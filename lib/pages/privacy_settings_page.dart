import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/api.dart';
import '../core/store.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import 'login_page.dart';

/// ============================================================
///  隐私设置（原生）
///  服务端把「项目名 + 可选项」一起返回，这里照着渲染，
///  将来站点加新项，App 不用改代码就能出现。
/// ============================================================
class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  PrivacyData? _data;
  bool _loading = true;
  String? _err;
  String? _savingKey;

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
        _data = PrivacyData.fromJson(j);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = e is ApiError ? e.message : e.toString();
      });
    }
  }

  Future<void> _set(String key, String value) async {
    final d = _data;
    if (d == null || _savingKey != null) return;
    final old = d.privacy[key];
    setState(() {
      _savingKey = key;
      d.privacy[key] = value;
    });
    try {
      final j = await Api.i.setPrivacy(<String, dynamic>{key: value});
      if (!mounted) return;
      setState(() {
        _data = PrivacyData.fromJson(j);
        _savingKey = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        d.privacy[key] = old ?? 'all';
        _savingKey = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is ApiError ? e.message : '保存失败'),
          behavior: SnackBarBehavior.floating));
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
          title: const Text('隐私设置'),
        ),
        body: !(AppState.i.me?.loggedIn ?? false)
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const EmptyHint(
                        text: '登录后才能设置隐私', icon: Icons.lock_outline_rounded),
                    const SizedBox(height: 12),
                    GlassButton(
                        label: '去登录',
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const LoginPage()))),
                  ],
                ),
              )
            : _loading
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(children: [
                      GlassSkeleton(height: 64, radius: 16),
                      SizedBox(height: 10),
                      GlassSkeleton(height: 64, radius: 16),
                      SizedBox(height: 10),
                      GlassSkeleton(height: 64, radius: 16),
                    ]),
                  )
                : _err != null
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: ErrorPanel(message: _err!, onRetry: _load),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 40),
                        children: [
                          GlassPanel(
                            padding: const EdgeInsets.all(13),
                            child: Row(
                              children: [
                                Icon(Icons.shield_outlined,
                                    size: 18, color: t.accent),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    '「仅好友」= 加为好友才能看到；「仅自己」= 谁都看不到（管理员为了处理举报仍可查看）。',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: t.text3,
                                        height: 1.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...(_data!.items.entries.map((e) => _row(e.key, e.value, t))),
                        ],
                      ),
      ),
    );
  }

  Widget _row(String key, List<dynamic> item, GlassTokens t) {
    final title = item.isNotEmpty ? item[0].toString() : key;
    final options = (item.length > 1 && item[1] is List)
        ? (item[1] as List).map((x) => x.toString()).toList()
        : <String>['all', 'friends', 'self'];
    final cur = _data!.privacy[key] ?? options.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassPanel(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: t.text)),
                ),
                if (_savingKey == key)
                  const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: options
                  .map((o) => GlassChip(
                        label: PrivacyData.valueLabels[o] ?? o,
                        active: cur == o,
                        onTap: () => _set(key, o),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
