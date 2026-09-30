import 'dart:async';

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/api.dart';
import '../core/store.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import 'chat_page.dart';
import 'user_profile_page.dart';

/// ============================================================
///  好友管理（原生）：好友 / 申请 / 已发出 / 黑名单 + 找人
/// ============================================================
class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 4, vsync: this);

  FriendsData _data = FriendsData();
  bool _loading = true;
  String? _err;

  final _searchCtrl = TextEditingController();
  List<UserLite> _results = <UserLite>[];
  bool _searching = false;
  String? _searchMsg;
  StreamSubscription<RtPing>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = RtBus.i.stream.listen((p) {
      if (mounted && (p.tag == 'friend' || p.tag == 'login')) _load(silent: true);
    });
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final j = await Api.i.friends();
      if (!mounted) return;
      setState(() {
        _data = FriendsData.fromJson(j);
        _loading = false;
        _err = null;
      });
      AppState.i.refreshUnread(silent: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent) _err = e is ApiError ? e.message : e.toString();
      });
    }
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _searching = true;
      _searchMsg = null;
      _results = <UserLite>[];
    });
    try {
      final j = await Api.i.userSearch(q);
      final list = asList(j['users']).map(UserLite.fromJson).toList();
      if (!mounted) return;
      setState(() {
        _results = list;
        _searching = false;
        _searchMsg = list.isEmpty ? '没找到「$q」，试试站内用户名或游戏 ID' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchMsg = e is ApiError ? e.message : '搜索失败';
      });
    }
  }

  Future<void> _addFriend(UserLite u) async {
    try {
      await Api.i.friendRequest(u.id);
      _toast('已发送好友申请');
      _load(silent: true);
      _search();
    } catch (e) {
      _toast(e is ApiError ? e.message : '申请失败');
    }
  }

  Future<void> _accept(UserLite u) async {
    try {
      await Api.i.friendAccept(u.id);
      _toast('已同意，现在可以聊天了');
      _load(silent: true);
    } catch (e) {
      _toast(e is ApiError ? e.message : '操作失败');
    }
  }

  Future<void> _reject(UserLite u) async {
    try {
      await Api.i.friendReject(u.id);
      _load(silent: true);
    } catch (e) {
      _toast(e is ApiError ? e.message : '操作失败');
    }
  }

  Future<void> _openChat(UserLite u) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatPage(userId: u.id, peerName: u.display)));
    _load(silent: true);
  }

  Future<void> _openProfile(String username) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => UserProfilePage(username: username)));
    _load(silent: true);
  }

  Future<void> _actions(UserLite u, {bool isFriend = true}) async {
    final t = GlassTokens.of(context);
    await GlassSheet.show(context, child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isFriend)
          ListTile(
            leading: Icon(Icons.chat_bubble_outline_rounded,
                size: 20, color: t.text2),
            title: Text('发私信', style: TextStyle(fontSize: 14, color: t.text)),
            onTap: () {
              Navigator.pop(context);
              _openChat(u);
            },
          ),
        ListTile(
          leading: Icon(Icons.person_rounded, size: 20, color: t.text2),
          title: Text('查看主页', style: TextStyle(fontSize: 14, color: t.text)),
          onTap: () {
            Navigator.pop(context);
            _openProfile(u.username);
          },
        ),
        if (isFriend)
          ListTile(
            leading: Icon(Icons.edit_note_rounded, size: 20, color: t.text2),
            title: Text('设置备注 / 分组',
                style: TextStyle(fontSize: 14, color: t.text)),
            onTap: () {
              Navigator.pop(context);
              _editMeta(u);
            },
          ),
        if (isFriend)
          ListTile(
            leading: const Icon(Icons.block_rounded,
                size: 20, color: GlassTokens.danger),
            title: const Text('拉黑（加入黑名单）',
                style: TextStyle(fontSize: 14, color: GlassTokens.danger)),
            onTap: () async {
              Navigator.pop(context);
              try {
                await Api.i.friendBlock(u.id);
                _toast('已拉黑');
                _load(silent: true);
              } catch (e) {
                _toast(e is ApiError ? e.message : '操作失败');
              }
            },
          ),
        if (isFriend)
          ListTile(
            leading: const Icon(Icons.person_remove_rounded,
                size: 20, color: GlassTokens.danger),
            title: const Text('删除好友',
                style: TextStyle(fontSize: 14, color: GlassTokens.danger)),
            onTap: () async {
              Navigator.pop(context);
              final ok = await GlassDialog.confirm(
                context,
                title: '删除好友',
                message: '删除后 ${u.display} 会从好友列表消失，聊天记录也会一起清空。',
                okLabel: '删除',
                danger: true,
              );
              if (ok != true) return;
              try {
                await Api.i.friendDelete(u.id);
                _toast('已删除好友');
                _load(silent: true);
              } catch (e) {
                _toast(e is ApiError ? e.message : '删除失败');
              }
            },
          ),
      ],
    ));
  }

  Future<void> _editMeta(UserLite u) async {
    final remark = TextEditingController(text: u.remark ?? '');
    final group = TextEditingController(text: u.group ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('备注与分组'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: remark,
              maxLength: 24,
              decoration: const InputDecoration(
                  labelText: '备注名', hintText: '例如：班长'),
            ),
            TextField(
              controller: group,
              maxLength: 16,
              decoration: const InputDecoration(
                  labelText: '分组', hintText: '例如：同学 / 服里朋友'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('保存')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.i.friendMeta(u.id, remark: remark.text.trim(), group: group.text.trim());
      _toast('已保存');
      _load(silent: true);
    } catch (e) {
      _toast(e is ApiError ? e.message : '保存失败');
    }
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
    return AuroraBg(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('好友'),
          bottom: TabBar(
            controller: _tab,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: t.accent,
            unselectedLabelColor: t.text3,
            indicatorColor: t.accent,
            tabs: [
              Tab(text: '好友 ${_data.friends.length}'),
              Tab(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('申请'),
                  if (_data.incoming.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    GlassBadge(count: _data.incoming.length),
                  ],
                ]),
              ),
              Tab(text: '已发出 ${_data.outgoing.length}'),
              Tab(text: '黑名单 ${_data.blocked.length}'),
            ],
          ),
        ),
        body: _loading
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Column(children: [
                  GlassSkeleton(height: 52, radius: 14),
                  SizedBox(height: 10),
                  GlassSkeleton(height: 52, radius: 14),
                  SizedBox(height: 10),
                  GlassSkeleton(height: 52, radius: 14),
                ]),
              )
            : Column(
                children: [
                  _searchBar(t),
                  Expanded(
                    child: TabBarView(
                      controller: _tab,
                      children: [
                        _list(_data.friends, t, empty: '还没有好友\n用上面的搜索找找看'),
                        _list(_data.incoming, t,
                            incoming: true, empty: '没有待处理的好友申请'),
                        _list(_data.outgoing, t,
                            outgoing: true, empty: '没有等待对方同意的申请'),
                        _list(_data.blocked, t,
                            blocked: true, empty: '黑名单是空的'),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _searchBar(GlassTokens t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onSubmitted: (_) => _search(),
              textInputAction: TextInputAction.search,
              style: TextStyle(fontSize: 14, color: t.text),
              decoration: InputDecoration(
                hintText: '搜索用户名 / 游戏 ID',
                hintStyle: TextStyle(fontSize: 13.5, color: t.text3),
                prefixIcon: Icon(Icons.search_rounded, size: 20, color: t.text3),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                filled: true,
                fillColor: t.fill,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: t.stroke),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: t.accent, width: 1.3),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GlassIconButton(
              icon: Icons.person_add_alt_1_rounded,
              size: 42,
              tooltip: '搜索',
              onTap: _search),
        ],
      ),
    );
  }

  Widget _list(
    List<UserLite> list,
    GlassTokens t, {
    bool incoming = false,
    bool outgoing = false,
    bool blocked = false,
    String empty = '这里还是空的',
  }) {
    if (_results.isNotEmpty && !incoming && !outgoing && !blocked) {
      // 搜索有结果时优先展示搜索结果
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 90),
        itemCount: _results.length + 1,
        itemBuilder: (ctx, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text('搜索结果（${_results.length}）',
                      style: TextStyle(fontSize: 12.5, color: t.text3)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() {
                      _results = <UserLite>[];
                      _searchCtrl.clear();
                    }),
                    child: const Text('清除', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            );
          }
          return _resultRow(_results[i - 1], t);
        },
      );
    }
    if (_searching) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (list.isEmpty) {
      if (_err != null) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [ErrorPanel(message: _err!, onRetry: () => _load())],
        );
      }
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          EmptyHint(text: _searchMsg ?? empty, icon: Icons.people_outline_rounded),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 90),
        itemCount: list.length,
        itemBuilder: (ctx, i) => _row(list[i], t,
            incoming: incoming, outgoing: outgoing, blocked: blocked),
      ),
    );
  }

  Widget _resultRow(UserLite u, GlassTokens t) {
    final isFriend = _data.friends.any((f) => f.id == u.id);
    final isPending = _data.outgoing.any((f) => f.id == u.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _avatar(u, t, online: u.online),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u.username,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: t.text)),
                  if (u.bio != null && u.bio!.isNotEmpty)
                    Text(u.bio!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: t.text3)),
                ],
              ),
            ),
            if (isFriend)
              GlassButton(
                label: '私信',
                expand: false,
                height: 34,
                icon: Icons.chat_bubble_outline_rounded,
                onTap: () => _openChat(u),
              )
            else if (isPending)
              Text('等待同意', style: TextStyle(fontSize: 12, color: t.text3))
            else
              GlassButton(
                label: '加好友',
                expand: false,
                height: 34,
                primary: true,
                icon: Icons.person_add_alt_1_rounded,
                onTap: () => _addFriend(u),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(UserLite u, GlassTokens t,
      {bool incoming = false, bool outgoing = false, bool blocked = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        onTap: () => _openProfile(u.username),
        child: GestureDetector(
          onLongPress: () => blocked
              ? _unblock(u)
              : (incoming || outgoing ? null : _actions(u)),
          child: Row(
            children: [
              _avatar(u, t, online: u.online),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(u.display,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: t.text)),
                        ),
                        if (u.remark != null && u.remark!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text('(${u.username})',
                                style:
                                    TextStyle(fontSize: 11, color: t.text3)),
                          ),
                        if (u.group != null && u.group!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: GlassChip(label: u.group!, active: false),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      blocked
                          ? '已拉黑'
                          : (u.mcName != null
                              ? '游戏 ID ${u.mcName}'
                              : (u.online ? '在线' : '站内好友')),
                      style: TextStyle(fontSize: 11.5, color: t.text3),
                    ),
                  ],
                ),
              ),
              if (incoming) ...[
                GlassButton(
                    label: '同意',
                    expand: false,
                    height: 34,
                    primary: true,
                    onTap: () => _accept(u)),
                const SizedBox(width: 6),
                GlassButton(
                    label: '拒绝',
                    expand: false,
                    height: 34,
                    onTap: () => _reject(u)),
              ] else if (outgoing)
                GlassIconButton(
                    icon: Icons.close_rounded,
                    size: 34,
                    tooltip: '撤回申请',
                    onTap: () => _reject(u))
              else if (blocked)
                GlassButton(
                    label: '解除',
                    expand: false,
                    height: 34,
                    onTap: () => _unblock(u))
              else
                GlassIconButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    size: 36,
                    tooltip: '发私信',
                    onTap: () => _openChat(u)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _unblock(UserLite u) async {
    try {
      await Api.i.friendUnblock(u.id);
      _toast('已解除拉黑');
      _load(silent: true);
    } catch (e) {
      _toast(e is ApiError ? e.message : '操作失败');
    }
  }

  Widget _avatar(UserLite u, GlassTokens t, {bool online = false}) {
    final url = u.avatarUrl;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: t.fillStrong,
        border: Border.all(
            color: online ? t.accent : t.stroke, width: online ? 2 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? Center(
              child: Text(
                u.username.isEmpty ? '?' : u.username.substring(0, 1).toUpperCase(),
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: t.text2),
              ),
            )
          : Image.network(url,
              fit: BoxFit.cover,
              errorBuilder: (a, b, s) =>
                  Icon(Icons.person_rounded, size: 20, color: t.text3)),
    );
  }
}
