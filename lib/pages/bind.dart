import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/state.dart';
import '../core/ui.dart';

class BindPage extends StatefulWidget {
  const BindPage({super.key});

  @override
  State<BindPage> createState() => _BindPageState();
}

class _BindPageState extends State<BindPage> {
  final _state = AppState.i;
  bool _loading = true;
  bool _generating = false;
  String? _error;
  String? _code;
  Map<String, dynamic> _status = <String, dynamic>{};
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final j = await Api.i.bindStatus();
      if (!mounted) return;
      setState(() {
        _status = j;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      final j = await Api.i.bindStart();
      if (!mounted) return;
      setState(() => _code = asStr(j['code']));
      _poll?.cancel();
      _poll = Timer.periodic(const Duration(seconds: 4), (_) async {
        try {
          final s = await Api.i.bindStatus();
          if (asBool(s['bound']) || asStr(s['mcName']).isNotEmpty) {
            _poll?.cancel();
            await _state.refreshMe();
            if (!mounted) return;
            showToast(context, '绑定成功');
            setState(() {
              _status = s;
              _code = null;
            });
          }
        } catch (_) {}
      });
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _unbind() async {
    final ok = await showConfirm(
      context,
      title: '解除绑定',
      message: '解绑后无法在网页发言、领取会员权益、接收游戏内提醒，可随时重新绑定。',
      okText: '确认解绑',
      danger: true,
    );
    if (!ok) return;
    try {
      await Api.i.unbind();
      await _state.refreshMe();
      if (!mounted) return;
      showToast(context, '已解绑');
      _load();
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    }
  }

  void _copyCode() {
    if (_code == null) return;
    Clipboard.setData(ClipboardData(text: '绑定 $_code'));
    showToast(context, '已复制，进游戏粘贴即可');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bound = asBool(_status['bound']) ||
        asStr(_status['mcName']).isNotEmpty ||
        _state.mcName.isNotEmpty;
    final mcName = asStr(_status['mcName'], _state.mcName);

    return AppPage(
      title: '绑定游戏账号',
      actions: [
        IconButton(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: '刷新',
        ),
      ],
      child: AsyncView(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          children: [
            if (!_state.isLoggedIn)
              AppCard(
                child: Column(
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        color: cs.onSurfaceVariant, size: 30),
                    const SizedBox(height: 10),
                    const Text('登录后才能绑定游戏账号'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('先去登录'),
                    ),
                  ],
                ),
              )
            else if (bound)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        UserAvatar(name: mcName, size: 54, ring: true),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    mcName,
                                    style: TextStyle(
                                      color: cs.onSurface,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Pill(text: '已绑定', color: AppColors.brand),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '网页、App、游戏内身份已打通',
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    InfoRow(
                      label: '绑定时间',
                      value: fmtDate(asMap(_status['binding'])['created_at'] ??
                          _status['createdAt']),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: const Text('完成'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _unbind,
                            icon: const Icon(Icons.link_off_rounded, size: 18),
                            label: const Text('解除绑定'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.link_rounded, color: AppColors.brand, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          '两步完成绑定',
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _step('1', '点下面按钮生成 6 位绑定码'),
                    const SizedBox(height: 10),
                    _step('2', '进入游戏，在聊天框输入：绑定 你的码'),
                    const SizedBox(height: 16),
                    if (_code == null)
                      AsyncButton(
                        label: '生成绑定码',
                        icon: Icons.qr_code_2_rounded,
                        onPressed: _generating ? null : _generate,
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.brand.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.brand.withOpacity(0.25),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '在游戏里输入',
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              '绑定 $_code',
                              style: const TextStyle(
                                color: AppColors.brand,
                                fontSize: 28,
                                letterSpacing: 3,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '15 分钟内有效，绑定成功会自动刷新',
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 11.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _copyCode,
                              icon: const Icon(Icons.copy_rounded, size: 17),
                              label: const Text('复制指令'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                color: cs.surfaceContainerHighest.withOpacity(0.5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: cs.onSurfaceVariant, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '绑定后才能在网站发言、加好友、领取会员权益、接收游戏内提醒。一个网站账号只能绑定一个游戏 ID。',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _step(String n, String text) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.brand,
            shape: BoxShape.circle,
          ),
          child: Text(
            n,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 13.5,
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }
}
