import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/api.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import '../widgets/kit.dart';
import '../core/img.dart';
import 'login_page.dart';
import 'user_profile_page.dart';

/// 帖子详情：正文 + 楼层 + 回复框；作者/版主可编辑删除
class ThreadPage extends StatefulWidget {
  const ThreadPage({super.key, required this.threadId, this.focusPostId});

  final int threadId;
  final int? focusPostId;

  @override
  State<ThreadPage> createState() => _ThreadPageState();
}

class _ThreadPageState extends State<ThreadPage> {
  bool _loading = true;
  String? _err;
  Map<String, dynamic> _thread = const {};
  List<Map<String, dynamic>> _posts = const [];
  bool _liked = false;
  int _likes = 0;
  bool _sending = false;
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  List<String> _pendingImgs = <String>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final j = await Api.i.forumThread(widget.threadId);
      if (!mounted) return;
      setState(() {
        _thread = asMap(j['thread']);
        _posts = (j['posts'] as List? ?? const []).map((e) => asMap(e)).toList();
        _liked = asBool(j['liked']);
        _likes = asInt(j['likes']);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = e.toString();
        _loading = false;
      });
    }
  }

  bool get _mine => asBool(_thread['mine']);
  bool get _canEdit => asBool(_thread['canEdit']);
  bool get _canMod => asBool(_thread['canMod']);
  bool get _locked => asBool(_thread['locked']);
  bool get _readOnly => _locked && !_canMod;

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
          title: Text('帖子',
              style: TextStyle(
                  color: t.text, fontSize: 17, fontWeight: FontWeight.w700)),
          actions: [
            if (_canEdit)
              IconButton(
                tooltip: '编辑',
                icon: Icon(Icons.edit_outlined, color: t.text, size: 20),
                onPressed: _editThread,
              ),
            if (_canEdit)
              IconButton(
                tooltip: '删除',
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFD9534F), size: 21),
                onPressed: _deleteThread,
              ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: AsyncView(
                  loading: _loading,
                  error: _err,
                  onRetry: _load,
                  isEmpty: !_loading && _thread.isEmpty,
                  emptyText: '帖子不见了',
                  skeleton: const Padding(
                    padding: EdgeInsets.all(R.page),
                    child: Column(
                      children: [
                        GlassSkeleton(height: 120, radius: R.card),
                        SizedBox(height: 10),
                        GlassSkeleton(height: 80, radius: R.card),
                      ],
                    ),
                  ),
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(R.page, 6, R.page, 20),
                    children: [
                      _threadCard(),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          SectionTitle(
                              title: '回复',
                              sub: '${_posts.length} 楼'),
                        ],
                      ),
                      if (_posts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: EmptyHint(
                              text: '还没有人回复，来占个沙发',
                              icon: Icons.mode_comment_outlined),
                        )
                      else
                        for (final p in _posts) _postCard(p),
                    ],
                  ),
                ),
              ),
            ),
            if (!_readOnly) _composer(),
          ],
        ),
      ),
    );
  }

  Widget _threadCard() {
    final t = GlassTokens.of(context);
    final author = asMap(_thread['author']);
    final images = (_thread['images'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();
    final mc = asStrOrNull(_thread['mcName']);
    final membership = asMap(author['membership']);
    return GlassPanel(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (asBool(_thread['pinned']))
                const Padding(
                  padding: EdgeInsets.only(right: 6, top: 3),
                  child: MiniBadge(text: '置顶', color: Color(0xFFE0623A)),
                ),
              if (asBool(_thread['essence']))
                const Padding(
                  padding: EdgeInsets.only(right: 6, top: 3),
                  child: MiniBadge(text: '精华', color: Color(0xFFCC9A2B)),
                ),
              if (_locked)
                const Padding(
                  padding: EdgeInsets.only(right: 6, top: 3),
                  child: MiniBadge(text: '已锁定', color: Color(0xFF8A8A8A)),
                ),
              Expanded(
                child: Text(asStr(_thread['title']),
                    style: TextStyle(
                        color: t.text,
                        fontSize: 18,
                        height: 1.35,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AuthorRow(
            username: asStr(author['username']),
            avatar: asStrOrNull(author['avatar']),
            time: _thread['createdAt'],
            onTap: () => _openProfile(asStr(author['username'])),
            badges: [
              if (membership.isNotEmpty)
                MiniBadge(
                  text: asStr(membership['label'], '会员'),
                  color: _hexColor(asStrOrNull(membership['color'])),
                ),
              if (mc != null && mc.isNotEmpty)
                MiniBadge(
                    text: mc,
                    color: const Color(0xFF2FA6A0),
                    icon: Icons.sports_esports_rounded),
            ],
            trailing: asInt(_thread['editedAt']) > 0
                ? Text('已编辑',
                    style: TextStyle(color: t.text3, fontSize: 11))
                : null,
          ),
          const SizedBox(height: 14),
          SelectableText(asStr(_thread['body']),
              style: TextStyle(color: t.text, fontSize: 14.5, height: 1.7)),
          if (images.isNotEmpty) ...[
            const SizedBox(height: 12),
            ImageGrid(urls: images),
          ],
          const SizedBox(height: 14),
          Container(height: 1, color: t.divider),
          const SizedBox(height: 10),
          Row(
            children: [
              _action(
                _liked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                _liked ? '已赞 $_likes' : '赞 $_likes',
                _liked ? t.accent : t.text3,
                _like,
              ),
              const SizedBox(width: 20),
              _action(Icons.mode_comment_outlined, '${_posts.length} 回复',
                  t.text3, () => _focus.requestFocus()),
              const SizedBox(width: 20),
              _action(Icons.visibility_outlined, '${asInt(_thread['views'])}',
                  t.text3, () {}),
            ],
          ),
        ],
      ),
    );
  }

  Widget _postCard(Map<String, dynamic> p) {
    final t = GlassTokens.of(context);
    final author = asMap(p['author']);
    final images =
        (p['images'] as List? ?? const []).map((e) => e.toString()).toList();
    final membership = asMap(author['membership']);
    final mc = asStrOrNull(p['mcName']);
    final liked = asBool(p['liked']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassPanel(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: AuthorRow(
                    username: asStr(author['username']),
                    avatar: asStrOrNull(author['avatar']),
                    time: p['createdAt'],
                    avatarSize: 30,
                    onTap: () => _openProfile(asStr(author['username'])),
                    badges: [
                      if (membership.isNotEmpty)
                        MiniBadge(
                          text: asStr(membership['label'], '会员'),
                          color: _hexColor(asStrOrNull(membership['color'])),
                        ),
                    ],
                  ),
                ),
                Text('#${asInt(p['id'])}',
                    style: TextStyle(color: t.text3, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 9),
            SelectableText(asStr(p['body']),
                style: TextStyle(color: t.text, fontSize: 14, height: 1.6)),
            if (mc != null && mc.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('游戏内：$mc',
                  style: TextStyle(color: t.text3, fontSize: 11.5)),
            ],
            if (images.isNotEmpty) ...[
              const SizedBox(height: 9),
              ImageGrid(urls: images, height: 92),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                _action(
                  liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  liked ? '${asInt(p['likes'])}' : '${asInt(p['likes'])}',
                  liked ? t.accent : t.text3,
                  () => _likePost(p),
                ),
                const SizedBox(width: 18),
                _action(Icons.reply_rounded, '回复', t.text3,
                    () => _replyTo(p)),
                if (asBool(p['canEdit'])) ...[
                  const SizedBox(width: 18),
                  _action(Icons.edit_outlined, '编辑', t.text3,
                      () => _editPost(p)),
                  const SizedBox(width: 18),
                  _action(Icons.delete_outline_rounded, '删除',
                      const Color(0xFFD9534F), () => _deletePost(p)),
                ],
                const Spacer(),
                if (asInt(p['editedAt']) > 0)
                  Text('已编辑',
                      style: TextStyle(color: t.text3, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _action(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12.5)),
        ],
      ),
    );
  }

  Widget _composer() {
    final t = GlassTokens.of(context);
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: t.fill,
        border: Border(top: BorderSide(color: t.stroke)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_pendingImgs.isNotEmpty) ...[
            ImagePickerStrip(
              images: _pendingImgs,
              max: 3,
              onChanged: (v) => setState(() => _pendingImgs = v),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GlassIconButton(
                icon: Icons.add_photo_alternate_outlined,
                size: 40,
                tooltip: '配图',
                onTap: () async {
                  final u = await _pickAndUpload();
                  if (u == null || !mounted) return;
                  setState(() => _pendingImgs = [..._pendingImgs, u]);
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: t.fillStrong,
                    borderRadius: BorderRadius.circular(R.card),
                    border: Border.all(color: t.stroke),
                  ),
                  child: TextField(
                    controller: _input,
                    focusNode: _focus,
                    maxLines: 4,
                    minLines: 1,
                    style: TextStyle(color: t.text, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: _locked ? '该帖已锁定' : '说点什么…',
                      hintStyle: TextStyle(color: t.text3, fontSize: 13.5),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GlassButton(
                label: _sending ? '…' : '发送',
                expand: false,
                height: 40,
                primary: true,
                loading: _sending,
                onTap: _send,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 选一张图 → 上传 → 返回服务端地址（失败返回 null）
  Future<String?> _pickAndUpload() async {
    final d = await Img.pickDataUrl(maxEdge: 1400, quality: 82);
    if (d == null) return null;
    final r = await Api.i.uploadImage(d, kind: 'photo');
    return asStrOrNull(r['url']);
  }

  void _replyTo(Map<String, dynamic> p) {
    final name = asStr(asMap(p['author'])['username']);
    _input.text = '@$name ';
    _input.selection = TextSelection.fromPosition(
        TextPosition(offset: _input.text.length));
    _focus.requestFocus();
  }

  Future<void> _send() async {
    final body = _input.text.trim();
    if (body.isEmpty && _pendingImgs.isEmpty) return;
    if (!await requireLogin(context, reason: '登录后才能回复')) return;
    setState(() => _sending = true);
    try {
      final imgs = List<String>.from(_pendingImgs);
      await Api.i.forumReply(widget.threadId, body, images: imgs);
      _input.clear();
      setState(() {
        _pendingImgs = <String>[];
        _sending = false;
      });
      await _load();
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: Motion.medium,
        curve: Curves.easeOut,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('回复失败：$e')));
    }
  }

  Future<void> _like() async {
    if (!await requireLogin(context, reason: '登录后才能点赞')) return;
    final was = _liked;
    setState(() {
      _liked = !was;
      _likes += was ? -1 : 1;
    });
    try {
      final j = await Api.i.forumLike('thread', widget.threadId);
      if (!mounted) return;
      setState(() {
        _liked = asBool(j['liked']);
        _likes = asInt(j['likes']);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _liked = was;
        _likes += was ? 1 : -1;
      });
    }
  }

  Future<void> _likePost(Map<String, dynamic> p) async {
    if (!await requireLogin(context, reason: '登录后才能点赞')) return;
    final was = asBool(p['liked']);
    setState(() {
      p['liked'] = !was;
      p['likes'] = (asInt(p['likes']) + (was ? -1 : 1)).clamp(0, 1 << 30);
    });
    try {
      final j = await Api.i.forumLike('post', asInt(p['id']));
      if (!mounted) return;
      setState(() {
        p['liked'] = asBool(j['liked']);
        p['likes'] = asInt(j['likes']);
      });
    } catch (_) {/* 忽略，保持乐观值 */}
  }

  Future<void> _editThread() async {
    final titleCtl = TextEditingController(text: asStr(_thread['title']));
    final bodyCtl = TextEditingController(text: asStr(_thread['body']));
    final ok = await GlassSheet.show<bool>(
      context,
      child: StatefulBuilder(
        builder: (ctx, setSt) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('编辑帖子',
                style: TextStyle(
                    color: GlassTokens.of(ctx).text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _field(titleCtl, '标题', maxLines: 1),
            const SizedBox(height: 8),
            _field(bodyCtl, '正文', maxLines: 8),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: GlassButton(
                    label: '取消',
                    onTap: () => Navigator.pop(ctx, false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GlassButton(
                    label: '保存',
                    primary: true,
                    onTap: () => Navigator.pop(ctx, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await Api.i.forumEditThread(widget.threadId,
          title: titleCtl.text.trim(), body: bodyCtl.text.trim());
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存失败：$e')));
    }
  }

  Future<void> _editPost(Map<String, dynamic> p) async {
    final ctl = TextEditingController(text: asStr(p['body']));
    final ok = await GlassSheet.show<bool>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('编辑回复',
              style: TextStyle(
                  color: GlassTokens.of(context).text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _field(ctl, '', maxLines: 6),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                  child: GlassButton(
                      label: '取消', onTap: () => Navigator.pop(context, false))),
              const SizedBox(width: 10),
              Expanded(
                  child: GlassButton(
                      label: '保存',
                      primary: true,
                      onTap: () => Navigator.pop(context, true))),
            ],
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await Api.i.forumEditPost(asInt(p['id']), body: ctl.text.trim());
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存失败：$e')));
    }
  }

  Widget _field(TextEditingController c, String hint, {int maxLines = 4}) {
    final t = GlassTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.fill,
        borderRadius: BorderRadius.circular(R.tile),
        border: Border.all(color: t.stroke),
      ),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        style: TextStyle(color: t.text, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: t.text3, fontSize: 13.5),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        ),
      ),
    );
  }

  Future<void> _deleteThread() async {
    final ok = await GlassDialog.confirm(
      context,
      title: '删除帖子',
      message: '帖子连同所有回复都会被删除，确定吗？',
      okLabel: '删除',
      danger: true,
    );
    if (ok != true || !mounted) return;
    try {
      await Api.i.forumDeleteThread(widget.threadId);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('删除失败：$e')));
    }
  }

  Future<void> _deletePost(Map<String, dynamic> p) async {
    final ok = await GlassDialog.confirm(
      context,
      title: '删除回复',
      message: '确定删除这条回复？',
      okLabel: '删除',
      danger: true,
    );
    if (ok != true || !mounted) return;
    try {
      await Api.i.forumDeletePost(asInt(p['id']));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('删除失败：$e')));
    }
  }

  void _openProfile(String username) {
    if (username.isEmpty) return;
    Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => UserProfilePage(username: username)));
  }
}

Color _hexColor(String? hex) {
  const fallback = Color(0xFF2E9E63);
  if (hex == null || hex.isEmpty) return fallback;
  var s = hex.replaceAll('#', '');
  if (s.length == 6) s = 'FF$s';
  final v = int.tryParse(s, radix: 16);
  return v == null ? fallback : Color(v);
}
