import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/nav.dart';
import '../core/state.dart';
import '../core/ui.dart';

class RankPage extends StatefulWidget {
  const RankPage({super.key});

  @override
  State<RankPage> createState() => _RankPageState();
}

class _RankPageState extends State<RankPage> {
  final _state = AppState.i;
  String _by = 'tier';
  String? _tier;
  int _page = 1;
  bool _loading = true;
  String? _err;
  List<Map<String, dynamic>> _rows = const [];
  List<Map<String, dynamic>> _tiers = const [];
  Map<String, dynamic> _distribution = <String, dynamic>{};
  int _total = 0;
  int _fakeFolded = 0;
  Map<String, dynamic> _curve = <String, dynamic>{};
  Map<String, dynamic> _myRank = <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _loadCurve();
    _loadMine();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      _page = 1;
      _rows = const [];
    }
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      if (_by == 'tier') {
        final j = await Api.i.rankBoard(
          limit: 30,
          offset: (_page - 1) * 30,
          tier: _tier,
          showFakes: _state.showFakes,
        );
        final board = asList(j['board']);
        setState(() {
          _rows = reset || _page == 1 ? board : [..._rows, ...board];
          _total = asInt(j['total']);
          _tiers = asList(j['tiers']);
          _distribution = asMap(j['distribution']);
          _fakeFolded = asInt(j['fakesFolded']);
          _loading = false;
        });
      } else {
        final j = await Api.i.leaderboard(_by);
        final rows = asList(j['rows']);
        setState(() {
          _rows = rows;
          _total = rows.length;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadCurve() async {
    try {
      final j = await Api.i.rankCurve();
      if (mounted) setState(() => _curve = asMap(j['curve']));
    } catch (_) {}
  }

  Future<void> _loadMine() async {
    if (!_state.isLoggedIn) return;
    try {
      final j = await Api.i.myRank();
      if (mounted) setState(() => _myRank = j);
    } catch (_) {}
  }

  void _switchBy(String by) {
    if (_by == by) return;
    setState(() {
      _by = by;
      _tier = null;
    });
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final season = asMap(_state.season?['season']);
    return AppPage(
      title: '排行榜',
      actions: [
        IconButton(
          tooltip: '刷新',
          onPressed: () {
            _load(reset: true);
            _loadCurve();
            _loadMine();
          },
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: () async {
          await _load(reset: true);
          await _loadCurve();
          await _loadMine();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          children: [
            _seasonCard(context, season),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'tier', label: Text('段位')),
                ButtonSegment(value: 'playtime', label: Text('时长')),
                ButtonSegment(value: 'level', label: Text('等级')),
              ],
              selected: {_by},
              onSelectionChanged: (s) => _switchBy(s.first),
              showSelectedIcon: false,
            ),
            if (_by == 'tier') ...[
              const SizedBox(height: 12),
              _tierChips(context),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '共 $_total 人',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 11.5,
                    ),
                  ),
                  if (_fakeFolded > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      '假人 $_fakeFolded 个已折叠',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const Spacer(),
                  GestureDetector(
                    onTap: () async {
                      await _state.setShowFakes(!_state.showFakes);
                      _load(reset: true);
                    },
                    child: Text(
                      _state.showFakes ? '隐藏假人' : '展开假人',
                      style: const TextStyle(
                        color: AppColors.brand,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            AsyncView(
              loading: _loading && _rows.isEmpty,
              error: _err,
              onRetry: () => _load(reset: true),
              isEmpty: !_loading && _rows.isEmpty,
              emptyText: '这个榜单还没有玩家',
              emptyIcon: Icons.emoji_events_outlined,
              child: Column(
                children: [
                  ..._rows.asMap().entries.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: _rankRow(context, e.value, e.key),
                        ),
                      ),
                  if (_by == 'tier' && _rows.length < _total)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: OutlinedButton(
                        onPressed: () {
                          _page += 1;
                          _load();
                        },
                        child: const Text('加载更多'),
                      ),
                    ),
                ],
              ),
            ),
            if (_curve.isNotEmpty) _curveSection(context),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _seasonCard(BuildContext context, Map<String, dynamic> season) {
    final cs = Theme.of(context).colorScheme;
    final detail = asMap(_myRank['detail']);
    final tier = asMap(detail['tier']);
    final position = asInt(detail['position']);
    final total = asInt(detail['total']);
    final name = asStr(season['name'], '赛季');
    final days = asInt(season['daysLeft']);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.emoji_events_rounded,
                color: AppColors.gold, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      days > 0 ? '剩 $days 天' : '已结束',
                      style: TextStyle(
                        color: days > 0
                            ? AppColors.brand
                            : cs.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (detail.isEmpty || tier.isEmpty)
                  Text(
                    '登录并绑定游戏账号后显示我的段位',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 11.5,
                    ),
                  )
                else
                  Text(
                    '我的段位 ${asStr(tier['label'])} · ${asInt(tier['score'])} 分'
                    '${position > 0 ? ' · 全服第 $position / $total' : ''}',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 11.5,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tierChips(BuildContext context) {
    final tiers = _tiers.isEmpty
        ? [
            {'key': 'S', 'label': 'S 段', 'color': '#f59e0b'},
            {'key': 'A', 'label': 'A 段', 'color': '#8b5cf6'},
            {'key': 'B', 'label': 'B 段', 'color': '#3b82f6'},
            {'key': 'C', 'label': 'C 段', 'color': '#94a3b8'},
          ]
        : _tiers;
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: const Text('全部'),
              selected: _tier == null,
              onSelected: (_) {
                setState(() => _tier = null);
                _load(reset: true);
              },
            ),
          ),
          for (final t in tiers)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(
                  '${asStr(t['label'])} ${asInt(_distribution[asStr(t['key'])])}',
                ),
                selected: _tier == asStr(t['key']),
                onSelected: (_) {
                  setState(() => _tier = asStr(t['key']));
                  _load(reset: true);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _rankRow(BuildContext context, Map<String, dynamic> p, int index) {
    final cs = Theme.of(context).colorScheme;
    final pos = asInt(p['pos'] ?? p['rank'], index + 1);
    final name = asStr(p['name']);
    final tier = asMap(p['tier']);
    final webUser = asStrOrNull(p['webUser']);
    final isTop = pos <= 3;
    final medal = pos == 1
        ? const Color(0xFFD9A441)
        : pos == 2
            ? const Color(0xFF9AA7B2)
            : const Color(0xFFB87A4B);

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      onTap: () => Nav.to('/p/${Uri.encodeComponent(name)}'),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isTop ? medal.withOpacity(0.14) : cs.surfaceContainerHighest,
              shape: BoxShape.circle,
              border: isTop ? Border.all(color: medal.withOpacity(0.4)) : null,
            ),
            child: Text(
              '$pos',
              style: TextStyle(
                color: isTop ? medal : cs.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          UserAvatar(name: name, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (webUser != null) ...[
                      const SizedBox(width: 5),
                      Text(
                        '（$webUser）',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                if (_by == 'tier')
                  Text(
                    '${fmtNumber(p['hours'])} 小时 · 放置 ${fmtNumber(p['placed'])} · Lv.${asInt(p['level'])}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 10.5,
                    ),
                  )
                else if (_by == 'playtime')
                  Text(
                    '${asDouble(p['playtimeHours']).toStringAsFixed(1)} 小时 · Lv.${asInt(p['level'])}',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 10.5,
                    ),
                  )
                else
                  Text(
                    'Lv.${asInt(p['level'])} · ${asDouble(p['playtimeHours']).toStringAsFixed(1)} 小时',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 10.5,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (_by == 'tier')
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TierPill(tier: tier),
                const SizedBox(height: 3),
                Text(
                  '${asInt(p['score'])} 分',
                  style: const TextStyle(
                    color: AppColors.brand,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            )
          else if (_by == 'playtime')
            Text(
              '${asDouble(p['playtimeHours']).toStringAsFixed(1)}h',
              style: const TextStyle(
                color: AppColors.brand,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            )
          else
            Text(
              'Lv.${asInt(p['level'])}',
              style: const TextStyle(
                color: AppColors.brand,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
        ],
      ),
    );
  }

  Widget _curveSection(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final buckets = asList(_curve['buckets']);
    final tiers = asList(_curve['tiers']);
    final pct = asMap(_curve['percentiles']);
    final components = asList(_curve['components']);
    final maxCount = buckets.fold<int>(
      1,
      (m, b) => asInt(b['count']) > m ? asInt(b['count']) : m,
    );
    final labels = <String, String>{
      'playtime': '时长',
      'recency': '活跃',
      'sessions': '上场',
      'placed': '放置',
      'mined': '挖掘',
      'crafted': '合成',
      'advances': '成就',
      'forum': '论坛',
      'likes': '获赞',
      'chat': '聊天',
      'friends': '好友',
      'economy': '经济',
      'penalty': '违规',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: '段位分布', sub: '全服玩家分数段'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 110,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: buckets.map((b) {
                    final count = asInt(b['count']);
                    final ratio = count / maxCount;
                    final mid = (asInt(b['lo']) + asInt(b['hi'])) / 2;
                    final tier = tiers.firstWhere(
                      (t) => mid >= asInt(t['min']),
                      orElse: () => <String, dynamic>{},
                    );
                    final color = parseColor(
                      asStr(tier['color']),
                      cs.onSurfaceVariant,
                    );
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              count > 0 ? '$count' : '',
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 8.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              height: (92 * ratio).clamp(2.0, 92.0),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.75),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              asStr(b['lo']),
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: tiers.map((t) {
                  final color = parseColor(asStr(t['color']));
                  return Pill(
                    text:
                        '${asStr(t['label'])} ${asInt(t['count'])} 人 ${asDouble(t['percent']).toStringAsFixed(1)}%',
                    color: color,
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _pctCell(context, '中位', pct['p50']),
                  _pctCell(context, 'p75', pct['p75']),
                  _pctCell(context, 'p90', pct['p90']),
                  _pctCell(context, '最高', pct['max']),
                  _pctCell(context, '平均', pct['avg']),
                ],
              ),
            ],
          ),
        ),
        if (components.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: AppCard(
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '全服平均得分构成',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                ...components
                    .where((c) => asStr(c['key']) != 'penalty')
                    .map((c) {
                  final got = asDouble(c['avgGot']);
                  final max = asDouble(c['avgMax'], 1);
                  final ratio = (got / max).clamp(0.0, 1.0);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 42,
                          child: Text(
                            labels[asStr(c['key'])] ?? asStr(c['key']),
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: ratio,
                              minHeight: 6,
                              backgroundColor: cs.surfaceContainerHighest,
                              valueColor: const AlwaysStoppedAnimation(
                                AppColors.brand,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${got.toStringAsFixed(1)} / ${max.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _pctCell(BuildContext context, String label, dynamic value) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Text(
            value == null ? '—' : '$value',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }
}
