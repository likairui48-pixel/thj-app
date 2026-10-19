import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/state.dart';
import '../core/ui.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.startRegister = false});

  final bool startRegister;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _state = AppState.i;
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _qq = TextEditingController();
  late bool _register = widget.startRegister;
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _qq.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final u = _username.text.trim();
    final p = _password.text;
    if (u.length < 2) {
      setState(() => _error = '请输入用户名');
      return;
    }
    if (p.length < 6) {
      setState(() => _error = '密码至少 6 位');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_register) {
        await _state.register(u, p, qq: _qq.text.trim());
      } else {
        await _state.login(u, p);
      }
      if (!mounted) return;
      showToast(context, _register ? '注册成功，欢迎来到同禾境' : '登录成功');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppPage(
      title: null,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 34),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 76,
                  height: 76,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.brand, AppColors.teal],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brand.withOpacity(0.28),
                        blurRadius: 26,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Text(
                    '禾',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _register ? '加入同禾境' : '欢迎回来',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _register
                      ? '注册后绑定游戏 ID，就能发帖、加好友、领签到奖励'
                      : '登录一次，全站通用：论坛、私聊、活动、订单',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('登录')),
                    ButtonSegment(value: true, label: Text('注册')),
                  ],
                  selected: {_register},
                  onSelectionChanged: (s) {
                    setState(() {
                      _register = s.first;
                      _error = null;
                    });
                  },
                  showSelectedIcon: false,
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _username,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  decoration: const InputDecoration(
                    labelText: '用户名',
                    hintText: '3~20 位，支持中文 / 字母 / 数字',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: '密码',
                    hintText: '至少 6 位',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 19,
                      ),
                    ),
                  ),
                ),
                if (_register) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _qq,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'QQ 号（选填）',
                      hintText: '方便服主联系你',
                      prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 12.5,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                AsyncButton(
                  label: _register ? '注册并登录' : '登录',
                  icon: _register
                      ? Icons.person_add_alt_1_rounded
                      : Icons.login_rounded,
                  onPressed: _busy ? null : _submit,
                ),
                const SizedBox(height: 14),
                Text(
                  '登录即表示同意遵守服务器规则。账号与游戏 ID 绑定后，网页和 App 共用同一份数据。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 11.5,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
