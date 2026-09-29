import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/api.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import 'web_page.dart';

/// 玩家名片（核心屏）：数据总览 + 分数构成 + 网页详情入口
class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key, required this.name});

  final String name;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  PlayerCard? _card;
  Map<String, dynamic> _parts = <String, dynamic>{};
  int _percentile = 0;
  bool _loading = true;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final j = await Api.i.player(widget.name);
      final card = PlayerCard.fromJson(j);
      Map<String, dynamic> parts = <String, dynamic>{};
      try {
        final rj = await Api.i.get('/api/rank/${Uri.encodeComponent(widget.name)}');
        final r = asMap(rj['rank']);
        parts = asMap(asMap(r['components'])['parts']);
      } catch (_) {}
      setState(() {
        _card = card;
        _parts = parts;
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, R.page, 0),
              child: Row(
                children: [
                  GlassIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: t.text,
                          fontSize: 20,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  GlassIconButton(
                    icon: Icons.refresh_rounded,
                    onTap: _load,
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                color: t.accent,
                backgroundColor: t.brightness == Brightness.dark
                    ? const Color(0xFF16171A)
                    : Colors.white,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(R.page, 14, R.page, 24),
                  children: [
                    if (_loading && _card == null)
                      Column(
                        children: List<Widget>.generate(
                          4,
                          (_) => const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: GlassSkeleton(height: 90, radius: 20),
                          ),
                        ),
                      )
                    else if (_err != null && _card == null)
                      ErrorHint(message: _err!, onRetry: _load)
                    else if (_card != null)
                      ..._content(t, _card!),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(GlassTokens t, PlayerCard c) {
    final tier = c.tier;
    final tierColor =
        tier == null ? t.accent : Color(tier.color);
    return [
      GlassPanel(
        strong: true,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: tierColor.withOpacity(0.35),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: PlayerAvatar(
                    name: c.name,
                    size: 66,
                    online: c.online,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: t.text,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                          if (c.online) ...[
                            const SizedBox(width: 8),
                            GlassChip(label: '在线', color: t.accent),
                          ],
                          if (c.banned)
                            GlassChip(
                                label: '已封禁',
                                color: GlassTokens.danger),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 7,
                        runSpacing: 6,
                        children: [
                          if (tier != null)
                            GlassChip(
                              label: tier.label,
                              color: tierColor,
                              active: true,
                            ),
                          if (c.rank > 0)
                            GlassChip(label: '第 ${c.rank} 名',
                                icon: Icons.military_tech_rounded),
                          if (c.webUser != null)
                            GlassChip(
                                label: '已绑定 @${c.webUser}',
                                icon: Icons.link_rounded),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                Api.i.cardUrl(c.name),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                loadingBuilder: (ctx, child, p) => p == null
                    ? child
                    : const GlassSkeleton(height: 120, radius: 16),
              ),
            ),
          ],
        ),
      ),
      SectionTitle(title: '游戏数据', sub: '来自服务器实时统计'),
      Row(
        children: [
          Expanded(
            child: StatTile(
              label: '等级',
              value: '${c.level}',
              icon: Icons.star_rounded,
              highlight: true,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StatTile(
              label: '游戏时长',
              value: hoursText(c.hours),
              icon: Icons.schedule_rounded,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: StatTile(
              label: '累计挖矿',
              value: shortNum(c.blocksMined),
              icon: Icons.terrain_rounded,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StatTile(
              label: '行进距离',
              value: '${c.distanceKm.toStringAsFixed(1)} km',
              icon: Icons.explore_rounded,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: StatTile(
              label: '击杀怪物',
              value: shortNum(c.mobKills),
              icon: Icons.sports_kabaddi_rounded,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StatTile(
              label: '死亡次数',
              value: '${c.deaths}',
              icon: Icons.dangerous_rounded,
            ),
          ),
        ],
      ),
      if (_parts.isNotEmpty) ...[
        SectionTitle(title: '段位分构成', sub: '各维度得分明细'),
        GlassPanel(
          child: Column(
            children: _parts.entries
                .where((e) => e.value is num)
                .map((e) => _partBar(t, e.key, asDouble(e.value)))
                .toList(),
          ),
        ),
      ],
      const SizedBox(height: 18),
      GlassButton(
        label: '查看完整主页',
        icon: Icons.open_in_new_rounded,
        onTap: () => _openWeb(c.name),
      ),
    ];
  }

  Widget _partBar(GlassTokens t, String key, double value) {
    const names = <String, String>{
      'playtime': '游戏时长',
      'recency': '活跃度',
      'sessions': '上线次数',
      'placed': '放置方块',
      'mined': '挖掘',
      'crafted': '合成',
      'advances': '成就进度',
      'forum': '社区活跃',
      'likes': '获赞',
      'chat': '聊天',
      'friends': '好友',
      'economy': '经济',
    };
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            child: Text(names[key] ?? key,
                style: TextStyle(color: t.text2, fontSize: 12)),
          ),
          Expanded(child: GlassProgress(value: v, height: 6)),
          const SizedBox(width: 10),
          SizedBox(
            width: 34,
            child: Text(
              '${(v * 100).round()}',
              textAlign: TextAlign.right,
              style: TextStyle(color: t.text3, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openWeb(String name) async {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => WebPage(
        title: '$name 的主页',
        path: '/p/${Uri.encodeComponent(name)}',
      ),
    ));
  }
}
