import 'package:flutter/material.dart';

import '../app/config.dart';
import '../app/theme.dart';
import '../core/api.dart';
import '../core/notify.dart';
import '../core/store.dart';
import '../core/update.dart';
import '../widgets/glass.dart';

/// 设置：主题 / 通知 / 服务器地址 / 诊断 / 关于
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _state = AppState.i;
  final _urlCtrl = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _state.addListener(_onChange);
    _urlCtrl.text = Api.i.base;
  }

  @override
  void dispose() {
    _state.removeListener(_onChange);
    _urlCtrl.dispose();
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, R.page, 8),
              child: Row(
                children: [
                  GlassIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Text('设置',
                      style: TextStyle(
                          color: t.text,
                          fontSize: 19,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(R.page, 4, R.page, 26),
                children: [
                  _section(t, '外观'),
                  GlassPanel(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('主题',
                            style: TextStyle(
                                color: t.text2, fontSize: 13)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _themeChip(t, '跟随系统', ThemeMode.system,
                                Icons.brightness_auto_rounded),
                            const SizedBox(width: 8),
                            _themeChip(
                                t, '白', ThemeMode.light, Icons.light_mode_rounded),
                            const SizedBox(width: 8),
                            _themeChip(
                                t, '黑', ThemeMode.dark, Icons.dark_mode_rounded),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _state.reduceMotion,
                          activeColor: t.accent,
                          title: Text('减弱动画',
                              style: TextStyle(color: t.text, fontSize: 13.5)),
                          onChanged: (v) => _state.setReduceMotion(v),
                        ),
                      ],
                    ),
                  ),
                  _section(t, '消息与通知'),
                  GlassPanel(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        SwitchListTile.adaptive(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          value: _state.notifyEnabled,
                          activeColor: t.accent,
                          title: Text('系统通知提醒',
                              style: TextStyle(color: t.text, fontSize: 14)),
                          subtitle: Text('有新消息时在通知栏提醒',
                              style: TextStyle(
                                  color: t.text3, fontSize: 11.5)),
                          onChanged: (v) => _state.setNotifyEnabled(v),
                        ),
                        Divider(color: t.divider, height: 1),
                        ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          title: Text('申请通知权限',
                              style: TextStyle(color: t.text, fontSize: 14)),
                          subtitle: Text(
                            'Android 13 及以上需要手动授权',
                            style:
                                TextStyle(color: t.text3, fontSize: 11.5),
                          ),
                          trailing: Icon(Icons.notifications_active_rounded,
                              size: 18, color: t.accent),
                          onTap: () async {
                            final ok = await NotifyService.i.ensurePermission();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(ok
                                      ? '通知权限已开启'
                                      : '未获得权限，可到系统设置里打开')),
                            );
                          },
                        ),
                        Divider(color: t.divider, height: 1),
                        ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          title: Text('测试通知',
                              style: TextStyle(color: t.text, fontSize: 14)),
                          subtitle: Text('发一条看看能不能收到',
                              style: TextStyle(
                                  color: t.text3, fontSize: 11.5)),
                          trailing: Icon(Icons.send_rounded,
                              size: 18, color: t.text2),
                          onTap: () => NotifyService.i.show(
                            id: 999,
                            title: '同禾境 · 通知测试',
                            body: '如果你看到这条通知，说明消息提醒工作正常 🎉',
                          ),
                        ),
                      ],
                    ),
                  ),
                  _section(t, '服务器地址'),
                  GlassPanel(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '当前：${Api.i.base}\n状态：${Api.i.online ? '连接正常' : '连不上，试试切换地址'}',
                          style: TextStyle(
                              color: Api.i.online ? t.text2 : GlassTokens.warn,
                              fontSize: 12.5,
                              height: 1.6),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: t.fill,
                            borderRadius: BorderRadius.circular(R.tile),
                            border: Border.all(color: t.stroke),
                          ),
                          child: TextField(
                            controller: _urlCtrl,
                            style: TextStyle(color: t.text, fontSize: 13.5),
                            decoration: InputDecoration(
                              hintText: 'https://你的域名',
                              hintStyle:
                                  TextStyle(color: t.text3, fontSize: 13),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 13),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: GlassButton(
                                label: _busy ? '切换中…' : '应用地址',
                                icon: Icons.check_rounded,
                                loading: _busy,
                                onTap: _busy ? null : _applyUrl,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GlassButton(
                                label: '恢复默认',
                                icon: Icons.restore_rounded,
                                onTap: () async {
                                  await Api.i.resetBase();
                                  _urlCtrl.text = Api.i.base;
                                  await _state.refreshStatus();
                                  if (mounted) setState(() {});
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: Endpoints.defaults
                              .map((u) => GlassChip(
                                    label: u.replaceFirst('https://', ''),
                                    active: Api.i.base == u,
                                    onTap: () {
                                      _urlCtrl.text = u;
                                      _applyUrl();
                                    },
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                  _section(t, '显示'),
                  GlassPanel(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: SwitchListTile.adaptive(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      value: _state.showFakes,
                      activeColor: t.accent,
                      title: Text('显示机器人 / 假人账号',
                          style: TextStyle(color: t.text, fontSize: 14)),
                      subtitle: Text('默认折叠，榜单更干净',
                          style: TextStyle(color: t.text3, fontSize: 11.5)),
                      onChanged: (v) => _state.setShowFakes(v),
                    ),
                  ),
                  _section(t, '关于'),
                  GlassPanel(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          title: Text('当前版本',
                              style: TextStyle(color: t.text, fontSize: 14)),
                          trailing: Text(AppMeta.versionLabel,
                              style: TextStyle(color: t.text3, fontSize: 12.5)),
                        ),
                        Divider(color: t.divider, height: 1),
                        ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          title: Text('检查更新',
                              style: TextStyle(color: t.text, fontSize: 14)),
                          trailing: Icon(Icons.system_update_rounded,
                              size: 18, color: t.accent),
                          onTap: () async {
                            final info = await UpdateService.check();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(info == null
                                    ? '暂时拿不到更新信息'
                                    : (info.hasNewer
                                        ? '发现新版本 ${info.version}，去「我的」页更新'
                                        : '已是最新版本')),
                              ),
                            );
                          },
                        ),
                        Divider(color: t.divider, height: 1),
                        ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          title: Text('运行诊断',
                              style: TextStyle(color: t.text, fontSize: 14)),
                          subtitle: Text(
                            '会话：${Api.i.hasSession ? '已登录' : '未登录'} · '
                            '地址：${Api.i.host}',
                            style:
                                TextStyle(color: t.text3, fontSize: 11.5),
                          ),
                          trailing: Icon(Icons.bug_report_rounded,
                              size: 18, color: t.text2),
                          onTap: _diagnose,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      '同禾境 · 社区客户端\n液态玻璃 / 黑白双主题',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: t.text3, fontSize: 11.5, height: 1.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(GlassTokens t, String title) => SectionTitleSmall(title: title);

  Widget _themeChip(
      GlassTokens t, String label, ThemeMode mode, IconData icon) {
    return Expanded(
      child: GlassChip(
        label: label,
        icon: icon,
        active: _state.themeMode == mode,
        onTap: () => _state.setThemeMode(mode),
      ),
    );
  }

  Future<void> _applyUrl() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() => _busy = true);
    await Api.i.setBase(url);
    await _state.refreshStatus();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(Api.i.online ? '地址已切换，连接正常' : '已保存，但当前连不上这个地址'),
      ),
    );
  }

  Future<void> _diagnose() async {
    final buf = StringBuffer();
    buf.writeln('App：${AppMeta.versionLabel}');
    buf.writeln('地址：${Api.i.base}');
    buf.writeln('会话：${Api.i.hasSession ? '有 Cookie' : '无 Cookie'}');
    try {
      final j = await Api.i.get('/api/health');
      buf.writeln('健康：ok=${j['ok']}');
      final rcon = asMap(j['rcon']);
      buf.writeln('RCON：${rcon['connected']}');
      final scan = asMap(j['scan']);
      buf.writeln('扫描：${scan['lastCount']} 人');
    } catch (e) {
      buf.writeln('健康检查失败：$e');
    }
    try {
      final s = await Api.i.status();
      buf.writeln('在线：${s['online']}/${s['max']}');
    } catch (e) {
      buf.writeln('状态失败：$e');
    }
    if (!mounted) return;
    await GlassSheet.show<void>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('运行诊断',
              style: TextStyle(
                  color: GlassTokens.of(context).text,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          SelectableText(
            buf.toString(),
            style: TextStyle(
              color: GlassTokens.of(context).text2,
              fontSize: 12.5,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class SectionTitleSmall extends StatelessWidget {
  const SectionTitleSmall({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        title,
        style: TextStyle(
          color: t.text3,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
