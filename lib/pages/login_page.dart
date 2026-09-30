import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/api.dart';
import '../core/store.dart';
import '../widgets/glass.dart';

/// ============================================================
///  原生登录 / 注册
///
///  以前这里是跳网页登录再靠 Cookie 共享，体验割裂（还要等网页加载）。
///  现在完全原生：站点接口就是 POST /api/auth/login|register，
///  拿到的会话 Cookie 由 Api 层保存，同时注入 WebView，
///  所以原生登录之后，内嵌的网页页面也直接是登录态。
/// ============================================================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.reason});

  /// 为什么要登录（例如「私信」「加好友」），显示在顶部
  final String? reason;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _register = false;
  bool _busy = false;
  bool _obscure = true;
  String? _err;

  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  final _qq = TextEditingController();

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    _pass2.dispose();
    _qq.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final u = _user.text.trim();
    final p = _pass.text;
    if (u.length < 3) return _fail('用户名至少 3 位');
    if (p.length < 6) return _fail('密码至少 6 位');
    if (_register && p != _pass2.text) return _fail('两次输入的密码不一样');

    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      if (_register) {
        await Api.i.register(u, p);
        if (_qq.text.trim().isNotEmpty) {
          // QQ 是注册后的可选补充（失败不影响注册成功）
          try {
            await Api.i.saveProfile(bio: null);
          } catch (_) {}
        }
        await AppState.i.register(u, p);
      } else {
        await AppState.i.login(u, p);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) _fail(e is ApiError ? e.message : e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fail(String msg) {
    if (!mounted) return;
    setState(() => _err = msg);
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
          title: Text(_register ? '注册账号' : '登录'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
          children: [
            Center(
              child: Container(
                width: 76,
                height: 76,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2E9E63), Color(0xFF2FA6A0)],
                  ),
                ),
                child: const Text('禾',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Text(
                widget.reason ?? (_register ? '注册后可发帖、聊天、绑定游戏' : '登录同禾境账号'),
                textAlign: TextAlign.center,
                style: TextStyle(color: t.text3, fontSize: 13),
              ),
            ),
            const SizedBox(height: 22),

            // 登录 / 注册 切换
            GlassPanel(
              padding: const EdgeInsets.all(4),
              radius: R.pill,
              strong: true,
              shadow: false,
              child: Row(
                children: [
                  _seg('登录', !_register, () => setState(() {
                        _register = false;
                        _err = null;
                      })),
                  _seg('注册', _register, () => setState(() {
                        _register = true;
                        _err = null;
                      })),
                ],
              ),
            ),
            const SizedBox(height: 18),

            GlassPanel(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              child: Column(
                children: [
                  _field(
                    controller: _user,
                    label: '用户名',
                    hint: '3~20 位字母 / 数字 / 下划线 / 汉字',
                    icon: Icons.person_outline_rounded,
                    onSubmitted: (_) => _submit(),
                  ),
                  _field(
                    controller: _pass,
                    label: '密码',
                    hint: '至少 6 位',
                    icon: Icons.lock_outline_rounded,
                    obscure: _obscure,
                    trailing: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 20,
                        color: t.text3,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  if (_register)
                    _field(
                      controller: _pass2,
                      label: '确认密码',
                      hint: '再输一次',
                      icon: Icons.lock_reset_rounded,
                      obscure: _obscure,
                      onSubmitted: (_) => _submit(),
                    ),
                  if (_register)
                    _field(
                      controller: _qq,
                      label: 'QQ（选填）',
                      hint: '方便站长联系你',
                      icon: Icons.chat_bubble_outline_rounded,
                      onSubmitted: (_) => _submit(),
                    ),
                ],
              ),
            ),

            if (_err != null) ...[
              const SizedBox(height: 14),
              GlassPanel(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 18, color: GlassTokens.danger),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_err!,
                          style: TextStyle(
                              color: t.text2, fontSize: 12.5, height: 1.5)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),
            GlassButton(
              label: _register ? '注册并登录' : '登录',
              icon: Icons.login_rounded,
              primary: true,
              loading: _busy,
              onTap: _busy ? null : _submit,
            ),
            const SizedBox(height: 12),
            Text(
              _register
                  ? '注册即表示同意站点规则：不刷屏、不发广告、不上传违规内容。'
                  : '忘记密码？在 QQ 群 1032612899 找站长重置。',
              textAlign: TextAlign.center,
              style: TextStyle(color: t.text3, fontSize: 11.5, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seg(String label, bool on, VoidCallback tap) {
    final t = GlassTokens.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: tap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(R.pill),
            color: on ? t.accent.withOpacity(0.16) : Colors.transparent,
            border: on ? Border.all(color: t.accent.withOpacity(0.5)) : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: on ? t.accent : t.text3,
              fontWeight: on ? FontWeight.w700 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? trailing,
    ValueChanged<String>? onSubmitted,
  }) {
    final t = GlassTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        onSubmitted: onSubmitted,
        style: TextStyle(color: t.text, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, size: 20, color: t.text3),
          suffixIcon: trailing,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          labelStyle: TextStyle(color: t.text2, fontSize: 13.5),
          hintStyle: TextStyle(color: t.text3, fontSize: 12.5),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: t.stroke),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: t.accent, width: 1.4),
          ),
        ),
      ),
    );
  }
}

/// 统一的「需要登录」入口：直接开原生登录页
Future<bool> requireLogin(BuildContext context, {String? reason}) async {
  if (AppState.i.me?.loggedIn == true) return true;
  final ok = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => LoginPage(reason: reason)),
  );
  return ok == true;
}
