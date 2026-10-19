import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/cache.dart';
import '../core/meta.dart';
import '../core/state.dart';
import '../core/ui.dart';
import '../core/update_ui.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _state = AppState.i;

  Future<void> _checkUpdate() async {
    await _state.checkUpdate();
    if (!mounted) return;
    if (_state.update == null) {
      showToast(context, '检查更新失败，请稍后再试', error: true);
    } else if (!_state.update!.hasNewer) {
      showToast(context, '已是最新版本 ${AppMeta.version}');
    } else {
      await showUpdateDialog(context, _state.update!);
    }
  }

  Future<void> _changePassword() async {
    final oldPwd = TextEditingController();
    final newPwd = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPwd,
              obscureText: true,
              decoration: const InputDecoration(labelText: '当前密码'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: newPwd,
              obscureText: true,
              decoration: const InputDecoration(labelText: '新密码（至少 6 位）'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await Api.i.changePassword(oldPwd.text, newPwd.text);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) showToast(context, '密码已修改');
              } catch (e) {
                if (ctx.mounted) {
                  showToast(ctx, e.toString(), error: true);
                }
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    oldPwd.dispose();
    newPwd.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppPage(
      title: '设置',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        children: [
          const SectionTitle(title: '外观'),
          AppCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Text('主题',
                        style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 8),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                        value: ThemeMode.system, label: Text('跟随系统')),
                    ButtonSegment(value: ThemeMode.light, label: Text('白天')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('黑夜')),
                  ],
                  selected: {_state.themeMode},
                  onSelectionChanged: (s) => _state.setThemeMode(s.first),
                  showSelectedIcon: false,
                ),
                const Divider(height: 22),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('减少动画'),
                  subtitle: const Text('低配手机 / 晕动症友好'),
                  value: _state.reduceMotion,
                  onChanged: _state.setReduceMotion,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('展开假人'),
                  subtitle: const Text('默认折叠服务器机器人账号'),
                  value: _state.showFakes,
                  onChanged: _state.setShowFakes,
                ),
              ],
            ),
          ),
          const SectionTitle(title: '消息与提醒'),
          AppCard(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('系统通知'),
                  subtitle: const Text('私信、回复、好友申请、活动提醒'),
                  value: _state.notifyEnabled,
                  onChanged: _state.setNotifyEnabled,
                ),
                const Divider(height: 18),
                _rtModeTile(
                  context,
                  0,
                  '仅在打开 App 时接收',
                  '最省电，通知栏没有残留。代价：App 关着时收不到提醒。',
                ),
                _rtModeTile(
                  context,
                  1,
                  '后台实时接收',
                  '锁屏 / 切到别的 App 也能秒收（长连接）。代价：通知栏常驻一条静默通知，后台略耗电。',
                ),
                _rtModeTile(
                  context,
                  2,
                  '后台实时 + 省电白名单',
                  '最稳。建议在系统设置里允许自启动 / 不优化电池。',
                ),
                const Divider(height: 18),
                ActionTile(
                  icon: Icons.lock_outline_rounded,
                  title: '隐私设置',
                  sub: '资料、游戏数据、加好友、私信',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PrivacyPage()),
                  ),
                ),
                ActionTile(
                  icon: Icons.notifications_none_rounded,
                  title: '游戏内提醒',
                  sub: '哪些消息同步提醒到 Minecraft',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NotifySettingsPage()),
                  ),
                ),
              ],
            ),
          ),
          const SectionTitle(title: '账号'),
          AppCard(
            child: Column(
              children: [
                ActionTile(
                  icon: Icons.password_rounded,
                  title: '修改密码',
                  sub: '建议使用与其他网站不同的密码',
                  onTap: _changePassword,
                ),
                ActionTile(
                  icon: Icons.cleaning_services_outlined,
                  title: '清理缓存',
                  sub: '首页、榜单、帖子缓存',
                  onTap: () async {
                    await Cache.clear();
                    if (mounted) showToast(context, '缓存已清理');
                  },
                ),
                ActionTile(
                  icon: Icons.system_update_alt_rounded,
                  title: '检查更新',
                  sub: '当前 v${AppMeta.version} (${AppMeta.versionCode})',
                  onTap: _checkUpdate,
                ),
                if (_state.isLoggedIn)
                  ActionTile(
                    icon: Icons.logout_rounded,
                    title: '退出登录',
                    onTap: () async {
                      final ok = await showConfirm(
                        context,
                        title: '退出登录',
                        message: '退出后需要重新输入密码才能看消息和个人数据。',
                        okText: '退出',
                        danger: true,
                      );
                      if (!ok) return;
                      await _state.logout();
                      if (mounted) Navigator.pop(context);
                    },
                    color: AppColors.danger,
                  ),
              ],
            ),
          ),
          const SectionTitle(title: '关于'),
          AppCard(
            child: Column(
              children: [
                InfoRow(label: '服务器', value: _state.serverAddress),
                InfoRow(label: '备用 IP', value: _state.serverIp),
                InfoRow(label: '玩家群', value: _state.qqGroup),
                InfoRow(label: '版本', value: '${AppMeta.version} (${AppMeta.versionCode})'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final uri = Uri.tryParse(AppMeta.siteUrl);
                          if (uri != null) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          }
                        },
                        icon: const Icon(Icons.language_rounded, size: 17),
                        label: const Text('打开网站'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final uri = Uri.tryParse(
                              'https://qm.qq.com/q/${_state.qqGroup}');
                          if (uri != null) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          }
                        },
                        icon: const Icon(Icons.groups_rounded, size: 17),
                        label: const Text('加入玩家群'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              '同禾境 · 与方块世界同行',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 10.5,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rtModeTile(
      BuildContext context, int value, String title, String desc) {
    final on = _state.rtMode == value;
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _state.setRtMode(value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              on ? Icons.radio_button_checked : Icons.radio_button_off,
              color: on ? AppColors.brand : cs.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 12.5,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 10.5,
                      height: 1.5,
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
}

/* ============================================================
 * 隐私设置
 * ============================================================ */

class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key});

  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  bool _loading = true;
  String? _err;
  Map<String, dynamic> _items = <String, dynamic>{};
  Map<String, dynamic> _privacy = <String, dynamic>{};

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
      final j = await Api.i.privacy();
      if (!mounted) return;
      setState(() {
        _items = asMap(j['items']);
        _privacy = asMap(j['privacy']);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _err = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _save(String key, String value) async {
    final next = Map<String, dynamic>.from(_privacy);
    next[key] = value;
    setState(() => _privacy = next);
    try {
      await Api.i.setPrivacy(next);
      if (mounted) showToast(context, '已保存');
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = <String, String>{
      'all': '所有人',
      'friends': '仅好友',
      'self': '仅自己',
      'none': '关闭',
    };
    return AppPage(
      title: '隐私设置',
      child: AsyncView(
        loading: _loading,
        error: _err,
        onRetry: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          children: [
            Text(
              '控制别人能看到什么、能不能加你、能不能私信你。修改后立即生效。',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 12),
            ..._items.entries.map((e) {
              final raw = e.value;
              final label = raw is List && raw.isNotEmpty
                  ? asStr(raw[0], e.key)
                  : e.key;
              final values = raw is List && raw.length > 1 && raw[1] is List
                  ? (raw[1] as List).map((x) => asStr(x)).toList()
                  : ['all', 'friends', 'self', 'none'];
              final current = asStr(_privacy[e.key], values.first);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  padding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      DropdownButton<String>(
                        value: values.contains(current)
                            ? current
                            : values.first,
                        underline: const SizedBox.shrink(),
                        items: values
                            .map(
                              (v) => DropdownMenuItem(
                                value: v,
                                child: Text(
                                  labels[v] ?? v,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) _save(e.key, v);
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/* ============================================================
 * 游戏内提醒
 * ============================================================ */

class NotifySettingsPage extends StatefulWidget {
  const NotifySettingsPage({super.key});

  @override
  State<NotifySettingsPage> createState() => _NotifySettingsPageState();
}

class _NotifySettingsPageState extends State<NotifySettingsPage> {
  bool _loading = true;
  String? _err;
  bool _bound = false;
  String _mcName = '';
  List<Map<String, dynamic>> _items = const [];
  Map<String, dynamic> _notify = <String, dynamic>{};

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
      final j = await Api.i.notifySettings();
      if (!mounted) return;
      final rawItems = j['items'];
      final items = <Map<String, dynamic>>[];
      if (rawItems is List) {
        for (final it in rawItems) {
          if (it is List && it.length >= 2) {
            items.add({
              'key': asStr(it[0]),
              'label': asStr(it[1]),
              'desc': it.length > 2 ? asStr(it[2]) : '',
            });
          }
        }
      }
      setState(() {
        _bound = asBool(j['bound']);
        _mcName = asStr(j['mcName']);
        _items = items;
        _notify = asMap(j['notify']);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _err = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    try {
      await Api.i.setNotifySettings(_notify);
      if (mounted) showToast(context, '提醒设置已保存');
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: '游戏内提醒',
      actions: [
        TextButton(
          onPressed: _loading ? null : _save,
          child: const Text('保存'),
        ),
      ],
      child: AsyncView(
        loading: _loading,
        error: _err,
        onRetry: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          children: [
            AppCard(
              child: Row(
                children: [
                  const Icon(Icons.sports_esports_rounded,
                      color: AppColors.brand, size: 22),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      _bound
                          ? '已绑定 $_mcName，消息会同步提醒到游戏'
                          : '尚未绑定游戏账号，绑定后才能同步提醒',
                      style: const TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                children: [
                  for (final it in _items)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(asStr(it['label'])),
                      subtitle: asStr(it['desc']).isEmpty
                          ? null
                          : Text(
                              asStr(it['desc']),
                              style: const TextStyle(fontSize: 11),
                            ),
                      value: asBool(_notify[asStr(it['key'])]),
                      onChanged: (v) {
                        setState(() {
                          _notify = {..._notify, asStr(it['key']): v};
                        });
                      },
                    ),
                  if (_items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('暂时没有可设置的提醒项'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
