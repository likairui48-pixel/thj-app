import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/api.dart';
import '../core/store.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import 'player_page.dart';
import 'user_profile_page.dart';

/// ============================================================
///  排行榜（原生）：段位榜 / 时长榜 / 等级榜
///  点任意一行 → 有站内账号的进「个人主页」，没有的进「游戏名片」
/// ============================================================
class RankPage extends StatefulWidget {
  const RankPage({super.key});

  @override
  State<RankPage> createState() => _RankPageState();
}

class _RankPageState extends State<RankPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);
  final _state = AppState.i;

  bool _loading = true;
  String? _err;

  List<RankRow> _board = <RankRow>[];
  int _boardTotal = 0;
  List<LeaderRow> _playtime = <LeaderRow>[];
  List<LeaderRow> _level = <LeaderRow>[];

  @override
  void initState() {
    super.initState();
    _tab.addListener(() {
      if (mounted) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final b = await Api.i.board(limit: 60, showFakes: _state.showFakes);
      final rows = asList(b['board']).map(RankRow.fromJson).toList();
      final pt = await Api.i.leaderboard('playtime');
      final lv = await Api.i.leaderboard('level');
      if (!mounted) return;
      setState(() {
        _board = rows;
        _boardTotal = asInt(b['total']);
        _playtime = asList(pt['rows']).map(LeaderRow.fromJson).toList();
        _level = asList(lv['rows']).map(LeaderRow.fromJson).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = e is ApiError ? e.message : e.toString();
      });
    }
  }

  Future<void> _open(String name, String? webUser) async {
    if (webUser != null && webUser.isNotEmpty) {
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => UserProfilePage(username: webUser)));
      return;
    }
    await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PlayerPage(name: name)));
  }

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    final s = _state.season;
    return AuroraBg(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('排行榜'),
          actions: [
            GlassIconButton(
              icon: Icons.refresh_rounded,
              size: 38,
              tooltip: '刷新',
              onTap: _load,
            ),
            const SizedBox(width: 10),
          ],
          bottom: TabBar(
            controller: _tab,
            labelColor: t.accent,
            unselectedLabelColor: t.text3,
            indicatorColor: t.accent,
            tabs: const [
              Tab(text: '段位榜'),
              Tab(text: '时长榜'),
              Tab(text: '等级榜'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (s != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: GlassPanel(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.emoji_events_rounded,
                          size: 18, color: t.accent),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          '${s.name} · 还剩 ${s.daysLeft} 天'
                          '${_boardTotal > 0 ? ' · 共 $_boardTotal 位玩家' : ''}',
                          style: TextStyle(fontSize: 13, color: t.text2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(child: _body(t)),
          ],
        ),
      ),
    );
  }

  Widget _body(GlassTokens t) {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: List<Widget>.generate(
          7,
          (i) => const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: GlassSkeleton(height: 56, radius: 16),
          ),
        ),
      );
    }
    if (_err != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [ErrorPanel(message: _err!, onRetry: _load)],
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: TabBarView(
        controller: _tab,
        children: [
          _boardList(t),
          _leaderList(_playtime, t, by: 'playtime'),
          _leaderList(_level, t, by: 'level'),
        ],
      ),
    );
  }

  Widget _boardList(GlassTokens t) {
    if (_board.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          EmptyHint(text: '还没有段位数据', icon: Icons.leaderboard_rounded),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 90),
      itemCount: _board.length,
      itemBuilder: (ctx, i) {
        final r = _board[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            onTap: () => _open(r.name, r.webUser),
            child: Row(
              children: [
                _posBadge(r.pos, t),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(r.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: t.text)),
                          ),
                          if (r.webUser != null) ...[
                            const SizedBox(width: 6),
                            GlassChip(label: '已绑定'),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${r.score} 分 · ${hoursText(r.hours)} · 已放置 ${shortNum(r.placed)}',
                        style: TextStyle(fontSize: 11.5, color: t.text3),
                      ),
                    ],
                  ),
                ),
                GlassChip(label: r.tier.label, color: Color(r.tier.color)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _leaderList(List<LeaderRow> rows, GlassTokens t, {required String by}) {
    if (rows.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          EmptyHint(text: '还没有数据', icon: Icons.bar_chart_rounded),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 90),
      itemCount: rows.length,
      itemBuilder: (ctx, i) {
        final r = rows[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            onTap: () => _open(r.name, r.webUser),
            child: Row(
              children: [
                _posBadge(r.rank, t),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(r.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: t.text)),
                          ),
                          if (r.webUser != null) ...[
                            const SizedBox(width: 6),
                            GlassChip(label: '已绑定'),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        by == 'playtime'
                            ? hoursText(r.hours)
                            : '等级 ${r.level ?? '—'}',
                        style: TextStyle(fontSize: 11.5, color: t.text3),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: t.text3),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _posBadge(int pos, GlassTokens t) {
    final top3 = pos <= 3;
    final color = pos == 1
        ? const Color(0xFFE0B24B)
        : (pos == 2
            ? const Color(0xFFB9C0C8)
            : (pos == 3 ? const Color(0xFFC98A5B) : t.text3));
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: top3 ? color.withOpacity(0.16) : t.fill,
        border: Border.all(
            color: top3 ? color.withOpacity(0.55) : t.stroke),
      ),
      child: Text(
        '$pos',
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
          color: top3 ? color : t.text3,
        ),
      ),
    );
  }
}
