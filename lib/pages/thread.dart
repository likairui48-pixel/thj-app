import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/img.dart';
import '../core/nav.dart';
import '../core/state.dart';
import '../core/ui.dart';
import 'login.dart';
import 'report.dart';

class ThreadPage extends StatefulWidget {
  const ThreadPage({super.key, required this.threadId});

  final int threadId;

  @override
  State<ThreadPage> createState() => _ThreadPageState();
}

class _ThreadPageState extends State<ThreadPage> {
  final _state = AppState.i;
  final _reply = TextEditingController();
  final _replyFocus = FocusNode();
  bool _loading = true;
  String? _err;
  Map<String, dynamic> _thread = <String, dynamic>{};
  List<Map<String, dynamic>> _posts = const [];
  bool _liked = false;
  int _likes = 0;
  bool _collected = false;
  bool _sending = false;
  List<String> _replyImages = <String>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reply.dispose();
    _replyFocus.dispose();
    super.dispose();
  }

  bool get _canEdit => asBool(_thread['canEdit']);
  bool get _locked => asBool(_thread['locked']);
  bool get _mine => asBool(_thread['mine']);

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
        _posts = asList(j['posts']);
        _liked = asBool(j['liked']);
        _likes = asInt(j['likes']);
        _collected = asBool(j['collected']);
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

  Future<void> _toggleLike() async {
    if (!_state.isLoggedIn) {
      await _login();
      return;
    }
    try {
      final j = await Api.i.forumLike('thread', widget.threadId);
      if (!mounted) return;
      setState(() {
        _liked = asBool(j['liked'], !_liked);
        _likes = asInt(j['likes'], _likes);
      });
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    }
  }

  Future<void> _toggleCollect() async {
    if (!_state.isLoggedIn) {
      await _login();
      return;
    }
    try {
      final j = await Api.i.collectThread(widget.threadId);
      if (!mounted) return;
      final on = asBool(j['collected'], !_collected);
      setState(() => _collected = on);
      showToast(context, on ? '已收藏' : '已取消收藏');
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    }
  }

  Future<bool> _login() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
    return ok == true;
  }

  Future<void> _sendReply() async {
    final text = _reply.text.trim();
    if (text.isEmpty && _replyImages.isEmpty) return;
    if (!_state.isLoggedIn) {
      await _login();
      return;
    }
    setState(() => _sending = true);
    try {
      final urls = <String>[];
      for (final d in _replyImages) {
        if (d.startsWith('data:')) {
          final up = await Api.i.uploadImage(d, kind: 'forum');
          final url = asStr(up['url']);
          if (url.isNotEmpty) urls.add(url);
        } else {
          urls.add(d);
        }
      }
      await Api.i.forumReply(widget.threadId, text, images: urls);
      _reply.clear();
      setState(() => _replyImages = <String>[]);
      _replyFocus.unfocus();
      await _load();
      if (mounted) showToast(context, '回复成功');
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteThread() async {
    final ok = await showConfirm(
      context,
      title: '删除帖子',
      message: '帖子与全部回复都会隐藏，图片会被回收，不能恢复。',
      okText: '删除',
      danger: true,
    );
    if (!ok) return;
    try {
      await Api.i.forumDeleteThread(widget.threadId);
      if (!mounted) return;
      showToast(context, '已删除');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    }
  }

  Future<void> _editThread() async {
    final title = TextEditingController(text: asStr(_thread['title']));
    final body = TextEditingController(text: asStr(_thread['body']));
    var images = asStrList(_thread['images']);
    var busy = false;
    await showAppSheet<void>(
      context,
      child: StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text('编辑帖子',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            if (title.text.trim().length < 2) {
                              showToast(ctx, '标题至少 2 个字', error: true);
                              return;
                            }
                            setSt(() => busy = true);
                            try {
                              final urls = <String>[];
                              for (final d in images) {
                                if (d.startsWith('data:')) {
                                  final up = await Api.i.uploadImage(d,
                                      kind: 'forum');
                                  final url = asStr(up['url']);
                                  if (url.isNotEmpty) urls.add(url);
                                } else {
                                  urls.add(d);
                                }
                              }
                              await Api.i.forumEditThread(
                                widget.threadId,
                                title: title.text.trim(),
                                body: body.text.trim(),
                                images: urls,
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                              await _load();
                            } catch (e) {
                              if (ctx.mounted) {
                                showToast(ctx, e.toString(), error: true);
                              }
                            } finally {
                              if (ctx.mounted) setSt(() => busy = false);
                            }
                          },
                    child: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('保存'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: title,
                maxLength: 60,
                decoration: const InputDecoration(labelText: '标题'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: body,
                minLines: 5,
                maxLines: 12,
                decoration: const InputDecoration(
                  labelText: '正文',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (var i = 0; i < images.length; i++)
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AnyImage(url: images[i], width: 76, height: 76),
                        Positioned(
                          right: -6,
                          top: -6,
                          child: GestureDetector(
                            onTap: () => setSt(() {
                              final next = List<String>.from(images)
                                ..removeAt(i);
                              images = next;
                            }),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Theme.of(ctx).colorScheme.surface,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(ctx).colorScheme.outlineVariant,
                                ),
                              ),
                              child: const Icon(Icons.close_rounded, size: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (images.length < 9)
                    GestureDetector(
                      onTap: () async {
                        final picked = await ImgPicker.multi(
                            limit: 9 - images.length);
                        if (picked.isNotEmpty) {
                          setSt(() => images = [...images, ...picked]);
                        }
                      },
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.add_photo_alternate_outlined),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    title.dispose();
    body.dispose();
  }

  Future<void> _editPost(Map<String, dynamic> post) async {
    final body = TextEditingController(text: asStr(post['body']));
    var images = asStrList(post['images']);
    var busy = false;
    await showAppSheet<void>(
      context,
      child: StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text('编辑回复',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            setSt(() => busy = true);
                            try {
                              final urls = <String>[];
                              for (final d in images) {
                                if (d.startsWith('data:')) {
                                  final up = await Api.i.uploadImage(d,
                                      kind: 'forum');
                                  final url = asStr(up['url']);
                                  if (url.isNotEmpty) urls.add(url);
                                } else {
                                  urls.add(d);
                                }
                              }
                              await Api.i.forumEditPost(
                                asInt(post['id']),
                                body: body.text,
                                images: urls,
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                              await _load();
                            } catch (e) {
                              if (ctx.mounted) {
                                showToast(ctx, e.toString(), error: true);
                              }
                            } finally {
                              if (ctx.mounted) setSt(() => busy = false);
                            }
                          },
                    child: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('保存'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: body,
                minLines: 4,
                maxLines: 10,
                decoration: const InputDecoration(labelText: '回复内容'),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (var i = 0; i < images.length; i++)
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AnyImage(url: images[i], width: 76, height: 76),
                        Positioned(
                          right: -6,
                          top: -6,
                          child: GestureDetector(
                            onTap: () => setSt(() {
                              final next = List<String>.from(images)
                                ..removeAt(i);
                              images = next;
                            }),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Theme.of(ctx).colorScheme.surface,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, size: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (images.length < 9)
                    GestureDetector(
                      onTap: () async {
                        final picked = await ImgPicker.multi(
                            limit: 9 - images.length);
                        if (picked.isNotEmpty) {
                          setSt(() => images = [...images, ...picked]);
                        }
                      },
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.add_photo_alternate_outlined),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    body.dispose();
  }

  Future<void> _deletePost(Map<String, dynamic> post) async {
    final ok = await showConfirm(
      context,
      title: '删除回复',
      message: '确定删除这条回复吗？',
      okText: '删除',
      danger: true,
    );
    if (!ok) return;
    try {
      await Api.i.forumDeletePost(asInt(post['id']));
      await _load();
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    }
  }

  void _replyTo(Map<String, dynamic> post) {
    final name = asStr(asMap(post['author'])['username']);
    final current = _reply.text;
    _reply.text = '@$name $current'.trim();
    _reply.selection = TextSelection.collapsed(offset: _reply.text.length);
    _replyFocus.requestFocus();
  }

  void _openReport({String type = 'thread', int? id, String? label}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportPage(
          targetType: type,
          targetId: id == null ? '${widget.threadId}' : '$id',
          targetLabel: label ?? '主题 #${widget.threadId}',
        ),
      ),
    );
  }

  void _share() {
    Clipboard.setData(
      ClipboardData(text: 'https://thjmc.duckdns.org:8443/forum/thread/${widget.threadId}'),
    );
    showToast(context, '链接已复制');
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: '帖子',
      actions: [
        if (_canEdit)
          IconButton(
            tooltip: '编辑',
            onPressed: _editThread,
            icon: const Icon(Icons.edit_outlined),
          ),
        if (_canEdit)
          IconButton(
            tooltip: '删除',
            onPressed: _deleteThread,
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.danger),
          ),
        PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'share') _share();
            if (v == 'report') _openReport();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'share', child: Text('复制链接')),
            PopupMenuItem(value: 'report', child: Text('举报主题')),
          ],
        ),
      ],
      child: Column(
        children: [
          Expanded(
            child: AsyncView(
              loading: _loading,
              error: _err,
              onRetry: _load,
              isEmpty: !_loading && _thread.isEmpty,
              emptyText: '帖子不存在或已被删除',
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                children: [
                  _threadBody(context),
                  const SizedBox(height: 18),
                  SectionTitle(
                    title: '全部回复',
                    sub: '共 ${_posts.length} 条',
                  ),
                  ..._posts.asMap().entries.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _postCard(context, e.value, e.key + 1),
                        ),
                      ),
                  if (_posts.isEmpty)
                    const EmptyView(
                      text: '还没有人回复，来抢沙发',
                      icon: Icons.chat_bubble_outline_rounded,
                    ),
                ],
              ),
            ),
          ),
          _composer(context),
        ],
      ),
    );
  }

  Widget _threadBody(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final author = asMap(_thread['author']);
    final images = asStrList(_thread['images']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [
            if (asBool(_thread['pinned']))
              const Pill(text: '置顶', color: AppColors.warning),
            if (asBool(_thread['essence']))
              const Pill(text: '精华', color: AppColors.teal),
            if (_locked) const Pill(text: '已锁', color: Colors.grey),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          asStr(_thread['title'], '无标题'),
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 21,
            fontWeight: FontWeight.w900,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            UserAvatar(
              name: asStr(author['username']),
              avatar: asStrOrNull(author['avatar']),
              size: 38,
              onTap: () => Nav.to('/u/${Uri.encodeComponent(asStr(author['username']))}'),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          asStr(author['username'], '未知'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      RolePill(
                        role: asStr(author['role'], 'user'),
                        isAdmin: asBool(author['isAdmin']),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${fmtDateTime(_thread['createdAt'])}'
                    '${_thread['editedAt'] != null ? ' · 已编辑' : ''} · ${asInt(_thread['views'])} 阅读',
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
        const SizedBox(height: 14),
        SelectableText(
          asStr(_thread['body']),
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 14,
            height: 1.75,
          ),
        ),
        if (images.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (var i = 0; i < images.length; i++)
                GestureDetector(
                  onTap: () => showImageViewer(context, images, i),
                  child: AnyImage(url: images[i], width: 106, height: 106),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            _actionButton(
              context,
              icon: _liked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              label: '$_likes',
              color: _liked ? AppColors.danger : null,
              onTap: _toggleLike,
            ),
            const SizedBox(width: 8),
            _actionButton(
              context,
              icon: _collected
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              label: _collected ? '已收藏' : '收藏',
              color: _collected ? AppColors.warning : null,
              onTap: _toggleCollect,
            ),
            const SizedBox(width: 8),
            _actionButton(
              context,
              icon: Icons.share_outlined,
              label: '分享',
              onTap: _share,
            ),
            const Spacer(),
            if (_mine)
              Text(
                '你是作者',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 10.5,
                ),
              ),
          ],
        ),
        const Divider(height: 28),
      ],
    );
  }

  Widget _postCard(BuildContext context, Map<String, dynamic> post, int floor) {
    final cs = Theme.of(context).colorScheme;
    final author = asMap(post['author']);
    final images = asStrList(post['images']);
    final mine = asBool(post['mine']);
    final canEdit = asBool(post['canEdit']) || mine;
    final liked = asBool(post['liked']);
    final likes = asInt(post['likes']);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                name: asStr(author['username']),
                avatar: asStrOrNull(author['avatar']),
                size: 34,
                onTap: () => Nav.to(
                    '/u/${Uri.encodeComponent(asStr(author['username']))}'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        asStr(author['username'], '未知'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    RolePill(
                      role: asStr(author['role'], 'user'),
                      isAdmin: asBool(author['isAdmin']),
                    ),
                  ],
                ),
              ),
              Text(
                '#$floor',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
              if (canEdit || mine)
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  onSelected: (v) {
                    if (v == 'edit') _editPost(post);
                    if (v == 'delete') _deletePost(post);
                    if (v == 'report') {
                      _openReport(
                        type: 'post',
                        id: asInt(post['id']),
                        label: '回复 #${asInt(post['id'])}',
                      );
                    }
                  },
                  itemBuilder: (_) => [
                    if (canEdit)
                      const PopupMenuItem(value: 'edit', child: Text('编辑')),
                    if (canEdit)
                      const PopupMenuItem(value: 'delete', child: Text('删除')),
                    const PopupMenuItem(value: 'report', child: Text('举报')),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            asStr(post['body']),
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 13.5,
              height: 1.7,
            ),
          ),
          if (images.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < images.length; i++)
                  GestureDetector(
                    onTap: () => showImageViewer(context, images, i),
                    child: AnyImage(url: images[i], width: 88, height: 88),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                fmtAgo(post['createdAt']),
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
              const Spacer(),
              _smallAction(
                context,
                icon: liked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: likes > 0 ? '$likes' : '赞',
                color: liked ? AppColors.danger : null,
                onTap: () async {
                  if (!_state.isLoggedIn) {
                    await _login();
                    return;
                  }
                  try {
                    final j = await Api.i.forumLike('post', asInt(post['id']));
                    setState(() {
                      post['liked'] = asBool(j['liked'], !liked);
                      post['likes'] = asInt(j['likes'], likes);
                    });
                  } catch (e) {
                    if (mounted) showToast(context, e.toString(), error: true);
                  }
                },
              ),
              const SizedBox(width: 12),
              _smallAction(
                context,
                icon: Icons.reply_rounded,
                label: '回复',
                onTap: () => _replyTo(post),
              ),
              if (!_mine) ...[
                const SizedBox(width: 12),
                _smallAction(
                  context,
                  icon: Icons.flag_outlined,
                  label: '举报',
                  onTap: () => _openReport(
                    type: 'post',
                    id: asInt(post['id']),
                    label: '回复 #${asInt(post['id'])}',
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    Color? color,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.onSurfaceVariant;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: c.withOpacity(0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.withOpacity(0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: c),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: c,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    Color? color,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.onSurfaceVariant;
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(color: c, fontSize: 10.5),
          ),
        ],
      ),
    );
  }

  Widget _composer(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (!_state.isLoggedIn) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant)),
        ),
        child: FilledButton.icon(
          onPressed: _login,
          icon: const Icon(Icons.login_rounded, size: 18),
          label: const Text('登录后回复'),
        ),
      );
    }
    if (_locked) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant)),
        ),
        child: Text(
          '该帖已被锁定，无法回复',
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyImages.isNotEmpty)
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _replyImages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, i) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnyImage(url: _replyImages[i], width: 64, height: 64),
                    Positioned(
                      right: -5,
                      top: -5,
                      child: GestureDetector(
                        onTap: () {
                          final next = List<String>.from(_replyImages)
                            ..removeAt(i);
                          setState(() => _replyImages = next);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: cs.surface,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, size: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Row(
            children: [
              IconButton(
                onPressed: () async {
                  final picked = await ImgPicker.multi(
                      limit: 9 - _replyImages.length);
                  if (picked.isNotEmpty) {
                    setState(() => _replyImages = [..._replyImages, ...picked]);
                  }
                },
                icon: Icon(Icons.image_outlined,
                    color: cs.onSurfaceVariant, size: 21),
              ),
              Expanded(
                child: TextField(
                  controller: _reply,
                  focusNode: _replyFocus,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    hintText: '说点什么…',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                onPressed: _sending ? null : _sendReply,
                icon: _sending
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 19),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
