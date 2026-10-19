import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/cache.dart';
import '../core/nav.dart';
import '../core/state.dart';
import '../core/ui.dart';
import '../core/update_ui.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _state = AppState.i;
  List<Map<String, dynamic>> _threads = const [];
  Map<String, dynamic> _festival = <String, dynamic>{};
  Map<String, dynamic> _myRank = <String, dynamic>{};
  bool _loadingThreads = true;
  String? _threadError;
  bool _noticeOpen = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _threads = const [];
    _load();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final until = _bannerUntil;
      if (until > 0 &&
          until - DateTime.now().millisecondsSinceEpoch > 0) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  int get _bannerUntil =>
      asInt(asMap(_festival['event'])['banner_until']);

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loadingThreads = true;
        _threadError = null;
      });
    }
    final cachedThreads = await Cache.load('home_threads');
    final cachedFest = await Cache.load('home_festival');
    if (cachedThreads != null && mounted) {
      _threads = asList(cachedThreads['threads']);
      _loadingThreads = false;
    }
    if (cachedFest != null && mounted) {
      _festival = cachedFest;
    }

    await _state.refreshStatus(silent: silent);
    await _state.refreshSeason();

    try {
      final j = await Api.i.forumThreads(size: 6, sort: 'new');
      final list = asList(j['threads']);
      if (mounted) {
        setState(() {
          _threads = list;
          _loadingThreads = false;
          _threadError = null;
        });
      }
      await Cache.save('home_threads', j);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingThreads = false;
          _threadError = _threads.isEmpty ? e.toString() : null;
        });
      }
    }

    try {
      final j = await Api.i.festival();
      if (mounted) setState(() => _festival = j);
      await Cache.save('home_festival', j);
    } catch (_) {
      // 活动接口失败不阻塞首页
    }

    if (_state.isLoggedIn) {
      try {
        final j = await Api.i.myRank();
        if (mounted) setState(() => _myRank = j);
      } catch (_) {}
    }
  }

  void _open(String path) => Nav.to(path);

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    showToast(context, '已复制$label');
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: null,
      child: AnimatedBuilder(
        animation: _state,
        builder: (context, _) {
          return RefreshIndicator(
            onRefresh: () => _load(silent: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
              children: [
                _topBar(context),
                const SizedBox(height: 14),
                _statusHero(context),
                const SizedBox(height: 12),
                _seasonCard(context),
                if (_state.notice.isNotEmpty) _noticeCard(context),
                if (_state.update?.hasNewer == true) _updateCard(context),
                if (_festival.isNotEmpty) _eventBanner(context),
                const SizedBox(height: 4),
                _quickGrid(context),
                if (_state.isLoggedIn) _myRankCard(context),
                SectionTitle(
                  title: '最新帖子',
                  sub: _threads.isEmpty ? null : '社区里正在聊',
                  trailing: TextButton(
                    onPressed: () => Nav.tab('community'),
                    child: const Text('去社区'),
                  ),
                ),
                if (_loadingThreads && _threads.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (_threadError != null && _threads.isEmpty)
                  ErrorView(message: _threadError!, onRetry: _load)
                else if (_threads.isEmpty)
                  const EmptyView(
                    text: '还没有人发帖，来发第一帖吧',
                    icon: Icons.edit_note_rounded,
                  )
                else
                  ..._threads.map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _threadCard(context, t),
                      )),
                const SizedBox(height: 18),
                _serverInfo(context),
                const SizedBox(height: 26),
                Center(
                  child: Text(
                    '同禾境 · 与方块世界同行',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.brand, AppColors.teal],
            ),
          ),
          child: const Text(
            '禾',
            style: TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '同禾境',
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              Text(
                'TONG HE JING · MC',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 9.5,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: '搜索',
          onPressed: () => _open('/search'),
          icon: Icon(Icons.search_rounded, color: cs.onSurface),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: '消息',
              onPressed: () => Nav.tab('messages'),
              icon: Icon(Icons.notifications_none_rounded, color: cs.onSurface),
            ),
            if (_state.unreadTotal > 0)
              Positioned(
                right: 6,
                top: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 15),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: cs.surface, width: 1.5),
                  ),
                  child: Text(
                    _state.unreadTotal > 99 ? '99+' : '${_state.unreadTotal}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _statusHero(BuildContext context) {
    final st = _state.status ?? <String, dynamic>{};
    final online = asInt(st['online']);
    final max = asInt(st['max'], 48);
    final players = asList(st['players']);
    final fakes = asInt(st['fakeFolded']);
    final version = asStr(st['version'], '—');
    final updated = asInt(st['updatedAt']);
    final error = _state.statusError;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B5E3B), Color(0xFF2E9E63), Color(0xFF2FA6A0)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withOpacity(0.22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.public_rounded, color: Colors.white70, size: 17),
              const SizedBox(width: 6),
              Text(
                _state.serverName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              _statusDot(error == null && st.isNotEmpty),
              const Spacer(),
              Text(
                'Java · $version',
                style: const TextStyle(color: Colors.white70, fontSize: 10.5),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                st.isEmpty ? '—' : '$online',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  height: 0.95,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 5),
                child: Text(
                  '/ $max 人在线',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: Text(
                  error == null ? '运行中' : '数据延迟',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: max <= 0 ? 0 : (online / max).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: Colors.white.withOpacity(0.18),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 14),
          if (players.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: players.length.clamp(0, 14),
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final p = players[i];
                  final name = asStr(p['name']);
                  return GestureDetector(
                    onTap: () => _open('/p/${Uri.encodeComponent(name)}'),
                    child: Row(
                      children: [
                        UserAvatar(name: name, size: 30),
                        const SizedBox(width: 6),
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            )
          else
            Text(
              error == null ? '现在服务器里没人，去开荒吧' : '读取失败：$error',
              style: const TextStyle(color: Colors.white70, fontSize: 11.5),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.memory_rounded, color: Colors.white.withOpacity(0.65), size: 13),
              const SizedBox(width: 4),
              Text(
                _state.status == null
                    ? '正在读取服务器状态…'
                    : (updated > 0 ? '更新于 ${fmtTime(updated)}' : '数据已同步'),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 10.5,
                ),
              ),
              const Spacer(),
              if (fakes > 0)
                GestureDetector(
                  onTap: () => _state.setShowFakes(!_state.showFakes),
                  child: Text(
                    _state.showFakes ? '隐藏 $fakes 个假人' : '$fakes 个假人已折叠',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusDot(bool ok) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: ok ? const Color(0xFF8CF0B8) : const Color(0xFFFFC46B),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (ok ? const Color(0xFF8CF0B8) : const Color(0xFFFFC46B))
                .withOpacity(0.6),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }

  Widget _seasonCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final season = asMap(_state.season?['season']);
    final name = asStr(season['name'], '赛季');
    final days = asInt(season['daysLeft']);
    final duration = asInt(season['durationDays'], 45);
    final progress = duration <= 0 ? 0.0 : (1 - days / duration).clamp(0.0, 1.0);
    final myDetail = asMap(_myRank['detail']);
    final myTier = asMap(myDetail['tier']);
    final myPosition = asInt(myDetail['position']);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: AppColors.gold, size: 18),
              const SizedBox(width: 7),
              Text(
                name,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                days > 0 ? '剩 $days 天' : '已结束',
                style: TextStyle(
                  color: days > 0 ? AppColors.brand : cs.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: const AlwaysStoppedAnimation(AppColors.brand),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Text(
                myTier.isEmpty
                    ? '绑定游戏账号后查看我的段位'
                    : '我的段位 ${asStr(myTier['label'])} · ${asInt(myTier['score'])} 分',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 11.5,
                ),
              ),
              const Spacer(),
              if (myPosition > 0)
                Text(
                  '全服第 $myPosition 名',
                  style: const TextStyle(
                    color: AppColors.brand,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _noticeCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AppCard(
        color: AppColors.warning.withOpacity(0.08),
        border: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.campaign_rounded,
                    color: AppColors.warning, size: 18),
                const SizedBox(width: 7),
                Text(
                  '服务器公告',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _noticeOpen = !_noticeOpen),
                  child: Text(
                    _noticeOpen ? '收起' : '展开',
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              _state.notice,
              maxLines: _noticeOpen ? null : 3,
              overflow: _noticeOpen ? null : TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 12,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _updateCard(BuildContext context) {
    final info = _state.update!;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AppCard(
        color: AppColors.teal.withOpacity(0.09),
        border: false,
        onTap: () => showUpdateDialog(context, info, force: _state.forceUpdate),
        child: Row(
          children: [
            const Icon(Icons.system_update_alt_rounded,
                color: AppColors.teal, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '发现新版本 ${info.version}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    info.notes.isEmpty ? '点此查看更新内容' : info.notes.first,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _eventBanner(BuildContext context) {
    final event = asMap(_festival['event']);
    final on = asInt(event['banner_on']) == 1;
    if (!on && asInt(event['photo_at']) == 0) return const SizedBox.shrink();
    final title = asStr(event['banner_title'], '同禾境活动');
    final sub = asStr(event['banner_sub']);
    final until = _bannerUntil;
    final left = until - DateTime.now().millisecondsSinceEpoch;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(17, 16, 17, 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF8A5A18), Color(0xFFD08A1C), Color(0xFFE7B85A)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.celebration_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (until > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      left > 0 ? fmtCountdown(left) : '已结束',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            if (sub.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                sub,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
            const SizedBox(height: 13),
            Row(
              children: [
                _bannerButton(
                  context,
                  '活动中心',
                  Icons.arrow_forward_rounded,
                  () => _open('/festival'),
                ),
                const SizedBox(width: 8),
                _bannerButton(
                  context,
                  '立即签到',
                  Icons.check_circle_outline_rounded,
                  () => _open('/festival?tab=checkin'),
                  ghost: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bannerButton(
    BuildContext context,
    String text,
    IconData icon,
    VoidCallback onTap, {
    bool ghost = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: ghost ? Colors.white.withOpacity(0.16) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: TextStyle(
                color: ghost ? Colors.white : const Color(0xFF6E4A12),
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              icon,
              size: 14,
              color: ghost ? Colors.white : const Color(0xFF6E4A12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickGrid(BuildContext context) {
    final items = <Map<String, dynamic>>[
      {
        'label': '签到',
        'icon': Icons.event_available_rounded,
        'color': AppColors.brand,
        'path': '/festival?tab=checkin',
      },
      {
        'label': '活动',
        'icon': Icons.celebration_rounded,
        'color': AppColors.warning,
        'path': '/festival',
      },
      {
        'label': '商城',
        'icon': Icons.storefront_rounded,
        'color': AppColors.teal,
        'path': '/shop',
      },
      {
        'label': '排行',
        'icon': Icons.leaderboard_rounded,
        'color': const Color(0xFF8B5CF6),
        'path': '/rank',
      },
      {
        'label': '举报',
        'icon': Icons.flag_rounded,
        'color': AppColors.danger,
        'path': '/report',
      },
      {
        'label': _state.mcName.isEmpty ? '绑定' : '名片',
        'icon': _state.mcName.isEmpty
            ? Icons.link_rounded
            : Icons.badge_rounded,
        'color': const Color(0xFF2B7CD3),
        'path': _state.mcName.isEmpty
            ? '/bind'
            : '/p/${Uri.encodeComponent(_state.mcName)}',
      },
      {
        'label': '论坛',
        'icon': Icons.forum_rounded,
        'color': const Color(0xFF0E7490),
        'path': '/forum',
      },
      {
        'label': 'SMP',
        'icon': Icons.sports_esports_rounded,
        'color': const Color(0xFFB45309),
        'path': '/smp',
      },
    ];
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.92,
      children: items.map((it) {
        return AppCard(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          onTap: () => _open(asStr(it['path'])),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: (it['color'] as Color).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  it['icon'] as IconData,
                  color: it['color'] as Color,
                  size: 20,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                asStr(it['label']),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _myRankCard(BuildContext context) {
    final detail = asMap(_myRank['detail']);
    if (detail.isEmpty) return const SizedBox.shrink();
    final tier = asMap(detail['tier']);
    final color = parseColor(asStr(tier['color']), AppColors.brand);
    final score = asInt(detail['score']);
    final position = asInt(detail['position']);
    final total = asInt(detail['total']);
    final next = asMap(tier['next']);

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: AppCard(
        onTap: () => Nav.tab('rank'),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withOpacity(0.13),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: color.withOpacity(0.35)),
              ),
              child: Text(
                asStr(tier['key'], 'C'),
                style: TextStyle(
                  color: color,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '我的段位',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${asStr(tier['label'])} · $score 分',
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    next.isEmpty
                        ? '已达最高段位'
                        : '距 ${asStr(next['label'])} 还差 ${asInt(tier['toNext'])} 分',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '#$position',
                  style: const TextStyle(
                    color: AppColors.brand,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '共 $total 人',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _threadCard(BuildContext context, Map<String, dynamic> t) {
    final cs = Theme.of(context).colorScheme;
    final author = asMap(t['author']);
    final images = asStrList(t['images']);
    final badges = <Widget>[
      if (asBool(t['pinned'])) const Pill(text: '置顶', color: AppColors.warning),
      if (asBool(t['essence'])) const Pill(text: '精华', color: AppColors.teal),
      if (asBool(t['locked'])) const Pill(text: '已锁', color: Colors.grey),
    ];
    return AppCard(
      onTap: () => _open('/forum/thread/${asInt(t['id'])}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(name: asStr(author['username']), avatar: asStrOrNull(author['avatar']), size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ...badges,
                    Text(
                      asStr(t['title'], '无标题'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
                if (images.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  NetImage(url: images.first, height: 120, width: double.infinity),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      asStr(author['username'], '未知'),
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10.5),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      fmtAgo(t['lastReplyAt'] ?? t['createdAt']),
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10.5),
                    ),
                    const Spacer(),
                    Icon(Icons.chat_bubble_outline_rounded,
                        size: 12, color: cs.onSurfaceVariant),
                    const SizedBox(width: 3),
                    Text('${asInt(t['replies'])}',
                        style: TextStyle(
                            color: cs.onSurfaceVariant, fontSize: 10.5)),
                    const SizedBox(width: 8),
                    Icon(Icons.visibility_outlined,
                        size: 12, color: cs.onSurfaceVariant),
                    const SizedBox(width: 3),
                    Text('${asInt(t['views'])}',
                        style: TextStyle(
                            color: cs.onSurfaceVariant, fontSize: 10.5)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _serverInfo(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.dns_rounded, color: AppColors.brand, size: 18),
              const SizedBox(width: 7),
              Text(
                '进服信息',
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _copyRow(context, '服务器地址', _state.serverAddress, '地址'),
          _copyRow(context, '备用端口 / IP', _state.serverIp, 'IP'),
          InfoRow(
            label: 'Java 版本',
            value: _state.status == null
                ? '—'
                : asStr(_state.status!['version'], '—'),
          ),
          InfoRow(label: '玩家群', value: _state.qqGroup),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copy(_state.serverAddress, '服务器地址'),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('复制地址'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copy(_state.qqGroup, '群号'),
                  icon: const Icon(Icons.groups_rounded, size: 16),
                  label: const Text('复制群号'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _copyRow(BuildContext context, String label, String value, String copyLabel) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _copy(value, copyLabel),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Text(label,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.copy_rounded, size: 14, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
