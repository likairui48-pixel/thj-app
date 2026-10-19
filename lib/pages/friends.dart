import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/nav.dart';
import '../core/state.dart';
import '../core/ui.dart';
import 'chat.dart';
import 'login.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage>
    with SingleTickerProviderStateMixin {
  final _state = AppState.i;
  late final TabController _tab = TabController(length: 6, vsync: this);
  final _search = TextEditingController();
  bool _loading = true;
  String? _err;
  Map<String, dynamic> _data = <String, dynamic>{};
  List<Map<String, dynamic>> _following = const [];
  List<Map<String, dynamic>> _followers = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!_state.isLoggedIn) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final results = await Future.wait([
        Api.i.friends(),
        Api.i.following(),
        Api.i.followers(),
      ]);
      if (!mounted) return;
      setState(() {
        _data = results[0];
        _following = asList(results[1]['users']);
        _followers = asList(results[2]['users']);
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

  Future<void> _login() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
    await _load();
  }

  Future<void> _searchUsers() async {
    final q = _search.text.trim();
    if (q.length < 2) {
      showToast(context, '请输入至少 2 个字', error: true);
      return;
    }
    try {
      final j = await Api.i.userSearch(q);
      final users = asList(j['users']);
      if (!mounted) return;
      await showAppSheet<void>(
        context,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '搜索：$q',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              if (users.isEmpty)
                const EmptyView(text: '没有找到用户', icon: Icons.search_off_rounded)
              else
                ...users.map(
                  (u) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: UserAvatar(
                      name: asStr(u['username']),
                      avatar: asStrOrNull(u['avatar']),
                      size: 40,
                      online: asBool(u['online']),
                    ),
                    title: Text(asStr(u['username'], '用户')),
                    subtitle: Text(
                      asStr(u['mcName'], '未绑定游戏 ID'),
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: FilledButton(
                      onPressed: () async {
                        try {
                          await Api.i.friendRequest(asInt(u['id']));
                          if (context.mounted) Navigator.pop(context);
                          showToast(context, '好友申请已发送');
                          _load();
                        } catch (e) {
                          if (context.mounted) {
                            showToast(context, e.toString(), error: true);
                          }
                        }
                      },
                      child: const Text('加好友'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    }
  }

  Future<void> _openChat(int userId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatPage(userId: userId)),
    );
    _load();
  }

  Future<void> _remark(Map<String, dynamic> u) async {
    final remark = TextEditingController(text: asStr(u['remark']));
    final group = TextEditingController(text: asStr(u['group']));
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('备注与分组'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: remark,
              decoration: const InputDecoration(labelText: '备注名'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: group,
              decoration: const InputDecoration(labelText: '分组（如：老玩家 / 建筑党）'),
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
                await Api.i.friendMeta(
                  asInt(u['id']),
                  remark: remark.text.trim(),
                  group: group.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
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
    remark.dispose();
    group.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_state.isLoggedIn) {
      return AppPage(
        title: '好友',
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people_outline_rounded,
                    color: AppColors.brand, size: 46),
                const SizedBox(height: 12),
                const Text('登录后管理好友、关注与粉丝'),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: _login,
                  child: const Text('去登录'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final friends = asList(_data['friends']);
    final incoming = asList(_data['incoming']);
    final outgoing = asList(_data['outgoing']);
    final blocked = asList(_data['blocked']);

    return AppPage(
      title: '好友',
      actions: [
        IconButton(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: '刷新',
        ),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchUsers(),
                    decoration: const InputDecoration(
                      hintText: '搜索用户名 / 游戏 ID',
                      isDense: true,
                      prefixIcon: Icon(Icons.search_rounded, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _searchUsers,
                  child: const Text('添加'),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tab,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: '好友 ${friends.length}'),
              Tab(text: '新申请 ${incoming.length}'),
              Tab(text: '我发出的 ${outgoing.length}'),
              Tab(text: '关注 ${_following.length}'),
              Tab(text: '粉丝 ${_followers.length}'),
              Tab(text: '屏蔽 ${blocked.length}'),
            ],
          ),
          Expanded(
            child: AsyncView(
              loading: _loading,
              error: _err,
              onRetry: _load,
              child: TabBarView(
                controller: _tab,
                children: [
                  _userList(context, friends, 'friend'),
                  _userList(context, incoming, 'incoming'),
                  _userList(context, outgoing, 'outgoing'),
                  _userList(context, _following, 'following'),
                  _userList(context, _followers, 'followers'),
                  _userList(context, blocked, 'blocked'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _userList(
      BuildContext context, List<Map<String, dynamic>> users, String kind) {
    if (users.isEmpty) {
      final text = switch (kind) {
        'friend' => '还没有好友，去搜索加人吧',
        'incoming' => '没有新的好友申请',
        'outgoing' => '没有等待中的申请',
        'following' => '还没有关注任何人',
        'followers' => '还没有粉丝',
        'blocked' => '没有屏蔽任何人',
        _ => '暂无数据',
      };
      return EmptyView(text: text, icon: Icons.people_outline_rounded);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        itemCount: users.length,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: _userCard(context, users[i], kind),
        ),
      ),
    );
  }

  Widget _userCard(
      BuildContext context, Map<String, dynamic> u, String kind) {
    final cs = Theme.of(context).colorScheme;
    final id = asInt(u['id']);
    final name = asStr(u['username']);
    final remark = asStr(u['remark']);
    final group = asStr(u['group']);
    final online = asBool(u['online']);
    final mcName = asStr(u['mcName']);
    return AppCard(
      onTap: () => Nav.to('/u/${Uri.encodeComponent(name)}'),
      child: Row(
        children: [
          UserAvatar(
            name: name,
            avatar: asStrOrNull(u['avatar']),
            size: 44,
            online: online,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        remark.isEmpty ? name : '$remark（$name）',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (group.isNotEmpty) ...[
                      const SizedBox(width: 5),
                      Pill(text: group, color: AppColors.teal),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${mcName.isEmpty ? '未绑定游戏 ID' : mcName} · ${online ? '在线' : '离线'}'
                  '${kind == 'incoming' ? ' · ${fmtAgo(u['reqAt'])} 申请' : ''}',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          ..._actions(context, u, kind, id, name),
        ],
      ),
    );
  }

  List<Widget> _actions(BuildContext context, Map<String, dynamic> u,
      String kind, int id, String name) {
    switch (kind) {
      case 'friend':
        return [
          IconButton(
            tooltip: '私聊',
            onPressed: () => _openChat(id),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
          ),
          PopupMenuButton<String>(
            iconSize: 19,
            onSelected: (v) async {
              if (v == 'remark') _remark(u);
              if (v == 'delete') {
                final ok = await showConfirm(
                  context,
                  title: '删除好友',
                  message: '确定删除这位好友吗？',
                  okText: '删除',
                  danger: true,
                );
                if (!ok) return;
                await Api.i.friendDelete(id);
                _load();
              }
              if (v == 'block') {
                final ok = await showConfirm(
                  context,
                  title: '屏蔽',
                  message: '屏蔽后对方无法给你发消息，也不再收到对方申请。',
                  okText: '屏蔽',
                  danger: true,
                );
                if (!ok) return;
                await Api.i.friendBlock(id);
                _load();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'remark', child: Text('备注 / 分组')),
              PopupMenuItem(value: 'delete', child: Text('删除好友')),
              PopupMenuItem(value: 'block', child: Text('屏蔽')),
            ],
          ),
        ];
      case 'incoming':
        return [
          TextButton(
            onPressed: () async {
              await Api.i.friendReject(id);
              _load();
            },
            child: const Text('拒绝'),
          ),
          FilledButton(
            onPressed: () async {
              await Api.i.friendAccept(id);
              _load();
            },
            child: const Text('同意'),
          ),
        ];
      case 'outgoing':
        return [
          const Pill(text: '等待同意', color: AppColors.warning),
          const SizedBox(width: 4),
          TextButton(
            onPressed: () async {
              await Api.i.friendDelete(id);
              _load();
            },
            child: const Text('撤回'),
          ),
        ];
      case 'blocked':
        return [
          TextButton(
            onPressed: () async {
              await Api.i.friendUnblock(id);
              _load();
            },
            child: const Text('解除'),
          ),
        ];
      case 'following':
        return [
          TextButton(
            onPressed: () async {
              await Api.i.follow(name);
              _load();
            },
            child: const Text('取消关注'),
          ),
        ];
      default:
        return [
          OutlinedButton(
            onPressed: () => Nav.to('/u/${Uri.encodeComponent(name)}'),
            child: const Text('主页'),
          ),
        ];
    }
  }
}
