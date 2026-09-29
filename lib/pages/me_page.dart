import 'package:flutter/material.dart';

import '../app/config.dart';
import '../app/theme.dart';
import '../core/api.dart';
import '../core/store.dart';
import '../core/update.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import 'settings_page.dart';
import 'web_page.dart';

/// 我的：账号 / 段位 / 快捷入口 / 更新检查
class MePage extends StatefulWidget {
  const MePage({super.key});

  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> with AutomaticKeepAliveClientMixin {
  final _state = AppState.i;
  Map<String, dynamic>? _myRank;
  bool _checking = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _state.addListener(_onChange);
    _loadRank();
  }

  @override
  void dispose() {
    _state.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _loadRank() async {
    if (!Api.i.hasSession) return;
    try {
      final j = await Api.i.myRank();
      if (mounted) setState(() => _myRank = j);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = GlassTokens.of(context);
    final me = _state.me;
    return RefreshIndicator(
      onRefresh: () async {
        await _state.refreshBrandAndMe();
        await _loadRank();
        await _state.refreshUnread();
      },
      color: t.accent,
      backgroundColor: t.brightness == Brightness.dark
          ? const Color(0xFF16171A)
          : Colors.white,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          R.page,
          MediaQuery.of(context).padding.top + 8,
          R.page,
          GlassPillNav.reserved(context),
        ),
        children: [
          Row(
            children: [
              Text('我的',
                  style: TextStyle(
                      color: t.text,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1)),
              const Spacer(),
              GlassIconButton(
                icon: Icons.settings_rounded,
                tooltip: '设置',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _profileCard(t, me),
          const SizedBox(height: 12),
          _rankCard(t),
          SectionTitle(title: '常用功能'),
          _menu(t),
          SectionTitle(title: '关于'),
          _about(t),
        ],
      ),
    );
  }

  Widget _profileCard(GlassTokens t, MeInfo? me) {
    final logged = me?.loggedIn == true;
    final name = me?.mcName ?? me?.username ?? '未登录';
    return GlassPanel(
      strong: true,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        children: [
          Row(
            children: [
              PlayerAvatar(name: name, size: 58, online: logged),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      logged ? (me?.username ?? '') : '还没有登录',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: t.text,
                          fontSize: 19,
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (logged && (me?.mcName ?? '').isNotEmpty)
                          GlassChip(
                              label: '游戏名 ${me!.mcName}',
                              icon: Icons.sports_esports_rounded),
                        if (logged)
                          GlassChip(
                            label: _roleLabel(me!.role),
                            color: t.accent,
                            icon: Icons.verified_rounded,
                          ),
                        if (!logged)
                          const GlassChip(
                              label: '登录后可用全部功能',
                              icon: Icons.lock_open_rounded),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!logged)
            GlassButton(
              label: '登录 / 注册',
              icon: Icons.login_rounded,
              primary: true,
              onTap: _openLogin,
            )
          else
            Row(
              children: [
                Expanded(
                  child: GlassButton(
                    label: '我的主页',
                    icon: Icons.person_rounded,
                    onTap: () => _openWeb(
                        '我的主页', '/u/${Uri.encodeComponent(me!.username!)}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GlassButton(
                    label: '退出登录',
                    icon: Icons.logout_rounded,
                    onTap: _confirmLogout,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  static String _roleLabel(String role) {
    switch (role) {
      case 'owner':
        return '站长';
      case 'admin':
        return '管理员';
      case 'mod':
        return '版主';
      default:
        return '成员';
    }
  }

  Widget _rankCard(GlassTokens t) {
    final bound = asBool(_myRank?['bound']);
    final detail = asMap(_myRank?['detail']);
    final tier = detail['tier'] is Map ? asMap(detail['tier']) : null;
    final score = asInt(detail['score']);
    final pos = asInt(asMap(detail['tier'])['position'] ?? detail['position']);

    if (!Api.i.hasSession) return const SizedBox.shrink();
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      onTap: _loadRank,
      child: bound
          ? Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('我的段位分',
                        style: TextStyle(color: t.text3, fontSize: 12)),
                    const SizedBox(height: 6),
                    Text('$score',
                        style: TextStyle(
                            color: t.text,
                            fontSize: 30,
                            height: 1,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (tier != null)
                      GlassChip(
                        label: '${tier['label'] ?? ''}',
                        active: true,
                        color: Color(TierInfo.fromJson(tier).color),
                      ),
                    const SizedBox(height: 6),
                    Text(pos > 0 ? '全服第 $pos 名' : '名次统计中',
                        style: TextStyle(color: t.text3, fontSize: 12)),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Icon(Icons.link_off_rounded, size: 18, color: t.text3),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '还没绑定 Minecraft 账号，绑定后就能看到自己的段位',
                    style: TextStyle(
                        color: t.text3, fontSize: 12.5, height: 1.4),
                  ),
                ),
                GlassChip(
                  label: '去绑定',
                  icon: Icons.link_rounded,
                  onTap: () => _openWeb('绑定游戏账号', '/me'),
                ),
              ],
            ),
    );
  }

  Widget _menu(GlassTokens t) {
    final items = <({String label, String sub, IconData icon, VoidCallback onTap})>[
      (
        label: '私信',
        sub: _state.unread.dm > 0 ? '${_state.unread.dm} 条未读' : '和站友聊天',
        icon: Icons.chat_bubble_rounded,
        onTap: () => _openWeb('私信', '/dm'),
      ),
      (
        label: '好友',
        sub: '好友申请 · 好友列表',
        icon: Icons.group_rounded,
        onTap: () => _openWeb('好友', '/friends'),
      ),
      (
        label: '会员与充值',
        sub: '赞助支持服务器',
        icon: Icons.card_giftcard_rounded,
        onTap: () => _openWeb('会员与充值', '/pay'),
      ),
      (
        label: '活动与签到',
        sub: '节日活动 · 每日签到',
        icon: Icons.celebration_rounded,
        onTap: () => _openWeb('活动与签到', '/festival'),
      ),
      (
        label: '全站设置（网页）',
        sub: '隐私 · 通知 · 头像',
        icon: Icons.tune_rounded,
        onTap: () => _openWeb('设置', '/me'),
      ),
    ];
    return GlassPanel(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(color: t.divider, height: 1, indent: 54),
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              leading: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: t.fill,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: t.stroke),
                ),
                child: Icon(items[i].icon, size: 17, color: t.text2),
              ),
              title: Text(items[i].label,
                  style: TextStyle(color: t.text, fontSize: 14)),
              subtitle: Text(items[i].sub,
                  style: TextStyle(color: t.text3, fontSize: 11.5)),
              trailing:
                  Icon(Icons.chevron_right_rounded, color: t.text3, size: 20),
              onTap: items[i].onTap,
            ),
          ],
        ],
      ),
    );
  }

  Widget _about(GlassTokens t) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            leading: Icon(Icons.system_update_rounded,
                size: 19, color: t.text2),
            title: Text('检查更新',
                style: TextStyle(color: t.text, fontSize: 14)),
            subtitle: Text('当前版本 ${AppMeta.versionLabel}',
                style: TextStyle(color: t.text3, fontSize: 11.5)),
            trailing: _checking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.chevron_right_rounded, color: t.text3, size: 20),
            onTap: _checkUpdate,
          ),
          Divider(color: t.divider, height: 1, indent: 54),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            leading: Icon(Icons.groups_rounded, size: 19, color: t.text2),
            title: Text('加入 QQ 群',
                style: TextStyle(color: t.text, fontSize: 14)),
            subtitle: Text('群号 ${_state.me?.qqGroup ?? AppMeta.qqGroupFallback}',
                style: TextStyle(color: t.text3, fontSize: 11.5)),
            trailing: Icon(Icons.chevron_right_rounded, color: t.text3, size: 20),
            onTap: () => UpdateService.openUrl(
              'https://qm.qq.com/q/${_state.me?.qqGroup ?? AppMeta.qqGroupFallback}',
            ),
          ),
          Divider(color: t.divider, height: 1, indent: 54),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            leading: Icon(Icons.dns_rounded, size: 19, color: t.text2),
            title: Text('服务器设置',
                style: TextStyle(color: t.text, fontSize: 14)),
            subtitle: Text(Api.i.host == '' ? Api.i.base : Api.i.host,
                style: TextStyle(color: t.text3, fontSize: 11.5)),
            trailing: Icon(Icons.chevron_right_rounded, color: t.text3, size: 20),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkUpdate() async {
    setState(() => _checking = true);
    final info = await UpdateService.check();
    if (!mounted) return;
    setState(() => _checking = false);
    if (info == null) {
      _snack('检查更新失败（服务器未提供更新清单，或网络不通）');
      return;
    }
    if (!info.hasNewer) {
      _snack('已是最新版本 ${AppMeta.version}');
      return;
    }
    await GlassSheet.show<void>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('发现新版本 ${info.version}',
              style: TextStyle(
                  color: GlassTokens.of(context).text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            '当前 ${AppMeta.version}'
            '${info.sizeLabel.isEmpty ? '' : ' · 安装包 ${info.sizeLabel}'}',
            style: TextStyle(
                color: GlassTokens.of(context).text3, fontSize: 12),
          ),
          if (info.notes.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...info.notes.map((n) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.circle,
                          size: 5,
                          color: GlassTokens.of(context).accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(n,
                            style: TextStyle(
                                color: GlassTokens.of(context).text2,
                                fontSize: 13,
                                height: 1.45)),
                      ),
                    ],
                  ),
                )),
          ],
          const SizedBox(height: 18),
          GlassButton(
            label: info.canDownload ? '立即下载' : '暂无下载地址',
            icon: Icons.download_rounded,
            primary: true,
            onTap: info.canDownload
                ? () async {
                    Navigator.of(context).pop();
                    final ok = await UpdateService.download(info);
                    if (!ok) _snack('已复制下载链接，请粘贴到浏览器打开');
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final ok = await GlassDialog.confirm(
      context,
      title: '退出登录？',
      message: '退出后需要重新输入密码才能看消息和个人数据。',
      okLabel: '退出',
      danger: true,
    );
    if (ok == true) {
      await _state.logout();
      if (mounted) setState(() => _myRank = null);
    }
  }

  void _openLogin() {
    GlassSheet.show<void>(context, child: const LoginSheet());
  }

  void _openWeb(String title, String path) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WebPage(title: title, path: path)),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

/// 登录 / 注册弹层（原生表单，比跳网页快）
class LoginSheet extends StatefulWidget {
  const LoginSheet({super.key});

  @override
  State<LoginSheet> createState() => _LoginSheetState();
}

class _LoginSheetState extends State<LoginSheet> {
  final _u = TextEditingController();
  final _p = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _u.dispose();
    _p.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final u = _u.text.trim();
    final p = _p.text;
    if (u.length < 3) {
      setState(() => _err = '用户名至少 3 个字符');
      return;
    }
    if (p.length < 6) {
      setState(() => _err = '密码至少 6 位');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      if (_register) {
        await AppState.i.register(u, p);
      } else {
        await AppState.i.login(u, p);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_register ? '注册成功，欢迎加入同禾境！' : '登录成功')),
      );
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    InputDecoration deco(String hint, IconData icon) => InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: t.text3, fontSize: 14),
          prefixIcon: Icon(icon, size: 19, color: t.text3),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_register ? '注册账号' : '登录同禾境',
            style: TextStyle(
                color: t.text, fontSize: 19, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          _register ? '注册后即可绑定游戏账号、收消息、上榜' : '用你的网站账号登录',
          style: TextStyle(color: t.text3, fontSize: 12.5),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: t.fill,
            borderRadius: BorderRadius.circular(R.tile),
            border: Border.all(color: t.stroke),
          ),
          child: TextField(
            controller: _u,
            autocorrect: false,
            style: TextStyle(color: t.text),
            decoration: deco('用户名 / 邮箱', Icons.person_outline_rounded),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: t.fill,
            borderRadius: BorderRadius.circular(R.tile),
            border: Border.all(color: t.stroke),
          ),
          child: TextField(
            controller: _p,
            obscureText: true,
            style: TextStyle(color: t.text),
            onSubmitted: (_) => _submit(),
            decoration: deco('密码', Icons.lock_outline_rounded),
          ),
        ),
        if (_err != null) ...[
          const SizedBox(height: 10),
          Text(_err!,
              style: TextStyle(
                  color: GlassTokens.danger, fontSize: 12.5, height: 1.4)),
        ],
        const SizedBox(height: 16),
        GlassButton(
          label: _register ? '注册并登录' : '登录',
          icon: Icons.login_rounded,
          primary: true,
          loading: _busy,
          onTap: _busy ? null : _submit,
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                      _register = !_register;
                      _err = null;
                    }),
            child: Text(
              _register ? '已有账号？去登录' : '没有账号？去注册',
              style: TextStyle(color: t.accent, fontSize: 13),
            ),
          ),
        ),
        Center(
          child: Text(
            '遇到问题可到网页端登录（点下方按钮）',
            style: TextStyle(color: t.text3, fontSize: 11.5),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: GlassChip(
            label: '用网页登录',
            icon: Icons.open_in_new_rounded,
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const WebPage(title: '网页登录', path: '/login'),
              ));
            },
          ),
        ),
      ],
    );
  }
}
