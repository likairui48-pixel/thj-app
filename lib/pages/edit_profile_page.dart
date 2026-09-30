import 'package:flutter/material.dart';

import '../app/bg_presets.dart';
import '../app/theme.dart';
import '../core/api.dart';
import '../core/img.dart';
import '../core/store.dart';
import '../widgets/glass.dart';

/// ============================================================
///  编辑我的资料（原生）
///  头像上传 / 主页背景（12 种预设 + 自己上传）/ 签名 / 标签
///
///  注意：站点 POST /api/profile 会一次性写 bio + profile_bg + tags，
///  所以保存时必须把「当前的背景值」一起带上，否则会把背景清空。
/// ============================================================
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _bio = TextEditingController();
  final _tag = TextEditingController();

  final _tags = <String>[];
  bool _loading = true;
  bool _saving = false;
  bool _busyImg = false;
  String? _err;
  String? _bgCode; // 预设代号或上传后的 URL
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _bio.dispose();
    _tag.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final me = AppState.i.me;
      final j = await Api.i.profile(me?.username ?? '');
      final p = ProfileData.fromJson(j);
      final bgj = await Api.i.get('/api/me/bg');
      if (!mounted) return;
      setState(() {
        _bio.text = p.bio;
        _tags
          ..clear()
          ..addAll(p.tags);
        _bgCode = asStrOrNull(bgj['bg']) ?? (p.bg?.isEmpty == true ? null : p.bg);
        _avatarUrl = p.user.avatarUrl;
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

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await Api.i.saveProfile(
        bio: _bio.text.trim(),
        bg: _bgCode ?? '',
        tags: _tags,
      );
      await AppState.i.refreshBrandAndMe();
      if (!mounted) return;
      _toast('已保存');
      Navigator.of(context).pop(true);
    } catch (e) {
      _toast(e is ApiError ? e.message : '保存失败');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final data = await Img.pickDataUrl(maxEdge: 800, quality: 88);
      if (data == null) return;
      setState(() => _busyImg = true);
      final r = await Api.i.setAvatar(data);
      final url = asStr(r['avatar']);
      await AppState.i.refreshBrandAndMe();
      if (!mounted) return;
      setState(() => _avatarUrl = url.isEmpty ? null : Api.i.abs(url));
      _toast('头像已更新');
    } catch (e) {
      _toast(e is ApiError ? e.message : '上传失败');
    } finally {
      if (mounted) setState(() => _busyImg = false);
    }
  }

  Future<void> _delAvatar() async {
    try {
      await Api.i.deleteAvatar();
      await AppState.i.refreshBrandAndMe();
      if (!mounted) return;
      setState(() => _avatarUrl = null);
      _toast('已恢复默认头像');
    } catch (e) {
      _toast(e is ApiError ? e.message : '操作失败');
    }
  }

  Future<void> _pickBg() async {
    try {
      final data = await Img.pickDataUrl(maxEdge: 1600, quality: 86);
      if (data == null) return;
      setState(() => _busyImg = true);
      final r = await Api.i.setProfileBg(data);
      final url = asStr(r['url']);
      await AppState.i.refreshBrandAndMe();
      if (!mounted) return;
      setState(() => _bgCode = url);
      _toast('背景已更新（已自动裁剪成 1600×600）');
    } catch (e) {
      _toast(e is ApiError ? e.message : '上传失败');
    } finally {
      if (mounted) setState(() => _busyImg = false);
    }
  }

  Future<void> _clearBg() async {
    try {
      await Api.i.deleteProfileBg();
      await AppState.i.refreshBrandAndMe();
      if (!mounted) return;
      setState(() => _bgCode = null);
      _toast('已恢复默认背景');
    } catch (e) {
      _toast(e is ApiError ? e.message : '操作失败');
    }
  }

  void _addTag() {
    final v = _tag.text.trim();
    if (v.isEmpty) return;
    if (_tags.length >= 6) return _toast('最多 6 个标签');
    if (v.length > 12) return _toast('单个标签最多 12 字');
    if (_tags.contains(v)) return _toast('这个标签已经有了');
    setState(() {
      _tags.add(v);
      _tag.clear();
    });
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    if (!(AppState.i.me?.loggedIn ?? false)) {
      return AuroraBg(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('编辑资料')),
          body: const Padding(
            padding: EdgeInsets.all(16),
            child: EmptyHint(text: '请先登录', icon: Icons.lock_outline_rounded),
          ),
        ),
      );
    }
    return AuroraBg(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('编辑资料'),
          actions: [
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('保存',
                      style: TextStyle(
                          color: t.accent, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: _loading
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Column(children: [
                  GlassSkeleton(height: 120, radius: 18),
                  SizedBox(height: 12),
                  GlassSkeleton(height: 60, radius: 16),
                ]),
              )
            : _err != null
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: ErrorPanel(message: _err!, onRetry: _load),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 40),
                    children: [
                      _bgPicker(t),
                      const SizedBox(height: 14),
                      _avatarRow(t),
                      const SectionTitle(title: '签名'),
                      GlassPanel(
                        padding: const EdgeInsets.all(12),
                        child: TextField(
                          controller: _bio,
                          maxLines: 4,
                          maxLength: 300,
                          style: TextStyle(fontSize: 14, color: t.text),
                          decoration: InputDecoration(
                            hintText: '写点什么介绍自己（≤300 字）',
                            hintStyle:
                                TextStyle(fontSize: 13, color: t.text3),
                            border: InputBorder.none,
                            counterStyle:
                                TextStyle(fontSize: 10.5, color: t.text3),
                          ),
                        ),
                      ),
                      const SectionTitle(
                          title: '标签', sub: '最多 6 个，每个 ≤12 字'),
                      GlassPanel(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                ..._tags.map((x) => GestureDetector(
                                      onTap: () =>
                                          setState(() => _tags.remove(x)),
                                      child: GlassChip(
                                          label: '$x ✕', active: true),
                                    )),
                                if (_tags.isEmpty)
                                  Text('还没有标签',
                                      style: TextStyle(
                                          fontSize: 12, color: t.text3)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _tag,
                                    maxLength: 12,
                                    onSubmitted: (_) => _addTag(),
                                    style: TextStyle(
                                        fontSize: 13.5, color: t.text),
                                    decoration: InputDecoration(
                                      hintText: '例如：建筑党 / 红石',
                                      hintStyle: TextStyle(
                                          fontSize: 12.5, color: t.text3),
                                      counterText: '',
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 10),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        borderSide:
                                            BorderSide(color: t.stroke),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                            color: t.accent, width: 1.3),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GlassButton(
                                    label: '添加',
                                    expand: false,
                                    height: 38,
                                    onTap: _addTag),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      GlassButton(
                        label: '保存资料',
                        icon: Icons.check_rounded,
                        primary: true,
                        loading: _saving,
                        onTap: _saving ? null : _save,
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _avatarRow(GlassTokens t) {
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          GestureDetector(
            onTap: _busyImg ? null : _pickAvatar,
            onLongPress: _delAvatar,
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.fillStrong,
                border: Border.all(color: t.stroke),
              ),
              clipBehavior: Clip.antiAlias,
              child: _busyImg
                  ? const Center(
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)))
                  : (_avatarUrl == null
                      ? Icon(Icons.person_rounded, size: 30, color: t.text3)
                      : Image.network(_avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (a, b, s) => Icon(
                              Icons.person_rounded,
                              size: 30,
                              color: t.text3))),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('头像',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: t.text)),
                const SizedBox(height: 4),
                Text('点一下从相册选图（自动裁成方形）；长按恢复默认',
                    style: TextStyle(
                        fontSize: 11.5, color: t.text3, height: 1.5)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    GlassButton(
                        label: '换头像',
                        expand: false,
                        height: 34,
                        onTap: _busyImg ? null : _pickAvatar),
                    const SizedBox(width: 8),
                    GlassButton(
                        label: '恢复默认',
                        expand: false,
                        height: 34,
                        onTap: _delAvatar),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bgPicker(GlassTokens t) {
    final grad = gradientForBg(_bgCode);
    final isUploaded = _bgCode != null && _bgCode!.startsWith('/');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: '主页背景', sub: '预设图或自己的照片（8:3）'),
        Container(
          height: 108,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(R.card),
            gradient: grad ??
                (isUploaded
                    ? null
                    : const LinearGradient(colors: [
                        Color(0xFF2E9E63),
                        Color(0xFF2FA6A0),
                      ])),
            image: isUploaded
                ? DecorationImage(
                    image: NetworkImage(Api.i.abs(_bgCode!)),
                    fit: BoxFit.cover)
                : null,
            border: Border.all(color: t.stroke),
          ),
          alignment: Alignment.bottomRight,
          padding: const EdgeInsets.all(10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GlassButton(
                  label: '上传图片',
                  expand: false,
                  height: 34,
                  icon: Icons.upload_rounded,
                  onTap: _busyImg ? null : _pickBg),
              if (_bgCode != null) ...[
                const SizedBox(width: 8),
                GlassButton(
                    label: '清除',
                    expand: false,
                    height: 34,
                    onTap: _clearBg),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kBgPresets.map((p) {
            final on = _bgCode == p.code;
            return GestureDetector(
              onTap: () => setState(() => _bgCode = p.code),
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 34,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: p.colors),
                      border: Border.all(
                          color: on ? t.accent : t.stroke,
                          width: on ? 2 : 1),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(p.label,
                      style: TextStyle(
                          fontSize: 10,
                          color: on ? t.accent : t.text3)),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
