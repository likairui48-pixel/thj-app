import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/cache.dart';
import '../core/nav.dart';
import '../core/state.dart';
import '../core/ui.dart';
import 'compose.dart';
import 'login.dart';
import 'search.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key, this.initialBoard});

  final String? initialBoard;

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  final _state = AppState.i;
  late String? _board = widget.initialBoard;
  String _sort = 'new';
  int _page = 1;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _err;
  List<Map<String, dynamic>> _boards = const [];
  List<Map<String, dynamic>> _threads = const [];

  @override
  void initState() {
    super.initState();
    _loadBoards();
    _load(reset: true);
  }

  Future<void> _loadBoards() async {
    try {
      final j = await Api.i.forumBoards();
      if (mounted) setState(() => _boards = asList(j['boards']));
    } catch (_) {}
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      _page = 1;
      _threads = const [];
    }
    setState(() {
      _loading = _threads.isEmpty;
      _err = null;
    });
    try {
      final j = await Api.i.forumThreads(
        board: _board,
        page: _page,
        size: 20,
        sort: _sort,
      );
      final list = asList(j['threads']);
      if (!mounted) return;
      setState(() {
        _threads = reset || _page == 1 ? list : [..._threads, ...list];
        _total = asInt(j['total']);
        _loading = false;
        _loadingMore = false;
      });
      if (_page == 1) {
        await Cache.save('community_${_board ?? 'all'}_$_sort', j);
      }
    } catch (e) {
      if (!mounted) return;
      if (_threads.isEmpty) {
        final cached = await Cache.load('community_${_board ?? 'all'}_$_sort');
        if (cached != null && mounted) {
          setState(() {
            _threads = asList(cached['threads']);
            _total = asInt(cached['total']);
            _loading = false;
          });
          return;
        }
      }
      setState(() {
        _err = e.toString();
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _openCompose() async {
    if (!_state.isLoggedIn) {
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      return;
    }
    final res = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => ComposePage(initialBoard: _board)),
    );
    if (res != null && mounted) {
      Nav.to('/forum/thread/$res');
      _load(reset: true);
    }
  }

  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SearchPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final boards = [
      {'id': '', 'name': '全部'},
      ..._boards,
    ];
    return AppPage(
      title: '社区',
      actions: [
        IconButton(
          tooltip: '搜索',
          onPressed: _openSearch,
          icon: const Icon(Icons.search_rounded),
        ),
        IconButton(
          tooltip: '发帖',
          onPressed: _openCompose,
          icon: const Icon(Icons.edit_rounded),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          children: [
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: boards.map((b) {
                  final id = asStr(b['id']);
                  final on = _board == (id.isEmpty ? null : id) ||
                      (_board == null && id.isEmpty);
                  return Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: ChoiceChip(
                      label: Text(asStr(b['name'], '版块')),
                      selected: on,
                      onSelected: (_) {
                        setState(() => _board = id.isEmpty ? null : id);
                        _load(reset: true);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'new', label: Text('最新')),
                    ButtonSegment(value: 'hot', label: Text('热门')),
                  ],
                  selected: {_sort},
                  onSelectionChanged: (s) {
                    setState(() => _sort = s.first);
                    _load(reset: true);
                  },
                  showSelectedIcon: false,
                ),
                const Spacer(),
                Text(
                  '共 $_total 帖',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AsyncView(
              loading: _loading,
              error: _err,
              onRetry: () => _load(reset: true),
              isEmpty: !_loading && _threads.isEmpty && _err == null,
              emptyText: '这个版块还没有帖子，来发第一帖',
              emptyIcon: Icons.edit_note_rounded,
              child: Column(
                children: [
                  ..._threads.map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _threadCard(context, t),
                    ),
                  ),
                  if (_threads.length < _total)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: OutlinedButton(
                        onPressed: _loadingMore
                            ? null
                            : () {
                                setState(() => _loadingMore = true);
                                _page += 1;
                                _load();
                              },
                        child: _loadingMore
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('加载更多'),
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

  Widget _threadCard(BuildContext context, Map<String, dynamic> t) {
    final cs = Theme.of(context).colorScheme;
    final author = asMap(t['author']);
    final images = asStrList(t['images']);
    final badges = <Widget>[
      if (asBool(t['pinned'])) const Pill(text: '置顶', color: AppColors.warning),
      if (asBool(t['essence'])) const Pill(text: '精华', color: AppColors.teal),
      if (asBool(t['locked'])) const Pill(text: '已锁', color: Colors.grey),
    ];
    final body = asStr(t['body']);
    return AppCard(
      onTap: () => Nav.to('/forum/thread/${asInt(t['id'])}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                name: asStr(author['username']),
                avatar: asStrOrNull(author['avatar']),
                size: 38,
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
                        const SizedBox(width: 4),
                        MembershipPill(
                          membership: asMap(author['membership']),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fmtAgo(t['createdAt']),
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '#${asInt(t['id'])}',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 5,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...badges,
              Text(
                asStr(t['title'], '无标题'),
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
            ],
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 11.5,
                height: 1.5,
              ),
            ),
          ],
          if (images.isNotEmpty) ...[
            const SizedBox(height: 9),
            NetImage(
              url: images.first,
              width: double.infinity,
              height: 130,
            ),
          ],
          const SizedBox(height: 9),
          Row(
            children: [
              _stat(Icons.chat_bubble_outline_rounded, '${asInt(t['replies'])}'),
              const SizedBox(width: 12),
              _stat(Icons.visibility_outlined, '${asInt(t['views'])}'),
              const SizedBox(width: 12),
              if (asInt(t['imageCount']) > 0)
                _stat(Icons.image_outlined, '${asInt(t['imageCount'])}'),
              const Spacer(),
              if (t['last'] != null)
                Text(
                  '最后回复 ${asStr(asMap(t['last'])['username'])}',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String text) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 13, color: cs.onSurfaceVariant),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10.5),
        ),
      ],
    );
  }
}
