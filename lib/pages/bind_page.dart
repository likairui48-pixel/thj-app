import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';
import '../core/api.dart';
import '../core/store.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import '../widgets/kit.dart';

/// 绑定游戏账号：拿验证码 → 进游戏聊天框发「绑定 验证码」→ 回来点「我已发送」
class BindPage extends StatefulWidget {
  const BindPage({super.key});

  @override
  State<BindPage> createState() => _BindPageState();
}

class _BindPageState extends State<BindPage> {
  bool _loading = true;
  String? _err;
  bool _busy = false;
  Map<String, dynamic> _binding = const {};
  Map<String, dynamic> _pending = const {};
  List<String> _steps = const [];

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
      final j = await Api.i.bindStatus();
      if (!mounted) return;
      setState(() {
        _binding = asMap(j['binding']);
        _pending = asMap(j['pendingCode']);
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

  bool get _bound => _binding.isNotEmpty && asStrOrNull(_binding['mc_name']) != null;

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
          title: Text('绑定游戏账号',
              style: TextStyle(
                  color: t.text, fontSize: 17, fontWeight: FontWeight.w700)),
        ),
        body: AsyncView(
          loading: _loading,
          error: _err,
          onRetry: _load,
          skeleton: const Padding(
            padding: EdgeInsets.all(R.page),
            child: GlassSkeleton(height: 160, radius: R.card),
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(R.page, 14, R.page, 30),
            children: [
              if (_bound) _boundCard() else _unboundCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _boundCard() {
    final t = GlassTokens.of(context);
    final name = asStr(_binding['mc_name']);
    return Column(
      children: [
        GlassPanel(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Icon(Icons.verified_rounded, size: 40, color: t.accent),
              const SizedBox(height: 10),
              Text('已绑定',
                  style: TextStyle(
                      color: t.text, fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(name,
                  style: TextStyle(
                      color: t.accent,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                '会员开通、签到奖励都会直接发到这个角色上。\n要换绑请先解绑（解绑后原有会员不会被回收）。',
                textAlign: TextAlign.center,
                style: TextStyle(color: t.text3, fontSize: 12, height: 1.6),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassPanel(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 14),
          child: Column(
            children: [
              InfoRow(label: '绑定角色', value: name),
              InfoRow(
                  label: 'UUID',
                  value: asStr(_binding['uuid'], '未记录').substring(
                      0,
                      (asStr(_binding['uuid']).length) > 8
                          ? 8
                          : asStr(_binding['uuid']).length)),
              InfoRow(label: '绑定时间', value: ago(_binding['created_at'])),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GlassButton(
          label: '解绑（换绑前先点这里）',
          icon: Icons.link_off_rounded,
          onTap: _unbind,
        ),
      ],
    );
  }

  Widget _unboundCard() {
    final t = GlassTokens.of(context);
    final code = asStrOrNull(_pending['code']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassPanel(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.link_rounded, color: t.accent, size: 20),
                  const SizedBox(width: 8),
                  Text('为什么要绑定',
                      style: TextStyle(
                          color: t.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '绑定游戏账号后，你买的会员、签到奖励会直接发放到游戏角色上，'
                '不用再手动兑换卡密。',
                style: TextStyle(color: t.text2, fontSize: 12.5, height: 1.6),
              ),
            ],
          ),
        ),
        if (code == null) ...[
          const SizedBox(height: 14),
          GlassButton(
            label: _busy ? '生成中…' : '生成绑定验证码',
            icon: Icons.qr_code_rounded,
            primary: true,
            loading: _busy,
            onTap: _busy ? null : _start,
          ),
        ] else ...[
          SectionTitle(title: '绑定步骤', sub: '3 步搞定'),
          GlassPanel(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('你的验证码',
                    style: TextStyle(color: t.text3, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SelectableText(code,
                          style: TextStyle(
                              color: t.accent,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5)),
                    ),
                    GlassChip(
                      label: '复制',
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: code));
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('验证码已复制')));
                      },
                    ),
                  ],
                ),
                if (asInt(_pending['expires_at']) > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('有效期至 ${_clock(_pending['expires_at'])}',
                        style: TextStyle(color: t.text3, fontSize: 11.5)),
                  ),
                const SizedBox(height: 14),
                Container(height: 1, color: t.divider),
                const SizedBox(height: 12),
                ...(_steps.isEmpty
                        ? [
                            '进入游戏服务器，在聊天框输入：绑定 $code',
                            '看到「绑定成功」提示后，回到这里点下面的按钮',
                          ]
                        : _steps)
                    .asMap()
                    .entries
                    .map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: t.accent.withOpacity(0.16),
                                  shape: BoxShape.circle,
                                ),
                                child: Text('${e.key + 1}',
                                    style: TextStyle(
                                        color: t.accent,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700)),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(e.value,
                                    style: TextStyle(
                                        color: t.text,
                                        fontSize: 13,
                                        height: 1.5)),
                              ),
                            ],
                          ),
                        )),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassButton(
            label: _busy ? '核对中…' : '我已在游戏里发送',
            icon: Icons.check_circle_outline_rounded,
            primary: true,
            loading: _busy,
            onTap: _busy ? null : _verify,
          ),
          const SizedBox(height: 8),
          GlassButton(
            label: '重新生成验证码',
            icon: Icons.refresh_rounded,
            onTap: _busy ? null : _start,
          ),
        ],
        const SizedBox(height: 12),
        Text('绑定需要在游戏里操作一次，这是为了防止别人冒用你的角色名。',
            style: TextStyle(color: t.text3, fontSize: 11.5, height: 1.5)),
      ],
    );
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      final j = await Api.i.bindStart();
      final steps = (j['instructions'] as List? ?? const [])
          .map((e) => e.toString())
          .toList();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _pending = {
          'code': asStr(j['code']),
          'expires_at': asInt(j['expiresAt']),
        };
        _steps = steps;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('生成失败：$e')));
    }
  }

  Future<void> _verify() async {
    setState(() => _busy = true);
    try {
      final j = await Api.i.bindVerify(asStr(_pending['code']));
      if (!mounted) return;
      setState(() => _busy = false);
      if (asBool(j['bound'])) {
        await _load();
        await AppState.i.refreshBrandAndMe();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('绑定成功：${asStr(j['mcName'])}')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(asStr(j['error'] ?? j['message'],
                '还没检测到，请确认游戏里提示「绑定成功」后再试'))));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('核对失败：$e')));
    }
  }

  Future<void> _unbind() async {
    final ok = await GlassDialog.confirm(
      context,
      title: '解绑游戏账号',
      message: '解绑后已开通的会员仍然有效，但签到奖励、开通操作会暂停发放。确定解绑吗？',
      okLabel: '解绑',
      danger: true,
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await Api.i.unbind();
      if (!mounted) return;
      setState(() {
        _binding = const {};
        _pending = const {};
        _steps = const [];
        _busy = false;
      });
      await AppState.i.refreshBrandAndMe();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('解绑失败：$e')));
    }
  }

  String _clock(dynamic ms) {
    final v = asInt(ms);
    if (v <= 0) return '—';
    final d = DateTime.fromMillisecondsSinceEpoch(v);
    return '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }
}
