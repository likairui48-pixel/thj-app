import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/api.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import '../widgets/kit.dart';
import 'login_page.dart';
import 'pay_page.dart';
import 'user_profile_page.dart';

/// 活动专区：签到 / 连签奖励 / 榜单 / 日程
class FestivalPage extends StatefulWidget {
  const FestivalPage({super.key});

  @override
  State<FestivalPage> createState() => _FestivalPageState();
}

class _FestivalPageState extends State<FestivalPage>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _err;
  bool _busy = false;
  Map<String, dynamic> _data = const {};
  late final TabController _tab = TabController(length: 3, vsync: this);

  @override
  void initState() {
    super.initState();
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
      final j = await Api.i.festival();
      if (!mounted) return;
      setState(() {
        _data = j;
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

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    return AuroraBg(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: t.text,
          title: Text(asStr(_data['checkin'] == null
                  ? '活动'
                  : asStr(asMap(_data['checkin'])['title'], '活动专区')),
              style: TextStyle(
                  color: t.text, fontSize: 17, fontWeight: FontWeight.w700)),
          actions: [
            IconButton(
              tooltip: '刷新',
              onPressed: _load,
              icon: Icon(Icons.refresh_rounded, color: t.text, size: 20),
            ),
          ],
          bottom: TabBar(
            controller: _tab,
            indicatorColor: t.accent,
            labelColor: t.text,
            unselectedLabelColor: t.text3,
            tabs: const [
              Tab(text: '签到'),
              Tab(text: '榜单'),
              Tab(text: '日程'),
            ],
          ),
        ),
        body: AsyncView(
          loading: _loading,
          error: _err,
          onRetry: _load,
          child: TabBarView(
            controller: _tab,
            children: [
              _checkinTab(),
              _boardTab(),
              _timelineTab(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- 签到 ----------------
  Widget _checkinTab() {
    final t = GlassTokens.of(context);
    final c = asMap(_data['checkin']);
    final locked = asInt(_data['locked']) == 1;
    final pointsName = asStr(c['pointsName'] ?? _data['pointsName'], '积分');
    final milestones = (c['milestones'] as List? ?? const [])
        .map((e) => asMap(e))
        .toList();
    final doneDays = (c['doneDays'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();
    final products = (_data['products'] as List? ?? const [])
        .map((e) => asMap(e))
        .toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(R.page, 14, R.page, 30),
        children: [
          if (locked)
            GlassPanel(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.lock_clock_rounded,
                      color: Color(0xFFE0623A), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      asStr(asMap(_data['lock'])['title'], '活动还没开放'),
                      style: TextStyle(color: t.text, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          GlassPanel(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: t.accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.event_available_rounded,
                          color: t.accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(asStr(c['title'], '每日签到'),
                              style: TextStyle(
                                  color: t.text,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          Text(
                            asStr(c['note'], '每天签到领 $pointsName，连签还有额外奖励'),
                            style: TextStyle(
                                color: t.text3, fontSize: 12.5, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: '已连签',
                        value: '${asInt(c['streak'])} 天',
                        icon: Icons.local_fire_department_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatTile(
                        label: pointsName,
                        value: '${asInt(c['points'])}',
                        icon: Icons.workspace_premium_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatTile(
                        label: '累计签到',
                        value: '${asInt(c['doneCount'])} 天',
                        icon: Icons.calendar_month_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GlassButton(
                  label: _busy
                      ? '签到中…'
                      : (asBool(c['todayDone']) ? '今天已签到' : '立即签到'),
                  icon: asBool(c['todayDone'])
                      ? Icons.check_circle_rounded
                      : Icons.touch_app_rounded,
                  primary: !asBool(c['todayDone']),
                  loading: _busy,
                  onTap: (!asBool(c['canCheckin']) || _busy) ? null : _checkin,
                ),
                const SizedBox(height: 8),
                Text(
                  asStr(c['reason'],
                      asBool(c['todayDone']) ? '明天记得再来～' : ''),
                  style: TextStyle(color: t.text3, fontSize: 12),
                ),
              ],
            ),
          ),
          if (milestones.isNotEmpty) ...[
            SectionTitle(title: '连签奖励', sub: '连续签到达标自动发放'),
            GlassPanel(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
              child: Column(
                children: milestones
                    .map((m) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            children: [
                              Icon(
                                asBool(m['done'])
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                size: 17,
                                color: asBool(m['done'])
                                    ? const Color(0xFF2E9E63)
                                    : t.text3,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  asStr(m['label'], '连签 ${asInt(m['streak'])} 天'),
                                  style: TextStyle(color: t.text, fontSize: 13.5),
                                ),
                              ),
                              Text(
                                asStr(m['desc'],
                                    asInt(m['points']) > 0
                                        ? '+${asInt(m['points'])} $pointsName'
                                        : (asInt(m['days']) > 0
                                            ? '${asInt(m['days'])} 天会员'
                                            : '卡密')),
                                style: TextStyle(
                                    color: asBool(m['done'])
                                        ? const Color(0xFF2E9E63)
                                        : t.text3,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
          if (doneDays.isNotEmpty) ...[
            SectionTitle(title: '签到记录',
                sub: '最近 ${doneDays.length} 天 · ${doneDays.take(1).join()}'),
            GlassPanel(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: doneDays
                    .map((d) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: t.accent.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(R.pill),
                          ),
                          child: Text(d.substring(5),
                              style: TextStyle(color: t.accent, fontSize: 11.5)),
                        ))
                    .toList(),
              ),
            ),
          ],
          if (products.isNotEmpty) ...[
            SectionTitle(
              title: '活动礼包',
              sub: '购买 / 开通',
              trailing: GlassChip(
                label: '全部',
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PayPage())),
              ),
            ),
            ...products.take(3).map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassPanel(
                    padding: const EdgeInsets.all(13),
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PayPage())),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(asStr(p['name']),
                                  style: TextStyle(
                                      color: t.text,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              if (asStr(p['desc']).isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(asStr(p['desc']),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: t.text3, fontSize: 11.5)),
                                ),
                            ],
                          ),
                        ),
                        Text(asStr(p['priceText'], yuan(asInt(p['price']))),
                            style: TextStyle(
                                color: t.accent,
                                fontSize: 15,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Future<void> _checkin() async {
    if (!await requireLogin(context, reason: '登录后才能签到')) return;
    setState(() => _busy = true);
    try {
      final j = await Api.i.festivalCheckin();
      final gained = asInt(j['gained']);
      final streak = asInt(j['streak']);
      final rewards = (j['rewards'] as List? ?? const [])
          .map((e) => asMap(e))
          .toList();
      if (!mounted) return;
      setState(() => _busy = false);
      await GlassSheet.show<void>(
        context,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events_rounded,
                size: 44, color: GlassTokens.of(context).accent),
            const SizedBox(height: 10),
            Text('签到成功 · 连签 $streak 天',
                style: TextStyle(
                    color: GlassTokens.of(context).text,
                    fontSize: 17,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('获得 $gained ${asStr(asMap(_data['checkin'])['pointsName'], '积分')}',
                style: TextStyle(
                    color: GlassTokens.of(context).text2, fontSize: 13.5)),
            if (rewards.isNotEmpty) ...[
              const SizedBox(height: 14),
              ...rewards.map((r) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(
                      '🎁 ${asStr(r['label'], '奖励')}'
                      '${asStrOrNull(r['code']) != null ? '：卡密 ${asStr(r['code'])}' : ''}'
                      '${asBool(r['needBind']) ? '（绑定游戏账号后可兑换）' : ''}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: GlassTokens.of(context).text2, fontSize: 12.5),
                    ),
                  )),
            ],
            const SizedBox(height: 16),
            GlassButton(
              label: '好',
              primary: true,
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('签到失败：$e')));
    }
  }

  // ---------------- 榜单 ----------------
  Widget _boardTab() {
    final t = GlassTokens.of(context);
    final list =
        (_data['board'] as List? ?? const []).map((e) => asMap(e)).toList();
    if (list.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(R.page),
        children: const [
          EmptyHint(text: '榜单还没开始（有人签到后就有了）', icon: Icons.leaderboard_outlined),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(R.page, 14, R.page, 30),
      itemCount: list.length,
      itemBuilder: (c, i) {
        final r = list[i];
        final rank = asInt(r['rank'], i + 1);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    UserProfilePage(username: asStr(r['username'])))),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text('#$rank',
                      style: TextStyle(
                          color: rank <= 3 ? t.accent : t.text3,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800)),
                ),
                Expanded(
                  child: Text(asStr(r['username']),
                      style: TextStyle(
                          color: t.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ),
                Text('${asInt(r['days'])} 天 · 连签 ${asInt(r['best'])}',
                    style: TextStyle(color: t.text2, fontSize: 12)),
                const SizedBox(width: 10),
                Text('${asInt(r['points'])}',
                    style: TextStyle(
                        color: t.accent,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------- 日程 ----------------
  Widget _timelineTab() {
    final t = GlassTokens.of(context);
    final items =
        (_data['timeline'] as List? ?? const []).map((e) => asMap(e)).toList();
    final live = _data['live'] == null ? null : asMap(_data['live']);
    final next = _data['next'] == null ? null : asMap(_data['next']);
    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(R.page),
        children: const [
          EmptyHint(text: '日程还没排出来，多留意群里公告', icon: Icons.schedule_rounded),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(R.page, 14, R.page, 30),
      children: [
        if (live != null && live.isNotEmpty)
          GlassPanel(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: Color(0xFFE0623A), shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('进行中：${asStr(live['title'])}',
                      style: TextStyle(
                          color: t.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        if (next != null && next.isNotEmpty) ...[
          const SizedBox(height: 8),
          GlassPanel(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.notifications_active_outlined, size: 17, color: t.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('下一个：${asStr(next['title'])} · ${_clock(next['at'])}',
                      style: TextStyle(color: t.text2, fontSize: 13)),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        ...items.map((it) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassPanel(
                padding: const EdgeInsets.all(13),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 58,
                      child: Text(_clock(it['at']),
                          style: TextStyle(
                              color: t.accent,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(asStr(it['title']),
                              style: TextStyle(
                                  color: t.text,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          if (asStr(it['note']).isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(asStr(it['note']),
                                  style: TextStyle(
                                      color: t.text3,
                                      fontSize: 12,
                                      height: 1.45)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  String _clock(dynamic ms) {
    final v = asInt(ms);
    if (v <= 0) return '待定';
    final d = DateTime.fromMillisecondsSinceEpoch(v);
    return '${d.month}/${d.day} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
