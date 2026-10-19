import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/img.dart';
import '../core/ui.dart';

class ComposePage extends StatefulWidget {
  const ComposePage({super.key, this.initialBoard});

  final String? initialBoard;

  @override
  State<ComposePage> createState() => _ComposePageState();
}

class _ComposePageState extends State<ComposePage> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  List<Map<String, dynamic>> _boards = const [];
  String? _board;
  List<String> _images = <String>[];
  bool _loadingBoards = true;
  bool _busy = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _board = widget.initialBoard;
    _loadBoards();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _loadBoards() async {
    try {
      final j = await Api.i.forumBoards();
      final boards = asList(j['boards']);
      if (!mounted) return;
      setState(() {
        _boards = boards;
        if (_board == null || !boards.any((b) => asStr(b['id']) == _board)) {
          _board = boards.isEmpty ? null : asStr(boards.first['id']);
        }
        _loadingBoards = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _err = e.toString();
          _loadingBoards = false;
        });
      }
    }
  }

  Future<void> _pick() async {
    try {
      final remain = 9 - _images.length;
      if (remain <= 0) return;
      final picked = await ImgPicker.multi(limit: remain);
      if (picked.isEmpty) return;
      setState(() => _images = [..._images, ...picked].take(9).toList());
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    }
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.length < 2) {
      showToast(context, '标题至少 2 个字', error: true);
      return;
    }
    if (body.isEmpty) {
      showToast(context, '正文不能为空', error: true);
      return;
    }
    if (_board == null || _board!.isEmpty) {
      showToast(context, '请选择版块', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final urls = <String>[];
      for (final d in _images) {
        final up = await Api.i.uploadImage(d, kind: 'forum');
        final url = asStr(up['url']);
        if (url.isNotEmpty) urls.add(url);
      }
      final j = await Api.i.forumNewThread(
        board: _board!,
        title: title,
        body: body,
        images: urls,
      );
      final id = asInt(j['id']);
      if (!mounted) return;
      showToast(context, '发布成功');
      Navigator.pop(context, id);
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppPage(
      title: '发新帖',
      actions: [
        TextButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('发布'),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
        children: [
          if (_loadingBoards)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_err != null)
            ErrorView(message: _err!, onRetry: _loadBoards)
          else
            DropdownButtonFormField<String>(
              value: _board,
              decoration: const InputDecoration(
                labelText: '版块',
                prefixIcon: Icon(Icons.forum_outlined),
              ),
              items: _boards
                  .map(
                    (b) => DropdownMenuItem(
                      value: asStr(b['id']),
                      child: Text(asStr(b['name'], '版块')),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _board = v),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            maxLength: 60,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '标题',
              hintText: '2~60 字，把话说清楚',
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _body,
            minLines: 9,
            maxLines: 18,
            decoration: const InputDecoration(
              labelText: '正文',
              hintText: '聊聊玩法、晒作品、找人组队、给服主提建议…',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                '配图（最多 9 张）',
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${_images.length}/9',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (var i = 0; i < _images.length; i++)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnyImage(url: _images[i], width: 82, height: 82),
                    Positioned(
                      right: -6,
                      top: -6,
                      child: GestureDetector(
                        onTap: () {
                          final next = List<String>.from(_images)..removeAt(i);
                          setState(() => _images = next);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: cs.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: cs.outlineVariant),
                          ),
                          child: Icon(Icons.close_rounded,
                              size: 13, color: cs.onSurface),
                        ),
                      ),
                    ),
                  ],
                ),
              if (_images.length < 9)
                GestureDetector(
                  onTap: _pick,
                  child: Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Icon(Icons.add_photo_alternate_outlined,
                        color: cs.onSurfaceVariant, size: 25),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '请勿发布广告、辱骂、外挂等违规内容；图片会自动压缩。发布后可在帖子里继续编辑。',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 11.5,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
