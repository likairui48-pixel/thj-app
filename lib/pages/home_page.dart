import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/api.dart';
import '../core/store.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import 'player_page.dart';

/// 首页：实时在线 / 服务器信息 / 在线玩家 / 快捷入口
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.onOpenTab});

  final ValueChanged<String>? onOpenTab;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin {
  final _state = AppState.i;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _state.addListener(_onChange);
    if (_state.status == null) _state.refreshStatus();
  }

  @override
  void dispose() {
    _state.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = GlassTokens.of(context);
    final st = _state.status;
    return RefreshIndicator(
      onRefresh: () async {
        await _state.refreshStatus();
        await _state.refreshBrandAndMe();
      },
      color: t.accent,
      backgroundColor: t.brightness == Brightness.dark
          ? const Color(0xFF16171A)
          : Colors.white,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          R.page,
          MediaQuery.of(context).padding.top + 8,
          R.page,
          GlassPillNav.reserved(context),
        ),
        children: [
          _header(t),
          const SizedBox(height: 14),
          _statusCard(t, st),
          const SizedBox(height: 12),
          _quickRow(t),
          SectionTitle(
            title: '在线玩家',
            sub: st == null
                ? null
                : '${st.online} 人 · 上限 ${st.max}'
                    '${st.fakeFolded > 0 ? ' · 已折叠 ${st.fakeFolded} 个假人' : ''}',
            trailing: GlassChip(
              label: _state.showFakes ? '含假人' : '只看真人',
              active: _state.showFakes,
              icon: Icons.visibility_rounded,
              onTap: () => _state.setShowFakes(!_state.showFakes),
            ),
          ),
          AsyncView(
            loading: _state.loadingStatus && st == null,
            error: st == null ? _state.statusError : null,
            onRetry: () => _state.refreshStatus(),
            isEmpty: (st?.players.isEmpty ?? true),
            emptyText: '现在服务器没人在线\n叫上朋友一起上号吧',
            emptyIcon: Icons.nightlight_round,
            skeleton: Column(
              children: List<Widget>.generate(
                3,
                (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: GlassSkeleton(height: 58, radius: 18),
                ),
              ),
            ),
            child: Column(
              children: (st?.players ?? <PlayerLite>[])
                  .map((p) => _playerTile(t, p))
                  .toList(),
            ),
          ),
          if (st?.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('扫描提示：${st!.error}',
                  style: TextStyle(color: t.text3, fontSize: 11.5)),
            ),
        ],
      ),
    );
  }

  Widget _header(GlassTokens t) {
    final me = _state.me;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                me?.serverName ?? '同禾境',
                style: TextStyle(
                  color: t.text,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Java 版 · 生存 · 长期开放',
                style: TextStyle(color: t.text3, fontSize: 12),
              ),
            ],
          ),
        ),
        GlassIconButton(
          icon: Icons.search_rounded,
          tooltip: '搜索玩家',
          onTap: () => _openSearch(),
        ),
        const SizedBox(width: 8),
        GlassIconButton(
          icon: t.brightness == Brightness.dark
              ? Icons.light_mode_rounded
              : Icons.dark_mode_rounded,
          tooltip: '切换黑白主题',
          onTap: () => _state.toggleTheme(),
        ),
      ],
    );
  }

  Widget _statusCard(GlassTokens t, ServerStatus? st) {
    final online = st?.online ?? 0;
    final max = st?.max ?? 48;
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      strong: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$online',
                style: TextStyle(
                  color: t.text,
                  fontSize: 54,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 6),
                child: Text('/ $max 人在线',
                    style: TextStyle(color: t.text3, fontSize: 13)),
              ),
              const Spacer(),
              _liveDot(t, online > 0),
            ],
          ),
          const SizedBox(height: 12),
          GlassProgress(value: st?.fill ?? 0),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              GlassChip(
                label: st?.version != null ? 'Java ${st!.version}' : 'Java 版',
                icon: Icons.memory_rounded,
              ),
              GlassChip(
                label: _state.season?.name ?? '赛季加载中',
                icon: Icons.emoji_events_rounded,
              ),
              if (_state.season != null)
                GlassChip(
                  label: '剩 ${_state.season!.daysLeft} 天',
                  icon: Icons.hourglass_bottom_rounded,
                ),
            ],
          ),
          if ((_state.me?.notice ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: t.accent.withOpacity(0.10),
                borderRadius: BorderRadius.circular(R.tile),
                border: Border.all(color: t.accent.withOpacity(0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.campaign_rounded, size: 16, color: t.accent),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      _state.me!.notice,
                      style: TextStyle(
                          color: t.text2, fontSize: 12.5, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _liveDot(GlassTokens t, bool live) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: live ? t.accent : t.text3,
            shape: BoxShape.circle,
            boxShadow: live
                ? [
                    BoxShadow(
                      color: t.accent.withOpacity(0.6),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          live ? '运行中' : '离线',
          style: TextStyle(
            color: live ? t.accent : t.text3,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _quickRow(GlassTokens t) {
    final items = <({String label, IconData icon, VoidCallback onTap})>[
      (
        label: '排行榜',
        icon: Icons.leaderboard_rounded,
        onTap: () => widget.onOpenTab?.call('rank'),
      ),
      (
        label: '我的名片',
        icon: Icons.badge_rounded,
        onTap: () {
          final name = _state.me?.mcName ?? _state.me?.username;
          if (name == null) {
            _snack('先登录才能看自己的名片，去「我的」登录吧');
            widget.onOpenTab?.call('me');
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PlayerPage(name: name)),
          );
        },
      ),
      (
        label: '社区',
        icon: Icons.forum_rounded,
        onTap: () => widget.onOpenTab?.call('community'),
      ),
      (
        label: '消息',
        icon: Icons.notifications_rounded,
        onTap: () => widget.onOpenTab?.call('messages'),
      ),
    ];
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: GlassPanel(
              padding: const EdgeInsets.symmetric(vertical: 14),
              radius: R.tile,
              onTap: items[i].onTap,
              child: Column(
                children: [
                  Icon(items[i].icon, size: 21, color: t.text2),
                  const SizedBox(height: 7),
                  Text(items[i].label,
                      style: TextStyle(color: t.text2, fontSize: 11.5)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _playerTile(GlassTokens t, PlayerLite p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        radius: R.tile,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PlayerPage(name: p.name)),
        ),
        child: Row(
          children: [
            PlayerAvatar(name: p.name, size: 38, online: true),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: t.text,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (p.fake) ...[
                        const SizedBox(width: 6),
                        GlassChip(label: '机器人', color: t.text3),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${p.level == null ? '等级未知' : 'Lv.${p.level}'} · ${hoursText(p.hours)}',
                    style: TextStyle(color: t.text3, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: t.text3, size: 20),
          ],
        ),
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openSearch() async {
    final name = await GlassSheet.show<String>(
      context,
      child: const _SearchSheetBody(),
    );
    if (name == null || name.isEmpty || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlayerPage(name: name)),
    );
  }
}

class _SearchSheetBody extends StatefulWidget {
  const _SearchSheetBody();

  @override
  State<_SearchSheetBody> createState() => _SearchSheetBodyState();
}

class _SearchSheetBodyState extends State<_SearchSheetBody> {
  final _ctrl = TextEditingController();
  List<PlayerLite> _players = const <PlayerLite>[];
  List<String> _users = const <String>[];
  bool _loading = false;
  String? _err;
  bool _touched = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _run(String q) async {
    if (q.trim().length < 2) return;
    setState(() {
      _loading = true;
      _err = null;
      _touched = true;
    });
    try {
      final j = await Api.i.search(q.trim());
      final players = asList(j['players']).map(PlayerLite.fromJson).toList();
      final users = asList(j['users'])
          .map((u) => asStr(u['mcName'] ?? u['username']))
          .where((s) => s.isNotEmpty)
          .toList();
      setState(() {
        _players = players;
        _users = users;
      });
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    final results = <String>{
      ..._players.map((p) => p.name),
      ..._users,
    }.toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('搜索玩家',
            style: TextStyle(
                color: t.text, fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: t.fill,
            borderRadius: BorderRadius.circular(R.tile),
            border: Border.all(color: t.stroke),
          ),
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: _run,
            style: TextStyle(color: t.text),
            decoration: InputDecoration(
              hintText: '输入玩家名 / 站内昵称',
              hintStyle: TextStyle(color: t.text3, fontSize: 14),
              prefixIcon: Icon(Icons.search_rounded, color: t.text3, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (_err != null)
          Text(_err!, style: TextStyle(color: t.text3, fontSize: 12.5))
        else if (_touched && results.isEmpty)
          Text('没找到相关玩家', style: TextStyle(color: t.text3, fontSize: 13))
        else
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: results
                  .take(20)
                  .map((n) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: PlayerAvatar(name: n, size: 36),
                        title: Text(n, style: TextStyle(color: t.text)),
                        trailing: Icon(Icons.chevron_right_rounded,
                            color: t.text3),
                        onTap: () => Navigator.of(context).pop(n),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}
