import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/nav.dart';
import '../core/state.dart';
import '../core/ui.dart';
import 'login.dart';

class SmpPage extends StatefulWidget {
  const SmpPage({super.key});

  @override
  State<SmpPage> createState() => _SmpPageState();
}

class _SmpPageState extends State<SmpPage> {
  final _state = AppState.i;
  bool _loading = true;
  bool _busy = false;
  String? _err;
  Map<String, dynamic> _smp = <String, dynamic>{};
  Map<String, dynamic> _map = <String, dynamic>{};
  String _world = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      _loadMap();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final results = await Future.wait([
        Api.i.smp(),
        Api.i.smpMap(),
      ]);
      if (!mounted) return;
      setState(() {
        _smp = results[0];
        _map = results[1];
        final worlds = _worlds();
        if (_world.isEmpty && worlds.isNotEmpty) _world = worlds.first;
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

  Future<void> _loadMap() async {
    try {
      final j = await Api.i.smpMap();
      if (!mounted) return;
      setState(() {
        _map = j;
        final worlds = _worlds();
        if (_world.isEmpty && worlds.isNotEmpty) _world = worlds.first;
      });
    } catch (_) {}
  }

  List<String> _worlds() {
    final out = <String>[];
    for (final p in asList(_map['players'])) {
      final w = asStr(p['world']);
      if (w.isNotEmpty && !out.contains(w)) out.add(w);
    }
    return out;
  }

  Future<void> _signup(bool publicPos) async {
    if (!_state.isLoggedIn) {
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final j = await Api.i.smpSignup(publicPos: publicPos);
      if (!mounted) return;
      showToast(context, asStr(j['message'], '报名成功'));
      await _load();
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _withdraw() async {
    final ok = await showConfirm(
      context,
      title: '取消报名',
      message: '取消后你的位置不再出现在观战地图，也可以重新报名。',
      okText: '确认取消',
      danger: true,
    );
    if (!ok) return;
    try {
      await Api.i.smpWithdraw();
      await _load();
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    }
  }

  Future<void> _togglePos(bool v) async {
    try {
      await Api.i.smpPos(publicPos: v);
      await _load();
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final signup = asMap(_smp['signup']);
    final mine = asMap(signup['mine']);
    final board = asList(_smp['board']);
    final kills = asList(_map['kills']);
    final players = asList(_map['players']);
    final progress = asMap(_map['progress']);
    final arena = asMap(_map['arena']);
    final border = asDouble(progress['border']);

    return AppPage(
      title: 'SMP 活动服',
      actions: [
        IconButton(
          onPressed: () {
            _load();
            _loadMap();
          },
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
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.danger.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.sports_esports_rounded,
                              color: AppColors.danger, size: 25),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                asStr(_smp['title'], 'SMP 活动'),
                                style: TextStyle(
                                  color: cs.onSurface,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                asStr(_smp['note']),
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 10.5,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Pill(
                          text: asStr(_smp['phaseName'], '进行中'),
                          color: AppColors.danger,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        if (asStr(_smp['eventIp']).isNotEmpty)
                          Pill(
                            text: '活动服 ${asStr(_smp['eventIp'])}',
                            color: AppColors.teal,
                          ),
                        Pill(
                          text: '${asInt(signup['count'])} / ${asInt(signup['maxPlayers'], 48)} 人',
                          color: AppColors.brand,
                        ),
                        if (asInt(progress['alive']) > 0)
                          Pill(
                            text: '存活 ${asInt(progress['alive'])}',
                            color: AppColors.warning,
                          ),
                        if (border > 0)
                          Pill(
                            text: '边界 ${border.toStringAsFixed(0)}',
                            color: AppColors.danger,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SectionTitle(title: '报名参赛'),
              _signupCard(context, signup, mine),
              const SectionTitle(title: '活动进度'),
              AppCard(
                child: Column(
                  children: asList(_smp['stages']).map((s) {
                    final status = asStr(s['status']);
                    final live = status == 'live';
                    final done = status == 'done';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: (live
                                      ? AppColors.danger
                                      : done
                                          ? cs.onSurfaceVariant
                                          : AppColors.brand)
                                  .withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              live
                                  ? Icons.play_arrow_rounded
                                  : done
                                      ? Icons.check_rounded
                                      : Icons.schedule_rounded,
                              size: 15,
                              color: live
                                  ? AppColors.danger
                                  : done
                                      ? cs.onSurfaceVariant
                                      : AppColors.brand,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        asStr(s['title']),
                                        style: TextStyle(
                                          color: cs.onSurface,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    if (live)
                                      const Pill(
                                          text: '进行中',
                                          color: AppColors.danger)
                                    else if (done)
                                      const Pill(
                                          text: '已完成', color: Colors.grey),
                                  ],
                                ),
                                if (asStr(s['desc']).isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    asStr(s['desc']),
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 10,
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SectionTitle(title: '实时地图'),
              AppCard(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          asInt(_map['at']) > 0
                              ? '更新于 ${fmtTime(_map['at'])}'
                              : '等待活动服数据',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                        const Spacer(),
                        if (asStr(_map['error']).isNotEmpty)
                          const Pill(text: '地图维护中', color: AppColors.warning),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (players.isEmpty)
                      EmptyView(
                        text: asStr(_map['error']).isEmpty
                            ? '暂时没有公开位置的玩家'
                            : '地图暂时不可用：${asStr(_map['error'])}',
                        icon: Icons.map_outlined,
                      )
                    else ...[
                      if (_worlds().length > 1)
                        Wrap(
                          spacing: 5,
                          children: _worlds().map((w) {
                            return ChoiceChip(
                              label: Text(w),
                              selected: _world == w,
                              onSelected: (_) => setState(() => _world = w),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 300,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: CustomPaint(
                            painter: _SmpMapPainter(
                              players: players
                                  .where((p) => asStr(p['world']) == _world)
                                  .toList(),
                              arena: arena,
                              border: border,
                              text: cs.onSurface,
                              muted: cs.onSurfaceVariant,
                              grid: cs.outlineVariant,
                              bg: cs.surfaceContainerHighest,
                              brand: AppColors.brand,
                              gold: AppColors.gold,
                              danger: AppColors.danger,
                              world: _world,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        players
                            .where((p) => asStr(p['world']) == _world)
                            .map((p) =>
                                '${asStr(p['name'])} (${asInt(p['x'])}, ${asInt(p['z'])})')
                            .join(' · '),
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 9.5,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SectionTitle(title: '击杀流水'),
              AppCard(
                child: kills.isEmpty
                    ? Text(
                        '暂时没有击杀记录',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 11.5,
                        ),
                      )
                    : Column(
                        children: kills.take(30).map((k) {
                          final t = asInt(k['ts']);
                          final time = t > 0
                              ? '${DateTime.fromMillisecondsSinceEpoch(t).hour.toString().padLeft(2, '0')}:'
                                  '${DateTime.fromMillisecondsSinceEpoch(t).minute.toString().padLeft(2, '0')}'
                              : '';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 38,
                                  child: Text(
                                    time,
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 9.5,
                                    ),
                                  ),
                                ),
                                Text(
                                  asStr(k['killer']),
                                  style: const TextStyle(
                                    color: AppColors.brand,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6),
                                  child: Icon(Icons.flash_on_rounded,
                                      color: AppColors.danger, size: 14),
                                ),
                                Text(
                                  asStr(k['victim']),
                                  style: const TextStyle(fontSize: 11.5),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SectionTitle(title: '参赛名单'),
              AppCard(
                child: board.isEmpty
                    ? Text(
                        '还没有人报名',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 11.5,
                        ),
                      )
                    : Column(
                        children: board.take(20).map((b) {
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
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '${asStr(b['mcName'])}'
                                    '${asStr(b['username']).isEmpty ? '' : ' @${asStr(b['username'])}'}',
                                    style: const TextStyle(fontSize: 11.5),
                                  ),
                                ),
                                Text(
                                  '${asInt(b['kills'])} 杀 · ${asInt(b['deaths'])} 死',
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 9.5,
                                  ),
                                ),
                                if (asBool(b['publicPos'])) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.location_on,
                                      size: 12, color: AppColors.teal),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SectionTitle(title: '活动规则'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: asList(_smp['rules']).map((r) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('· ',
                              style: TextStyle(color: AppColors.brand)),
                          Expanded(
                            child: Text(
                              asStr(r),
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 11,
                                height: 1.55,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _signupCard(
      BuildContext context, Map<String, dynamic> signup, Map<String, dynamic> mine) {
    final cs = Theme.of(context).colorScheme;
    if (mine.isNotEmpty) {
      final status = asStr(mine['status']);
      final statusText = status == 'alive'
          ? '参赛中'
          : status == 'out'
              ? '已淘汰'
              : '已报名';
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  asStr(mine['mcName'], '我的报名'),
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 6),
                Pill(
                  text: statusText,
                  color: status == 'out' ? Colors.grey : AppColors.brand,
                ),
                if (asInt(mine['place']) > 0) ...[
                  const Spacer(),
                  Text(
                    '名次 #${asInt(mine['place'])}',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '击杀 ${asInt(mine['kills'])} · 死亡 ${asInt(mine['deaths'])} · '
              '${asBool(mine['whitelisted']) ? '已在白名单' : '白名单待同步'}',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 10.5,
              ),
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('公开位置到观战地图',
                  style: TextStyle(fontSize: 12)),
              subtitle: const Text(
                '关闭后别人在地图上就看不到你（不影响参赛）',
                style: TextStyle(fontSize: 10),
              ),
              value: asBool(mine['publicPos']),
              onChanged: _busy ? null : _togglePos,
            ),
            if (asStr(_smp['phase']) == 'signup' ||
                asStr(_smp['phase']) == 'dev')
              OutlinedButton(
                onPressed: _busy ? null : _withdraw,
                child: const Text('取消报名'),
              ),
          ],
        ),
      );
    }
    if (asBool(signup['needLogin'])) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              asStr(signup['reason'], '登录并绑定游戏账号后即可报名'),
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 11.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              ),
              child: const Text('登录后报名'),
            ),
          ],
        ),
      );
    }
    if (!asBool(signup['bound'])) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '报名需要先绑定游戏账号，防止冒名并保证奖励发对人。',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 11.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Nav.to('/bind'),
              child: const Text('去绑定游戏账号'),
            ),
          ],
        ),
      );
    }
    if (!asBool(signup['open'])) {
      return AppCard(
        child: Text(
          asStr(signup['reason'], '报名已关闭'),
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11.5),
        ),
      );
    }
    var publicPos = true;
    return AppCard(
      child: StatefulBuilder(
        builder: (ctx, setSt) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '你的游戏账号：${asStr(signup['mcName'])}（已绑定）',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 11.5,
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('报名后公开位置到观战地图',
                  style: TextStyle(fontSize: 12)),
              value: publicPos,
              onChanged: (v) => setSt(() => publicPos = v ?? true),
            ),
            FilledButton.icon(
              onPressed: _busy ? null : () => _signup(publicPos),
              icon: const Icon(Icons.how_to_reg_rounded, size: 18),
              label: const Text('报名参赛（自动加入白名单）'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmpMapPainter extends CustomPainter {
  _SmpMapPainter({
    required this.players,
    required this.arena,
    required this.border,
    required this.text,
    required this.muted,
    required this.grid,
    required this.bg,
    required this.brand,
    required this.gold,
    required this.danger,
    required this.world,
  });

  final List<Map<String, dynamic>> players;
  final Map<String, dynamic> arena;
  final double border;
  final Color text;
  final Color muted;
  final Color grid;
  final Color bg;
  final Color brand;
  final Color gold;
  final Color danger;
  final String world;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);
    if (players.isEmpty) return;

    final ax = asDouble(arena['x']);
    final az = asDouble(arena['z']);
    final ar = asDouble(arena['r'], 120);
    final xs = players.map((p) => asDouble(p['x'])).toList();
    final zs = players.map((p) => asDouble(p['z'])).toList();
    if (border > 0) {
      xs.addAll([ax - border / 2, ax + border / 2]);
      zs.addAll([az - border / 2, az + border / 2]);
    } else if (ar > 0) {
      xs.addAll([ax - ar, ax + ar]);
      zs.addAll([az - ar, az + ar]);
    }
    final minX = xs.reduce((a, b) => a < b ? a : b);
    final maxX = xs.reduce((a, b) => a > b ? a : b);
    final minZ = zs.reduce((a, b) => a < b ? a : b);
    final maxZ = zs.reduce((a, b) => a > b ? a : b);
    final spanX = (maxX - minX) * 1.25 + 40;
    final spanZ = (maxZ - minZ) * 1.25 + 40;
    final cx = (minX + maxX) / 2;
    final cz = (minZ + maxZ) / 2;
    final scale = (size.width / spanX < size.height / spanZ)
        ? size.width / spanX
        : size.height / spanZ;
    double px(double x) => size.width / 2 + (x - cx) * scale;
    double pz(double z) => size.height / 2 + (z - cz) * scale;

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    var step = 32.0;
    while (step * scale < 44) {
      step *= 2;
    }
    final x0 = ((cx - spanX / 2) / step).ceil() * step;
    for (var x = x0; x <= cx + spanX / 2; x += step) {
      final p = px(x);
      canvas.drawLine(Offset(p, 0), Offset(p, size.height), gridPaint);
      _label(canvas, '${x.toInt()}', Offset(p + 3, size.height - 14), muted);
    }
    final z0 = ((cz - spanZ / 2) / step).ceil() * step;
    for (var z = z0; z <= cz + spanZ / 2; z += step) {
      final p = pz(z);
      canvas.drawLine(Offset(0, p), Offset(size.width, p), gridPaint);
      _label(canvas, '${z.toInt()}', Offset(4, p - 14), muted);
    }

    if (border > 0) {
      final rect = Rect.fromLTRB(
        px(ax - border / 2),
        pz(az - border / 2),
        px(ax + border / 2),
        pz(az + border / 2),
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = danger
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    } else if (ar > 0) {
      canvas.drawCircle(
        Offset(px(ax), pz(az)),
        ar * scale,
        Paint()
          ..color = gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    for (final p in players) {
      final x = px(asDouble(p['x']));
      final z = pz(asDouble(p['z']));
      final name = asStr(p['name']);
      final isMe = false;
      canvas.drawCircle(
        Offset(x, z),
        isMe ? 7 : 5,
        Paint()..color = isMe ? gold : brand,
      );
      canvas.drawCircle(
        Offset(x, z),
        isMe ? 7 : 5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      _label(canvas, '$name ${asInt(p['hp']) > 0 ? '${asInt(p['hp'])}HP' : ''}',
          Offset(x + 8, z + 2), text);
    }
    _label(canvas, '${world.isEmpty ? '世界' : world} · 仅显示公开位置',
        const Offset(8, 8), muted);
  }

  void _label(Canvas canvas, String text, Offset at, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 9.5),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant _SmpMapPainter old) =>
      old.players != players ||
      old.border != border ||
      old.world != world;
}
