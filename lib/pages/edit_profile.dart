import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/img.dart';
import '../core/state.dart';
import '../core/ui.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _state = AppState.i;
  final _bio = TextEditingController();
  final _tags = TextEditingController();
  String _avatar = '';
  String _bg = '';
  bool _busy = false;
  bool _uploading = false;

  static const Map<String, List<Color>> _presets = <String, List<Color>>{
    'g1': [Color(0xFF2F9E6B), Color(0xFF7FD1A8)],
    'g2': [Color(0xFF2B7CD3), Color(0xFF7FC4F5)],
    'g3': [Color(0xFF7C5CF0), Color(0xFFC9A7FF)],
    'g4': [Color(0xFFE8A33D), Color(0xFFFFD9A0)],
    'g5': [Color(0xFFE56A9A), Color(0xFFFFC2D8)],
    'g6': [Color(0xFF1F7F57), Color(0xFF9FD97F)],
    'g7': [Color(0xFF14476B), Color(0xFF4AA3C9)],
    'g8': [Color(0xFFC2532C), Color(0xFFF0A06A)],
  };

  @override
  void initState() {
    super.initState();
    final user = _state.user ?? <String, dynamic>{};
    _avatar = asStr(user['avatar']);
    _bg = asStr(user['profileBg'] ??
        user['bg'] ??
        asMap(user['profile'])['bg']);
    _bio.text = asStr(user['bio'] ?? asMap(user['profile'])['bio']);
    _tags.text = asStrList(user['tags']).join(', ');
  }

  @override
  void dispose() {
    _bio.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final d = await ImgPicker.one(maxWidth: 800, quality: 86);
      if (d == null) return;
      setState(() => _uploading = true);
      final j = await Api.i.setAvatar(d);
      final url = asStr(j['avatar']);
      if (!mounted) return;
      setState(() {
        if (url.isNotEmpty) _avatar = url;
      });
      await _state.refreshMe();
      if (mounted) showToast(context, '头像已更新');
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deleteAvatar() async {
    final ok = await showConfirm(
      context,
      title: '恢复默认头像',
      message: '将删除你上传的头像，改用游戏皮肤头像。',
      okText: '恢复默认',
      danger: true,
    );
    if (!ok) return;
    try {
      await Api.i.deleteAvatar();
      await _state.refreshMe();
      if (!mounted) return;
      setState(() => _avatar = '');
      showToast(context, '已恢复默认头像');
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    }
  }

  Future<void> _pickBg() async {
    try {
      final d = await ImgPicker.one(maxWidth: 1600, quality: 84);
      if (d == null) return;
      setState(() => _uploading = true);
      final j = await Api.i.setBg(d);
      final url = asStr(j['bg']);
      if (!mounted) return;
      setState(() {
        if (url.isNotEmpty) _bg = url;
      });
      await _state.refreshMe();
      if (mounted) showToast(context, '背景已更新');
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _clearBg() async {
    try {
      await Api.i.deleteBg();
      await _state.refreshMe();
      if (!mounted) return;
      setState(() => _bg = '');
      showToast(context, '已恢复默认背景');
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    }
  }

  Future<void> _save() async {
    final tags = _tags.text
        .split(RegExp(r'[,，\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(6)
        .toList();
    setState(() => _busy = true);
    try {
      await Api.i.saveProfile(
        bio: _bio.text.trim(),
        bg: _bg,
        tags: tags,
      );
      await _state.refreshMe();
      if (!mounted) return;
      showToast(context, '资料已保存');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = _state.mcName.isEmpty ? _state.username : _state.mcName;
    return AppPage(
      title: '编辑资料',
      actions: [
        TextButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存'),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        children: [
          const SectionTitle(title: '头像'),
          AppCard(
            child: Row(
              children: [
                UserAvatar(
                  name: name,
                  avatar: _avatar,
                  size: 72,
                  ring: true,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '点击右侧按钮上传',
                        style: TextStyle(fontSize: 12.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '支持 PNG / JPG / WebP，会自动裁成方图，全站生效',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 10.5,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _uploading ? null : _pickAvatar,
                            icon: const Icon(Icons.upload_rounded, size: 16),
                            label: const Text('选择图片'),
                          ),
                          if (_avatar.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: _uploading ? null : _deleteAvatar,
                              child: const Text('恢复默认'),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionTitle(title: '个人资料'),
          AppCard(
            child: Column(
              children: [
                TextField(
                  controller: _bio,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: '个性签名',
                    hintText: '介绍一下自己，比如擅长建筑 / 红石 / 挖矿…',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _tags,
                  decoration: const InputDecoration(
                    labelText: '标签',
                    hintText: '建筑师, 红石党, 老玩家（最多 6 个）',
                    prefixIcon: Icon(Icons.tag_rounded),
                  ),
                ),
              ],
            ),
          ),
          const SectionTitle(title: '主页背景'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_bg.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: _presets.containsKey(_bg)
                          ? Container(
                              height: 120,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _presets[_bg]!,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                            )
                          : Image.network(
                              Api.i.abs(_bg),
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(
                                height: 120,
                                color: cs.surfaceContainerHighest,
                                child: const Icon(Icons.broken_image_outlined),
                              ),
                            ),
                    ),
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in _presets.entries)
                      GestureDetector(
                        onTap: () => setState(() => _bg = e.key),
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              colors: e.value,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color: _bg == e.key
                                  ? AppColors.brand
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _uploading ? null : _pickBg,
                        icon: const Icon(Icons.add_photo_alternate_outlined,
                            size: 17),
                        label: const Text('上传横图'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _bg.isEmpty ? null : _clearBg,
                        icon: const Icon(Icons.restart_alt_rounded, size: 17),
                        label: const Text('恢复默认'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '建议横图，会自动居中裁剪。上传即代表你确认拥有该图片的使用权。',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
