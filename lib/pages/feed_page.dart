import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/api.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import '../widgets/kit.dart';
import 'login_page.dart';
import 'new_thread_page.dart';
import 'thread_page.dart';
import 'user_profile_page.dart';

/// 社区：动态流（关注 / 全部 / 我的）+ 进入论坛版块
class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage>
    with AutomaticKeepAliveClientMixin {
  String _scope = 'all';
  bool _loading = true;
  String? _err;
  List<Map<String, dynamic>> _items = const [];
  List<Map<String, dynamic>> _boards = const [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    _loadBoards();
  }

  Future<void> _loadBoards() async {
    try {
      final j = await Api.i.forumBoards();
      final list = (j['boards'] as List? ?? const [])
          .map((e) => asMap(e))
          .toList();
      if (mounted) setState(() => _boards = list);
    } catch (_) {/* 版块拿不到不影响看动态 */}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final j = await Api.i.feed(scope: _scope, limit: 30);
      final list = (j['items'] as List? ?? const [])
          .map((e) => asMap(e))
          .toList();
      if (!mounted) return;
      setState(() {
        _items = list;
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

  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => page));
    if (mounted) _load();
  }

  Future<void> _compose() async {
    if (!await requireLogin(context, reason: '登录后才能发帖')) return;
    if (!mounted) return;
    final id = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => const NewThreadPage()),
    );
    if (id != null && mounted) {
      await _open(ThreadPage(threadId: id));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = GlassTokens.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _compose,
        backgroundColor: t.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_rounded),
        label: const Text('发帖'),
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await _load();
            await _loadBoards();
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(R.page, 14, R.page, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('社区',
                              style: TextStyle(
                                  color: t.text,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800)),
                          const Spacer(),
                          GlassIconButton(
                            icon: Icons.forum_outlined,
                            tooltip: '论坛版块',
                            onTap: _showBoards,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _scopeChip('all', '全部'),
                          const SizedBox(width: 8),
                          _scopeChip('following', '关注'),
                          const SizedBox(width: 8),
                          _scopeChip('mine', '我的'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_loading && _items.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        GlassSkeleton(height: 96, radius: R.card),
                        SizedBox(height: 10),
                        GlassSkeleton(height: 96, radius: R.card),
                        SizedBox(height: 10),
                        GlassSkeleton(height: 96, radius: R.card),
                      ],
                    ),
                  ),
                )
              else if (_err != null && _items.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(R.page),
                    child: ErrorPanel(message: _err!, onRetry: _load),
                  ),
                )
              else if (_items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(R.page),
                    child: EmptyHint(
                      text: _scope == 'following'
                          ? '关注的动态会出现在这里\n先去论坛逛逛，关注几个有趣的玩家'
                          : '还没有动态，来发第一帖吧',
                      icon: Icons.dynamic_feed_outlined,
                    ),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: _items.length,
                  itemBuilder: (c, i) => _item(_items[i]),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scopeChip(String id, String label) => GlassChip(
        label: label,
        active: _scope == id,
        onTap: () {
          if (_scope == id) return;
          setState(() {
            _scope = id;
            _items = const [];
          });
          _load();
        },
      );

  Widget _item(Map<String, dynamic> it) {
    final t = GlassTokens.of(context);
    final user = asMap(it['user']);
    final username = asStr(user['username'], '');
    final kind = asStr(it['kind'], 'thread');
    final meta = asMap(it['meta']);
    final images = (it['images'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();
    final liked = asBool(it['liked']);
    final likes = asInt(meta['likes']);
    final link = asStr(it['link']);

    return Padding(
      padding: const EdgeInsets.fromLTRB(R.page, 0, R.page, 10),
      child: GlassPanel(
        padding: const EdgeInsets.all(14),
        onTap: () => _tapItem(it),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthorRow(
              username: username,
              avatar: asStrOrNull(user['avatar']),
              time: it['at'],
              onTap: () => _open(UserProfilePage(username: username)),
              badges: [
                if (kind == 'reply') const MiniBadge(text: '回复', icon: Icons.reply_rounded),
                if (kind == 'guestbook')
                  const MiniBadge(text: '留言', icon: Icons.chat_bubble_outline_rounded),
              ],
            ),
            const SizedBox(height: 10),
            Text(asStr(it['title'], ''),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: t.text,
                    fontSize: 15,
                    height: 1.35,
                    fontWeight: FontWeight.w700)),
            if (asStr(it['excerpt']).isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(asStr(it['excerpt']),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: t.text2, fontSize: 13, height: 1.55)),
            ],
            if (images.isNotEmpty) ...[
              const SizedBox(height: 10),
              ImageGrid(urls: images),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                _miniAction(
                  liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  liked ? '已赞' : '赞',
                  liked ? t.accent : t.text3,
                  () => _like(it),
                ),
                const SizedBox(width: 16),
                _miniAction(Icons.mode_comment_outlined, '${asInt(meta['replies'])} 回复', t.text3,
                    () => _tapItem(it)),
                const SizedBox(width: 16),
                _miniAction(Icons.visibility_outlined, '${asInt(meta['views'])}',
                    t.text3, () => _tapItem(it)),
                const Spacer(),
                if (kind == 'thread' && link.isNotEmpty)
                  Icon(Icons.chevron_right_rounded, color: t.text3, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _like(Map<String, dynamic> it) async {
    if (!await requireLogin(context, reason: '登录后才能点赞')) return;
    final id = asInt(it['id']);
    if (id <= 0) {
      if (mounted) _open(UserProfilePage(username: asStr(asMap(it['user'])['username'])));
      return;
    }
    final wasLiked = asBool(it['liked']);
    setState(() {
      it['liked'] = !wasLiked;
      final m = asMap(it['meta']);
      m['likes'] = (asInt(m['likes']) + (wasLiked ? -1 : 1)).clamp(0, 1 << 30);
      it['meta'] = m;
    });
    try {
      await Api.i.forumLike('thread', id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        it['liked'] = wasLiked;
        final m = asMap(it['meta']);
        m['likes'] = (asInt(m['likes']) + (wasLiked ? 1 : -1)).clamp(0, 1 << 30);
        it['meta'] = m;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('点赞失败：$e')));
    }
  }

  void _tapItem(Map<String, dynamic> it) {
    final kind = asStr(it['kind'], 'thread');
    final user = asMap(it['user']);
    if (kind == 'thread') {
      final id = asInt(it['id']);
      if (id > 0) _open(ThreadPage(threadId: id));
      return;
    }
    if (kind == 'reply') {
      final link = asStr(it['link']);
      final m = RegExp(r'/forum/thread/(\d+)').firstMatch(link);
      final id = int.tryParse(m?.group(1) ?? '');
      if (id != null) _open(ThreadPage(threadId: id));
      return;
    }
    // 留言板 → 玩家主页
    final link = asStr(it['link']);
    final name = link.startsWith('/u/')
        ? Uri.decodeComponent(link.substring(3))
        : asStr(user['username']);
    if (name.isNotEmpty) _open(UserProfilePage(username: name));
  }

  void _showBoards() {
    GlassSheet.show<void>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('论坛版块',
              style: TextStyle(
                  color: GlassTokens.of(context).text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (_boards.isEmpty)
            const EmptyHint(text: '版块加载失败，下拉刷新试试')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _boards
                  .map((b) => GlassChip(
                        label: '${asStr(b['name'] ?? b['title'], asStr(b['id']))}'
                            '${asInt(b['threads']) > 0 ? ' · ${asInt(b['threads'])}' : ''}',
                        onTap: () {
                          Navigator.pop(context);
                          _open(BoardPage(
                            board: asStr(b['id']),
                            title: asStr(b['name'] ?? b['title'], '版块'),
                          ));
                        },
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

/// 单个版块的帖子列表
class BoardPage extends StatefulWidget {
  const BoardPage({super.key, required this.board, required this.title});

  final String board;
  final String title;

  @override
  State<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
  bool _loading = true;
  String? _err;
  bool _hot = false;
  int _page = 1;
  int _pages = 1;
  int _total = 0;
  List<Map<String, dynamic>> _list = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      if (!more) _loading = true;
      _err = null;
    });
    try {
      final j = await Api.i.forumThreads(
        board: widget.board,
        page: more ? _page + 1 : 1,
        sort: _hot ? 'hot' : 'new',
      );
      final list = (j['threads'] as List? ?? const [])
          .map((e) => asMap(e))
          .toList();
      if (!mounted) return;
      setState(() {
        if (more) {
          _list = [..._list, ...list];
          _page += 1;
        } else {
          _list = list;
          _page = 1;
        }
        _pages = asInt(j['pages'], 1);
        _total = asInt(j['total']);
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
          title: Text(widget.title,
              style: TextStyle(
                  color: t.text, fontSize: 17, fontWeight: FontWeight.w700)),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _hot = !_hot);
                _load();
              },
              child: Text(_hot ? '最热' : '最新',
                  style: TextStyle(color: t.accent, fontSize: 13.5)),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => _load(),
          child: AsyncView(
            loading: _loading,
            error: _err,
            onRetry: _load,
            isEmpty: _list.isEmpty,
            emptyText: '这个版块还没有帖子',
            skeleton: const Padding(
              padding: EdgeInsets.all(R.page),
              child: Column(
                children: [
                  GlassSkeleton(height: 84, radius: R.card),
                  SizedBox(height: 10),
                  GlassSkeleton(height: 84, radius: R.card),
                ],
              ),
            ),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(R.page, 8, R.page, 30),
              itemCount: _list.length + 1,
              itemBuilder: (c, i) {
                if (i == _list.length) {
                  if (_page >= _pages) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text('共 $_total 帖',
                            style:
                                TextStyle(color: t.text3, fontSize: 12)),
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: GlassButton(
                      label: '加载更多',
                      onTap: () => _load(more: true),
                    ),
                  );
                }
                return _threadTile(_list[i]);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _threadTile(Map<String, dynamic> th) {
    final t = GlassTokens.of(context);
    final author = asMap(th['author']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassPanel(
        padding: const EdgeInsets.all(13),
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ThreadPage(threadId: asInt(th['id']))));
          if (mounted) _load();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (asBool(th['pinned']))
                  const Padding(
                    padding: EdgeInsets.only(right: 5, top: 2),
                    child: MiniBadge(text: '置顶', color: Color(0xFFE0623A)),
                  ),
                if (asBool(th['essence']))
                  const Padding(
                    padding: EdgeInsets.only(right: 5, top: 2),
                    child: MiniBadge(text: '精华', color: Color(0xFFCC9A2B)),
                  ),
                Expanded(
                  child: Text(asStr(th['title']),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: t.text,
                          fontSize: 15,
                          height: 1.35,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            if (asStr(th['body']).isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(asStr(th['body']),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(color: t.text2, fontSize: 12.5, height: 1.5)),
            ],
            const SizedBox(height: 9),
            Row(
              children: [
                Text(asStr(author['username']),
                    style: TextStyle(color: t.text3, fontSize: 11.5)),
                const SizedBox(width: 8),
                Text(ago(th['lastReplyAt'] ?? th['createdAt']),
                    style: TextStyle(color: t.text3, fontSize: 11.5)),
                const Spacer(),
                Icon(Icons.mode_comment_outlined, size: 13, color: t.text3),
                const SizedBox(width: 3),
                Text('${asInt(th['replies'])}',
                    style: TextStyle(color: t.text3, fontSize: 11.5)),
                const SizedBox(width: 10),
                Icon(Icons.visibility_outlined, size: 13, color: t.text3),
                const SizedBox(width: 3),
                Text('${asInt(th['views'])}',
                    style: TextStyle(color: t.text3, fontSize: 11.5)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
