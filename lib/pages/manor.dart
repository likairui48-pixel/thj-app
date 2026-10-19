import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/nav.dart';
import '../core/state.dart';
import '../core/ui.dart';
import 'login.dart';

class ManorPage extends StatefulWidget {
  const ManorPage({super.key});

  @override
  State<ManorPage> createState() => _ManorPageState();
}

class _ManorPageState extends State<ManorPage> {
  final _state = AppState.i;
  final _qq = TextEditingController();
  final _motto = TextEditingController();
  bool _loading = true;
  bool _busy = false;
  String? _err;
  Map<String, dynamic> _pub = <String, dynamic>{};
  Map<String, dynamic> _identity = <String, dynamic>{};
  String _mode = 'spectator';
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _load();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _remaining > 0) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _qq.dispose();
    _motto.dispose();
    super.dispose();
  }

  DateTime? get _countdownAt {
    final event = asMap(_pub['event']);
    final raw = asStr(event['countdown']);
    return DateTime.tryParse(raw);
  }

  int get _remaining {
    final at = _countdownAt;
    if (at == null) return 0;
    return at.difference(DateTime.now()).inMilliseconds;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final results = await Future.wait([
        Api.i.manorPublic(),
        Api.i.manorIdentity(),
      ]);
      if (!mounted) return;
      setState(() {
        _pub = results[0];
        _identity = results[1];
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

  Future<void> _login() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
    await _load();
  }

  Future<void> _register() async {
    setState(() => _busy = true);
    try {
      final j = await Api.i.manorRegister(
        qq: _qq.text.trim(),
        motto: _motto.text.trim(),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('报名成功'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '你的地块编号：${asStr(j['plotLabel'])}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                asStr(j['msg'], '已加入白名单并开通创造模式。'),
                style: const TextStyle(height: 1.55),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('好的'),
            ),
          ],
        ),
      );
      await _load();
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _visit() async {
    setState(() => _busy = true);
    try {
      final j = await Api.i.manorVisit(_mode);
      if (!mounted) return;
      showToast(
        context,
        asStr(j['msg'], _mode == 'adventure' ? '已切换冒险模式' : '已切换旁观模式'),
      );
      await _load();
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final event = asMap(_pub['event']);
    final slots = asList(_pub['slots']);
    final leaderboard = asList(_pub['leaderboard']);
    final registration = asMap(_identity['registration']);
    final visitor = asMap(_identity['visitor']);
    final loggedIn = asBool(_identity['loggedIn']);
    final bound = asBool(_identity['bound']);
    final remaining = _remaining;

    return AppPage(
      title: '庄园杯',
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
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF2A2418),
                      Color(0xFF6B5126),
                      Color(0xFFC39B55),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asStr(event['short'], '庄园杯 · 建筑大赛'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10.5,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      asStr(event['title'], '第一届庄园杯'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '主题：${asStr(event['theme'], '中世纪欧洲庄园')}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (asStr(event['heroSub']).isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        asStr(event['heroSub']),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          height: 1.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _countCell(
                          context,
                          '${remaining <= 0 ? 0 : remaining ~/ 86400000}',
                          '天',
                        ),
                        _countCell(
                          context,
                          '${remaining <= 0 ? 0 : (remaining % 86400000) ~/ 3600000}',
                          '时',
                        ),
                        _countCell(
                          context,
                          '${remaining <= 0 ? 0 : (remaining % 3600000) ~/ 60000}',
                          '分',
                        ),
                        _countCell(
                          context,
                          '${remaining <= 0 ? 0 : (remaining % 60000) ~/ 1000}',
                          '秒',
                        ),
                        const Spacer(),
                        if (asStr(_pub['serverAddress']).isNotEmpty)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                            ),
                            onPressed: () {
                              showToast(
                                context,
                                '活动服：${asStr(_pub['serverAddress'])}',
                              );
                            },
                            icon: const Icon(Icons.dns_rounded, size: 16),
                            label: const Text('比赛服'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SectionTitle(title: '参赛地块'),
              GridView.count(
                crossAxisCount: 5,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 0.85,
                children: slots.map((s) {
                  final name = asStr(s['name']);
                  final used = name.isNotEmpty;
                  return Container(
                    decoration: BoxDecoration(
                      color: used
                          ? AppColors.brand.withOpacity(0.1)
                          : cs.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: used
                            ? AppColors.brand.withOpacity(0.35)
                            : cs.outlineVariant,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          asStr(s['label']),
                          style: TextStyle(
                            color:
                                used ? AppColors.brand : cs.onSurfaceVariant,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          used ? name : '空位',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: used ? cs.onSurface : cs.onSurfaceVariant,
                            fontSize: 8.5,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SectionTitle(title: '报名'),
              if (!loggedIn)
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('报名需要使用同禾境网站账号，并绑定游戏 ID。'),
                      const SizedBox(height: 10),
                      FilledButton(
                        onPressed: _login,
                        child: const Text('去登录 / 注册'),
                      ),
                    ],
                  ),
                )
              else if (!bound)
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('已登录 ${asStr(_identity['username'])}，但还没绑定游戏账号。'),
                      const SizedBox(height: 10),
                      FilledButton(
                        onPressed: () => Nav.to('/bind'),
                        child: const Text('去绑定游戏账号'),
                      ),
                    ],
                  ),
                )
              else if (registration.isNotEmpty)
                AppCard(
                  color: AppColors.brand.withOpacity(0.07),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: AppColors.brand, size: 20),
                          const SizedBox(width: 7),
                          Text(
                            '已报名 · 地块 ${asStr(registration['plotLabel'])}',
                            style: const TextStyle(
                              color: AppColors.brand,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '游戏 ID：${asStr(_identity['mcName'])}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                )
              else
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '已登录：${asStr(_identity['username'])} · 已绑定 ${asStr(_identity['mcName'])}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _qq,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'QQ（选填）'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _motto,
                        maxLength: 80,
                        decoration: const InputDecoration(
                          labelText: '参赛宣言（选填）',
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _busy || !asBool(_pub['registrationOpen'])
                            ? null
                            : _register,
                        icon: const Icon(Icons.flag_rounded, size: 18),
                        label: Text(asBool(_pub['registrationOpen'])
                            ? '提交报名'
                            : '报名通道尚未开启'),
                      ),
                    ],
                  ),
                ),
              const SectionTitle(title: '观众模式'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '观赛登记后可选冒险（可互动、不可破坏）或旁观（自由飞行）。',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11.5,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: 'spectator', label: Text('旁观')),
                        ButtonSegment(
                            value: 'adventure', label: Text('冒险')),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (s) =>
                          setState(() => _mode = s.first),
                      showSelectedIcon: false,
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: _busy || !loggedIn || !bound ? null : _visit,
                      child: Text(visitor.isEmpty
                          ? '应用我的模式'
                          : '当前：${asStr(visitor['mode'])}，重新应用'),
                    ),
                    if (asStr(_pub['serverAddress']).isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '比赛服：${asStr(_pub['serverAddress'])}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SectionTitle(title: '排行榜'),
              AppCard(
                child: leaderboard.isEmpty
                    ? Text(
                        asBool(_pub['leaderboardPublic'])
                            ? '还没有评分记录'
                            : '排行榜暂未公开',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11.5,
                        ),
                      )
                    : Column(
                        children: leaderboard.asMap().entries.map((e) {
                          final r = e.value;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 26,
                                  child: Text(
                                    '${e.key + 1}',
                                    style: const TextStyle(
                                      color: AppColors.gold,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        asStr(r['mc_name']),
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (asStr(r['note']).isNotEmpty)
                                        Text(
                                          asStr(r['note']),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                            fontSize: 9.5,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${asDouble(r['avg']).toStringAsFixed(1)}',
                                  style: const TextStyle(
                                    color: AppColors.brand,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SectionTitle(title: '赛程与规则'),
              if (asStr(event['serverIntro']).isNotEmpty)
                AppCard(
                  child: Text(
                    asStr(event['serverIntro']),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                      height: 1.6,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              ...asList(event['rules']).map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('· ',
                          style: TextStyle(color: AppColors.brand)),
                      Expanded(
                        child: Text(
                          asStr(r),
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            fontSize: 11,
                            height: 1.55,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ...asList(event['rubric']).map((r) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: AppCard(
                    padding: const EdgeInsets.all(11),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${asInt(r['max'])} 分',
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                asStr(r['name']),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (asStr(r['desc']).isNotEmpty)
                                Text(
                                  asStr(r['desc']),
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontSize: 10,
                                    height: 1.45,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              if (!asBool(_pub['entranceVisible']))
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    '该赛事入口暂未对外公开。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 10.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _countCell(BuildContext context, String value, String label) {
    return Container(
      width: 44,
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 8.5),
          ),
        ],
      ),
    );
  }
}
