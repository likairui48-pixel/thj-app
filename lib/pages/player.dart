import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/api.dart';
import '../core/nav.dart';
import '../core/ui.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key, required this.name});

  final String name;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  bool _loading = true;
  String? _err;
  Map<String, dynamic> _player = <String, dynamic>{};
  Map<String, dynamic> _rank = <String, dynamic>{};

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
      final player = await Api.i.player(widget.name);
      Map<String, dynamic> rank = <String, dynamic>{};
      try {
        rank = await Api.i.rankDetail(widget.name);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _player = player;
        _rank = asMap(rank['rank']);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = e.toString();
        _loading = false;
      });
    }
  }

  void _share() {
    final url = Api.i.cardUrl(widget.name);
    Clipboard.setData(ClipboardData(text: url));
    showToast(context, '名片链接已复制');
    Share.share('${widget.name} 的同禾境名片：$url');
  }

  Future<void> _showCard() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.network(
                Api.i.cardUrl(widget.name),
                fit: BoxFit.contain,
                errorBuilder: (c, e, s) => Container(
                  padding: const EdgeInsets.all(30),
                  color: Theme.of(ctx).colorScheme.surface,
                  child: const Text('名片生成失败'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: Api.i.cardUrl(widget.name)),
                    );
                    showToast(ctx, '链接已复制');
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('复制链接'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => Share.share(
                    '${widget.name} 的同禾境名片：${Api.i.cardUrl(widget.name)}',
                  ),
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text('分享'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('关闭'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = asMap(_player['player']);
    final tier = asMap(_rank['tier']);
    final membership = asMap(_player['membership']);
    final webUser = asStrOrNull(_player['webUser']);
    final parts = asMap(asMap(_rank['components'])['parts']);
    final labels = <String, String>{
      'playtime': '游戏时长',
      'recency': '近期活跃',
      'sessions': '上场次数',
      'placed': '放置方块',
      'mined': '挖掘方块',
      'crafted': '合成物品',
      'advances': '成就进度',
      'forum': '论坛发言',
      'likes': '收到点赞',
      'chat': '游戏聊天',
      'friends': '好友数量',
      'economy': '经济余额',
    };

    return AppPage(
      title: '玩家名片',
      actions: [
        IconButton(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: '刷新',
        ),
        IconButton(
          onPressed: _share,
          icon: const Icon(Icons.share_outlined),
          tooltip: '分享',
        ),
      ],
      child: AsyncView(
        loading: _loading,
        error: _err,
        onRetry: _load,
        isEmpty: !_loading && p.isEmpty,
        emptyText: '没有找到玩家「${widget.name}」',
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
            children: [
              AppCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        UserAvatar(
                          name: widget.name,
                          size: 68,
                          ring: true,
                          online: asBool(p['online']),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      widget.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: cs.onSurface,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  if (tier.isNotEmpty) TierPill(tier: tier),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (asBool(p['online']))
                                    const Pill(
                                        text: '在线',
                                        color: AppColors.brand)
                                  else
                                    const Pill(
                                        text: '离线', color: Colors.grey),
                                  if (asBool(p['banned'])) ...[
                                    const SizedBox(width: 5),
                                    const Pill(
                                        text: '封禁', color: AppColors.danger),
                                  ],
                                  if (membership.isNotEmpty) ...[
                                    const SizedBox(width: 5),
                                    MembershipPill(membership: membership),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _stat(context, '等级',
                              'Lv.${asInt(p['level'])}'),
                        ),
                        Expanded(
                          child: _stat(context, '时长',
                              '${asDouble(p['playtimeHours']).toStringAsFixed(1)}h'),
                        ),
                        Expanded(
                          child: _stat(context, '段位分',
                              '${asInt(_rank['score'])}'),
                        ),
                        Expanded(
                          child: _stat(context, '排名',
                              '#${asInt(_rank['position'])}'),
                        ),
                      ],
                    ),
                    if (webUser != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => Nav.to(
                                '/u/${Uri.encodeComponent(webUser)}'),
                            icon: const Icon(Icons.person_outline_rounded,
                                size: 16),
                            label: Text('查看 $webUser 的站内主页'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '游戏数据',
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _dataCell(context, '挖掘方块',
                            fmtNumber(p['blocksMined'])),
                        _dataCell(context, '击杀生物',
                            fmtNumber(p['mobKills'])),
                        _dataCell(context, '击杀玩家',
                            fmtNumber(p['playerKills'])),
                        _dataCell(context, '死亡次数',
                            fmtNumber(p['deaths'])),
                        _dataCell(context, '移动距离',
                            '${asDouble(p['distanceKm']).toStringAsFixed(1)} km'),
                        _dataCell(context, '首次进服',
                            fmtDate(p['firstJoin'])),
                      ],
                    ),
                  ],
                ),
              ),
              if (tier.isNotEmpty) ...[
                const SizedBox(height: 12),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '段位构成',
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${asInt(_rank['score'])} / 1000',
                            style: const TextStyle(
                              color: AppColors.brand,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: (asInt(_rank['score']) / 1000).clamp(0.0, 1.0),
                          minHeight: 7,
                          backgroundColor: cs.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation(
                            parseColor(asStr(tier['color'])),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...parts.entries.map((e) {
                        final part = asMap(e.value);
                        if (asBool(part['available'], true) == false) {
                          return const SizedBox.shrink();
                        }
                        final got = asDouble(part['got']);
                        final max = asDouble(part['max'], 1);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 54,
                                child: Text(
                                  labels[e.key] ?? e.key,
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(99),
                                  child: LinearProgressIndicator(
                                    value: (got / max).clamp(0.0, 1.0),
                                    minHeight: 5,
                                    backgroundColor:
                                        cs.surfaceContainerHighest,
                                    valueColor: AlwaysStoppedAnimation(
                                      parseColor(asStr(tier['color']))
                                          .withOpacity(0.8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                '${got.toStringAsFixed(0)}/${max.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 9.5,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (asInt(asMap(_rank['components'])['penalty']) > 0)
                        Text(
                          '违规扣分 −${asInt(asMap(_rank['components'])['penalty'])}',
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 10.5,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _showCard,
                icon: const Icon(Icons.badge_rounded, size: 18),
                label: const Text('查看 / 分享名片图'),
              ),
              const SizedBox(height: 8),
              Text(
                '名片由站点实时生成；如果玩家开启隐私保护，名片可能不对外展示。',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 10.5,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 9.5),
        ),
      ],
    );
  }

  Widget _dataCell(BuildContext context, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: (MediaQuery.of(context).size.width - 62) / 2,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 9.5),
          ),
        ],
      ),
    );
  }
}
