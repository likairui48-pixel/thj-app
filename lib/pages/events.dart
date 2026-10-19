import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/img.dart';
import '../core/nav.dart';
import '../core/state.dart';
import '../core/ui.dart';
import 'login.dart';
import 'shop.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key, this.initialTab});

  final String? initialTab;

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  final _state = AppState.i;
  bool _loading = true;
  bool _checking = false;
  String? _err;
  Map<String, dynamic> _fest = <String, dynamic>{};
  Map<String, dynamic> _album = <String, dynamic>{};
  int _tab = 0;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tab = switch (widget.initialTab) {
      'timeline' => 1,
      'shop' => 2,
      'album' => 3,
      _ => 0,
    };
    _load();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_until > 0 && _until - DateTime.now().millisecondsSinceEpoch > 0) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  int get _until => asInt(asMap(_fest['event'])['banner_until']);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final results = await Future.wait([
        Api.i.festival(),
        Api.i.album(),
      ]);
      if (!mounted) return;
      setState(() {
        _fest = results[0];
        _album = results[1];
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

  Future<void> _checkin() async {
    if (!_state.isLoggedIn) {
      final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      if (ok != true) return;
    }
    setState(() => _checking = true);
    try {
      final j = await Api.i.festivalCheckin();
      if (!mounted) return;
      final rewards = asList(j['rewards']);
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('签到成功'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '连签 ${asInt(j['streak'])} 天 · 获得 ${asInt(j['points'])} ${asStr(j['pointsName'], '积分')}',
                style: const TextStyle(height: 1.5),
              ),
              if (rewards.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...rewards.map(
                  (r) => Text(
                    '· ${asStr(r['label'] ?? r['name'])}'
                    '${asStr(r['code']).isEmpty ? '' : '（卡密：${asStr(r['code'])}）'}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('收下'),
            ),
          ],
        ),
      );
      await _load();
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final event = asMap(_fest['event']);
    final locked = asInt(_fest['locked']) == 1;
    final title = asStr(event['banner_title'], '同禾境活动');
    final sub = asStr(event['banner_sub']);
    final until = _until;
    final left = until - DateTime.now().millisecondsSinceEpoch;

    return AppPage(
      title: '活动中心',
      actions: [
        IconButton(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: '刷新',
        ),
      ],
      child: AsyncView(
        loading: _loading,
        error: _err,
        onRetry: _load,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(17, 17, 17, 15),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF8A5A18),
                      Color(0xFFD08A1C),
                      Color(0xFFE7B85A),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.celebration_rounded,
                            color: Colors.white, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (until > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
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
                        style:
                            const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _goalBar(context),
                  ],
                ),
              ),
              if (locked) ...[
                const SizedBox(height: 12),
                AppCard(
                  child: Row(
                    children: [
                      const Icon(Icons.lock_clock_rounded,
                          color: AppColors.warning, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          asStr(asMap(_fest['lock'])['title'], '活动还没开放'),
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('签到')),
                  ButtonSegment(value: 1, label: Text('日程')),
                  ButtonSegment(value: 2, label: Text('商城')),
                  ButtonSegment(value: 3, label: Text('相册')),
                ],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
                showSelectedIcon: false,
              ),
              const SizedBox(height: 4),
              if (_tab == 0) _checkinSection(context),
              if (_tab == 1) _timelineSection(context),
              if (_tab == 2) _shopSection(context),
              if (_tab == 3) _albumSection(context),
              const SizedBox(height: 16),
              _entries(context),
              const SizedBox(height: 8),
              Text(
                '活动数据由站点实时下发。活动结束后入口会自动隐藏，不需要更新 App。',
                textAlign: TextAlign.center,
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

  Widget _goalBar(BuildContext context) {
    final stats = asMap(_fest['stats']);
    final goal = asInt(stats['goal']);
    final total = asInt(stats['totalAmount']);
    final progress = asDouble(stats['progress']);
    if (goal <= 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '活动进度 ${progress.toStringAsFixed(1)}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              '${fmtMoney(total)} / ${fmtMoney(goal)}',
              style: const TextStyle(color: Colors.white70, fontSize: 10.5),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: (progress / 100).clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: Colors.white.withOpacity(0.2),
            valueColor: const AlwaysStoppedAnimation(Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _checkinSection(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = asMap(_fest['checkin']);
    final pointsName = asStr(c['pointsName'] ?? _fest['pointsName'], '积分');
    final milestones = asList(c['milestones']);
    final board = asList(_fest['board']);
    final doneDays = asStrList(c['doneDays']);
    final todayDone = asBool(c['todayDone']);
    final canCheckin = asBool(c['canCheckin']);
    final on = asBool(c['on'], true);

    if (c.isEmpty) {
      return const EmptyView(
        text: '签到还没开放',
        icon: Icons.event_available_outlined,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: '每日签到'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.brand.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.event_available_rounded,
                        color: AppColors.brand, size: 24),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          asStr(c['title'], '每日签到'),
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          asStr(c['note'], '每天签到领 $pointsName'),
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 10.5,
                            height: 1.45,
                          ),
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
                    child: _checkinStat(
                        context, '${asInt(c['streak'])}', '当前连签'),
                  ),
                  Expanded(
                    child: _checkinStat(
                        context, '${asInt(c['doneCount'])}', '累计签到'),
                  ),
                  Expanded(
                    child: _checkinStat(
                        context, '${asInt(c['points'])}', pointsName),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!on)
                Text(
                  '本次签到已关闭',
                  style: TextStyle(
                      color: cs.onSurfaceVariant, fontSize: 12),
                )
              else
                AsyncButton(
                  label: todayDone
                      ? '今日已签到'
                      : (!_state.isLoggedIn
                          ? '登录后签到'
                          : (canCheckin ? '立即签到' : '暂不可签到')),
                  icon: todayDone
                      ? Icons.check_circle_rounded
                      : Icons.touch_app_rounded,
                  onPressed: todayDone || (!canCheckin && _state.isLoggedIn)
                      ? null
                      : _checkin,
                ),
              if (doneDays.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: doneDays
                      .take(10)
                      .map((d) => Pill(
                            text: d.length > 5 ? d.substring(5) : d,
                            color: AppColors.brand,
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
        if (milestones.isNotEmpty) ...[
          const SectionTitle(title: '连签奖励'),
          AppCard(
            child: Column(
              children: milestones.map((m) {
                final done = asBool(m['done']);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: (done ? AppColors.brand : cs.onSurfaceVariant)
                              .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Text(
                          '${asInt(m['streak'])}天',
                          style: TextStyle(
                            color:
                                done ? AppColors.brand : cs.onSurfaceVariant,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          asStr(m['label'], '连签奖励'),
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 12,
                            fontWeight:
                                done ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (done)
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.brand, size: 18)
                      else
                        Icon(Icons.lock_outline_rounded,
                            color: cs.onSurfaceVariant, size: 17),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
        if (board.isNotEmpty) ...[
          const SectionTitle(title: '签到榜'),
          AppCard(
            child: Column(
              children: board.take(10).map((b) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 26,
                        child: Text(
                          '${asInt(b['rank'])}',
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          asStr(b['username']),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Text(
                        '${asInt(b['days'])} 天 · 连签 ${asInt(b['best'])}',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _checkinStat(BuildContext context, String value, String label) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.brand,
            fontSize: 20,
            fontWeight: FontWeight.w900,
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

  Widget _timelineSection(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = asList(_fest['timeline']);
    if (items.isEmpty) {
      return const EmptyView(
        text: '站长还没排日程',
        icon: Icons.calendar_month_outlined,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: '活动日程'),
        ...items.map((it) {
          final status = asStr(it['status']);
          final live = status == 'live';
          final done = status == 'done';
          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: AppCard(
              color: live ? AppColors.danger.withOpacity(0.04) : null,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: (live
                              ? AppColors.danger
                              : done
                                  ? cs.onSurfaceVariant
                                  : AppColors.brand)
                          .withOpacity(0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      live
                          ? Icons.play_arrow_rounded
                          : done
                              ? Icons.check_rounded
                              : Icons.schedule_rounded,
                      color: live
                          ? AppColors.danger
                          : done
                              ? cs.onSurfaceVariant
                              : AppColors.brand,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                asStr(it['title'], '活动'),
                                style: TextStyle(
                                  color: cs.onSurface,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            if (live)
                              const Pill(
                                  text: '进行中', color: AppColors.danger)
                            else if (done)
                              const Pill(text: '已结束', color: Colors.grey),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${fmtDateTime(it['at'])} · ${asInt(it['dur'])} 分钟'
                          '${asStr(it['place']).isEmpty ? '' : ' · ${asStr(it['place'])}'}',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                        if (asStr(it['desc']).isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            asStr(it['desc']),
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 11,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _shopSection(BuildContext context) {
    final products = asList(_fest['products']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          title: '活动商城',
          trailing: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OrdersPage()),
            ),
            child: const Text('我的订单'),
          ),
        ),
        if (products.isEmpty)
          const EmptyView(
            text: '暂时没有在售商品',
            icon: Icons.storefront_outlined,
          )
        else
          ...products.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _productCard(context, p),
            ),
          ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RedeemPage()),
                ),
                icon: const Icon(Icons.confirmation_number_outlined, size: 17),
                label: const Text('兑换码'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Nav.to('/pay'),
                icon: const Icon(Icons.workspace_premium_outlined, size: 17),
                label: const Text('会员中心'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _productCard(BuildContext context, Map<String, dynamic> p) {
    final cs = Theme.of(context).colorScheme;
    final price = asInt(p['price']);
    final stock = p['stock'];
    final limitLeft = p['limitLeft'];
    final canBuy = asBool(p['canBuy']);
    final state = asStr(p['state']);
    final reason = state == 'ended'
        ? '已结束'
        : state == 'soon'
            ? '即将开售'
            : asInt(stock) == 0
                ? '已售罄'
                : asInt(limitLeft) == 0
                    ? '已达限购'
                    : '立即购买';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (asStr(p['badge']).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Pill(
                          text: asStr(p['badge']),
                          color: AppColors.warning,
                        ),
                      ),
                    Text(
                      asStr(p['name'], '商品'),
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    fmtMoney(price),
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (asStr(p['origText']).isNotEmpty)
                    Text(
                      '¥${asStr(p['origText'])}',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 10,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (asStr(p['desc']).isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              asStr(p['desc']),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 11.5,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 5,
            runSpacing: 4,
            children: [
              if (p['days'] != null && asInt(p['days']) > 0)
                Pill(text: '${asInt(p['days'])} 天', color: AppColors.teal),
              if (asBool(p['needAddr']))
                const Pill(text: '实体包邮', color: AppColors.warning),
              if (asInt(limitLeft) > 0)
                Pill(
                  text: '限购 ${asInt(limitLeft)}',
                  color: cs.onSurfaceVariant,
                ),
              if (stock != null)
                Pill(
                  text: '剩 ${asInt(stock)}',
                  color: AppColors.danger,
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canBuy ? () => _buy(p) : null,
              child: Text(canBuy ? '立即购买' : reason),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _buy(Map<String, dynamic> p) async {
    if (!_state.isLoggedIn) {
      final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      if (ok != true) return;
    }
    if (asBool(p['needBound']) && _state.mcName.isEmpty) {
      showToast(context, '购买前请先绑定游戏账号', error: true);
      Nav.to('/bind');
      return;
    }
    final qty = ValueNotifier<int>(1);
    final specs = <String, String>{};
    for (final s in asList(p['specs'])) {
      final opts = asStrList(s['options']);
      if (opts.isNotEmpty) specs[asStr(s['name'])] = opts.first;
    }
    final receiver = TextEditingController();
    final phone = TextEditingController();
    final addr = TextEditingController();
    final qq = TextEditingController();
    final ref4 = TextEditingController();
    final note = TextEditingController();
    String deliver = asStr(p['deliverDefault'], 'auto');
    String method = 'wechat';
    String? proof;

    await showAppSheet<void>(
      context,
      child: StatefulBuilder(
        builder: (ctx, setSt) {
          final price = asInt(p['price']);
          final maxQty = <int>[
            1,
            if (asInt(p['limitLeft']) > 0) asInt(p['limitLeft']) else 5,
            if (p['stock'] != null) asInt(p['stock']) else 5,
            5,
          ].reduce((a, b) => a < b ? a : b);
          return Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '购买 · ${asStr(p['name'])}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                Text(
                  '${fmtMoney(price)} / 份'
                  '${asInt(p['days']) > 0 ? ' · ${asInt(p['days'])} 天' : ''}',
                  style: TextStyle(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('数量'),
                    const Spacer(),
                    IconButton(
                      onPressed: qty.value > 1
                          ? () => setSt(() => qty.value -= 1)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(
                      '${qty.value}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      onPressed: qty.value < maxQty
                          ? () => setSt(() => qty.value += 1)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('合计'),
                    const Spacer(),
                    Text(
                      fmtMoney(price * qty.value),
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final s in asList(p['specs']))
                  if (asStrList(s['options']).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: DropdownButtonFormField<String>(
                        value: specs[asStr(s['name'])],
                        decoration:
                            InputDecoration(labelText: asStr(s['name'])),
                        items: asStrList(s['options'])
                            .map(
                              (o) => DropdownMenuItem(
                                value: o,
                                child: Text(o),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setSt(() =>
                                specs[asStr(s['name'])] = v);
                          }
                        },
                      ),
                    ),
                if (asBool(p['hasMembership'])) ...[
                  Text(
                    '交付方式',
                    style: TextStyle(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      fontSize: 11.5,
                    ),
                  ),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: 'auto',
                    groupValue: deliver,
                    onChanged: (v) => setSt(() => deliver = v ?? 'auto'),
                    title: Text(
                      '立即开通到 ${_state.mcName.isEmpty ? '我的游戏账号' : _state.mcName}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: 'code',
                    groupValue: deliver,
                    onChanged: (v) => setSt(() => deliver = v ?? 'code'),
                    title: const Text(
                      '给我一张卡密（可送人 / 以后激活）',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
                if (asBool(p['needAddr'])) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: receiver,
                          decoration:
                              const InputDecoration(labelText: '收件人'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: phone,
                          keyboardType: TextInputType.phone,
                          decoration:
                              const InputDecoration(labelText: '手机号'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: addr,
                    maxLines: 2,
                    decoration:
                        const InputDecoration(labelText: '收货地址'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: qq,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'QQ（选填）'),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: method,
                        decoration:
                            const InputDecoration(labelText: '付款方式'),
                        items: const [
                          DropdownMenuItem(
                              value: 'wechat', child: Text('微信')),
                          DropdownMenuItem(
                              value: 'alipay', child: Text('支付宝')),
                        ],
                        onChanged: (v) =>
                            setSt(() => method = v ?? 'wechat'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: ref4,
                        maxLength: 8,
                        decoration: const InputDecoration(
                          labelText: '单号后 4 位',
                          counterText: '',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: note,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: '给站长的留言',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final d = await ImgPicker.one(
                        maxWidth: 1400, quality: 80);
                    if (d != null) setSt(() => proof = d);
                  },
                  icon: Icon(
                    proof == null
                        ? Icons.upload_rounded
                        : Icons.check_circle_rounded,
                    size: 17,
                  ),
                  label: Text(proof == null ? '上传付款截图（可选）' : '已选择截图'),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    final payload = <String, dynamic>{
                      'productId': asInt(p['id']),
                      'qty': qty.value,
                      'spec': specs,
                      'deliverMode': deliver,
                      'payMethod': method,
                      'ref4': ref4.text.trim(),
                      'note': note.text.trim(),
                      if (proof != null) 'proof': proof,
                    };
                    if (asBool(p['needAddr'])) {
                      payload['receiver'] = receiver.text.trim();
                      payload['phone'] = phone.text.trim();
                      payload['addr'] = addr.text.trim();
                      payload['qq'] = qq.text.trim();
                    }
                    try {
                      final j = await Api.i.shopOrder(payload);
                      if (ctx.mounted) Navigator.pop(ctx);
                      final order = asMap(j['order']);
                      if (mounted) {
                        showToast(
                          context,
                          '订单已创建${asStr(order['orderNo']).isEmpty ? '' : '：${asStr(order['orderNo'])}'}',
                        );
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const OrdersPage()),
                        );
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        showToast(ctx, e.toString(), error: true);
                      }
                    }
                  },
                  icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                  label: const Text('提交订单'),
                ),
              ],
            ),
          );
        },
      ),
    );
    receiver.dispose();
    phone.dispose();
    addr.dispose();
    qq.dispose();
    ref4.dispose();
    note.dispose();
  }

  Widget _albumSection(BuildContext context) {
    final photos = asList(_album['photos']);
    if (!asBool(_album['on'], true) || photos.isEmpty) {
      return const EmptyView(
        text: '活动相册还没有照片',
        icon: Icons.photo_library_outlined,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          title: '活动相册',
          sub: '${photos.length} 张 · ${asStr(_album['photoPlace'])}',
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 4 / 3,
          children: [
            for (var i = 0; i < photos.length; i++)
              GestureDetector(
                onTap: () => showImageViewer(
                  context,
                  photos.map((p) => asStr(p['url'])).toList(),
                  i,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    NetImage(url: asStr(photos[i]['thumb'] ?? photos[i]['url'])),
                    if (asStr(photos[i]['caption']).isNotEmpty)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(14),
                            ),
                          ),
                          child: Text(
                            asStr(photos[i]['caption']),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _entries(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          ActionTile(
            icon: Icons.sports_esports_rounded,
            title: 'SMP 活动服',
            sub: '报名、规则、击杀流水、观战地图',
            onTap: () => Nav.to('/smp'),
          ),
          ActionTile(
            icon: Icons.workspace_premium_outlined,
            title: '会员与充值',
            sub: '会员权益、收款码、订单',
            onTap: () => Nav.to('/pay'),
          ),
        ],
      ),
    );
  }
}
