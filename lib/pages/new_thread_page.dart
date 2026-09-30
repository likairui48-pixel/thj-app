import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/api.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import '../widgets/kit.dart';

/// 发新帖：选版块 + 标题 + 正文 + 配图（成功后返回帖子 id）
class NewThreadPage extends StatefulWidget {
  const NewThreadPage({super.key});

  @override
  State<NewThreadPage> createState() => _NewThreadPageState();
}

class _NewThreadPageState extends State<NewThreadPage> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  List<String> _imgs = <String>[];
  String _board = 'general';
  String _boardName = '综合讨论';
  List<Map<String, dynamic>> _boards = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
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
      final list =
          (j['boards'] as List? ?? const []).map((e) => asMap(e)).toList();
      if (!mounted || list.isEmpty) return;
      final first = list.first;
      setState(() {
        _boards = list;
        _board = asStr(first['id'], 'general');
        _boardName = asStr(first['name'] ?? first['title'], '综合讨论');
      });
    } catch (_) {/* 用默认版块 */}
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
          scrolledUnderElevation: 0,
          foregroundColor: t.text,
          title: Text('发新帖',
              style: TextStyle(
                  color: t.text, fontSize: 17, fontWeight: FontWeight.w700)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(R.page, 6, R.page, 30),
          children: [
            SectionTitle(title: '发到哪个版块', sub: '点一下换版块'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (_boards.isEmpty
                      ? [
                          {'id': 'general', 'name': '综合讨论'}
                        ]
                      : _boards)
                  .map((b) => GlassChip(
                        label: asStr(b['name'] ?? b['title'], asStr(b['id'])),
                        active: _board == asStr(b['id']),
                        onTap: () => setState(() {
                          _board = asStr(b['id']);
                          _boardName =
                              asStr(b['name'] ?? b['title'], _boardName);
                        }),
                      ))
                  .toList(),
            ),
            SectionTitle(title: '标题', sub: '2~60 字'),
            _box(
              child: TextField(
                controller: _title,
                maxLength: 60,
                style: TextStyle(color: t.text, fontSize: 15),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '一句话说清楚',
                  hintStyle: TextStyle(color: t.text3, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                ),
              ),
            ),
            SectionTitle(title: '正文', sub: '2~8000 字，可配 3 张图'),
            _box(
              child: TextField(
                controller: _body,
                minLines: 8,
                maxLines: 20,
                style: TextStyle(color: t.text, fontSize: 14.5, height: 1.6),
                decoration: InputDecoration(
                  hintText: '想说什么？可以写游戏经历、提问、建议…',
                  hintStyle: TextStyle(color: t.text3, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ImagePickerStrip(
              images: _imgs,
              max: 3,
              onChanged: (v) => setState(() => _imgs = v),
            ),
            const SizedBox(height: 20),
            GlassButton(
              label: _busy ? '发布中…' : '发布到「$_boardName」',
              icon: Icons.send_rounded,
              primary: true,
              loading: _busy,
              onTap: _busy ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _box({required Widget child}) {
    final t = GlassTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.fill,
        borderRadius: BorderRadius.circular(R.tile),
        border: Border.all(color: t.stroke),
      ),
      child: child,
    );
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.length < 2) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('标题至少 2 个字')));
      return;
    }
    if (body.length < 2) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('正文至少 2 个字')));
      return;
    }
    setState(() => _busy = true);
    try {
      final imgs = <String>[];
      for (final d in _imgs) {
        final r = await Api.i.uploadImage(d, kind: 'photo');
        final u = asStrOrNull(r['url']);
        if (u != null) imgs.add(u);
      }
      final j = await Api.i.forumNewThread(
        board: _board,
        title: title,
        body: body,
        images: imgs,
      );
      if (!mounted) return;
      Navigator.pop(context, asInt(j['id']));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('发布失败：$e')));
    }
  }
}
