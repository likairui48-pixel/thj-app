import 'dart:async';

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/api.dart';
import '../core/realtime.dart';
import '../core/store.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import 'chat_page.dart';
import 'friends_page.dart';
import 'user_profile_page.dart';

/// ============================================================
///  私信会话列表（原生）
///  实时：收到 dm 事件立刻刷新；长连接不可用时 10 秒轮询兜底
/// ============================================================
class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  List<DmConv> _convs = <DmConv>[];
  bool _loading = true;
  String? _err;
  int _pendingFriends = 0;
  StreamSubscription<RtPing>? _sub;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _sub = RtBus.i.stream.listen((p) {
      if (!mounted) return;
      if (p.tag.startsWith('dm') || p.tag == 'login' || p.tag == 'friend') {
        _load(silent: true);
      }
    });
    _poll = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && !Realtime.i.connected) _load(silent: true);
    });
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final j = await Api.i.dmConversations();
      final list = asList(j['conversations']).map(DmConv.fromJson).toList();
      // 置顶优先，其次按最后消息时间
      list.sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return b.lastTs.compareTo(a.lastTs);
      });
      var pending = 0;
      try {
        final f = await Api.i.friends();
        pending = asList(f['incoming']).length;
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _convs = list;
        _pendingFriends = pending;
        _loading = false;
        _err = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent) _err = e is ApiError ? e.message : e.toString();
      });
    }
  }

  Future<void> _open(DmConv c) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ChatPage(userId: c.peer.id, peerName: c.peer.display),
      ),
    );
    _load(silent: true);
  }

  Future<void> _actions(DmConv c) async {
    final t = GlassTokens.of(context);
    await GlassSheet.show(context, child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: Icon(Icons.push_pin_rounded, size: 20, color: t.text2),
          title: Text(c.pinned ? '取消置顶' : '置顶会话',
              style: TextStyle(fontSize: 14, color: t.text)),
          onTap: () async {
            Navigator.pop(context);
            try {
              await Api.i.dmPin(c.peer.id, value: !c.pinned);
              _load(silent: true);
            } catch (e) {
              _toast(e is ApiError ? e.message : '操作失败');
            }
          },
        ),
        ListTile(
          leading: Icon(Icons.notifications_off_outlined,
              size: 20, color: t.text2),
          title: Text(c.muted ? '取消免打扰' : '免打扰',
              style: TextStyle(fontSize: 14, color: t.text)),
          onTap: () async {
            Navigator.pop(context);
            try {
              await Api.i.dmMute(c.peer.id, value: !c.muted);
              _load(silent: true);
            } catch (e) {
              _toast(e is ApiError ? e.message : '操作失败');
            }
          },
        ),
        ListTile(
          leading: Icon(Icons.person_rounded, size: 20, color: t.text2),
          title: Text('查看主页',
              style: TextStyle(fontSize: 14, color: t.text)),
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => UserProfilePage(username: c.peer.username),
            ));
          },
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline_rounded,
              size: 20, color: GlassTokens.danger),
          title: const Text('删除会话',
              style: TextStyle(fontSize: 14, color: GlassTokens.danger)),
          onTap: () async {
            Navigator.pop(context);
            final ok = await GlassDialog.confirm(
              context,
              title: '删除会话',
              message: '与 ${c.peer.display} 的聊天记录会被清空（双方都看不到），不可恢复。',
              okLabel: '删除',
              danger: true,
            );
            if (ok != true) return;
            try {
              await Api.i.dmDelete(c.peer.id);
              _load(silent: true);
            } catch (e) {
              _toast(e is ApiError ? e.message : '删除失败');
            }
          },
        ),
      ],
    ));
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
          title: const Text('私信'),
          actions: [
            GlassIconButton(
              icon: Icons.group_add_outlined,
              size: 38,
              badge: _pendingFriends,
              tooltip: '好友与申请',
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const FriendsPage()));
                _load(silent: true);
              },
            ),
            const SizedBox(width: 10),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => _load(silent: true),
          child: _body(t),
        ),
      ),
    );
  }

  Widget _body(GlassTokens t) {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: List<Widget>.generate(
          6,
          (i) => const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: GlassSkeleton(height: 58, radius: 16),
          ),
        ),
      );
    }
    if (_err != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [ErrorPanel(message: _err!, onRetry: _load)],
      );
    }
    if (_convs.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const EmptyHint(
              text: '还没有私信\n去「好友」里找人聊两句吧',
              icon: Icons.forum_outlined),
          const SizedBox(height: 12),
          GlassButton(
            label: '找好友 / 加好友',
            icon: Icons.person_search_rounded,
            onTap: () async {
              await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FriendsPage()));
              _load(silent: true);
            },
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 90),
      itemCount: _convs.length,
      itemBuilder: (ctx, i) => _row(_convs[i], t),
    );
  }

  Widget _row(DmConv c, GlassTokens t) {
    final url = c.peer.avatarUrl;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        onTap: () => _open(c),
        child: GestureDetector(
          onLongPress: () => _actions(c),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: t.fillStrong,
                      border: Border.all(
                          color: c.online ? t.accent : t.stroke,
                          width: c.online ? 2 : 1),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: url == null
                        ? Center(
                            child: Text(
                              c.peer.username.isEmpty
                                  ? '?'
                                  : c.peer.username.substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: t.text2),
                            ),
                          )
                        : Image.network(url,
                            fit: BoxFit.cover,
                            errorBuilder: (a, b, s) => Icon(
                                Icons.person_rounded,
                                size: 20,
                                color: t.text3)),
                  ),
                  if (c.pinned)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Icon(Icons.push_pin_rounded,
                          size: 13, color: t.accent),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.peer.display,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: t.text),
                          ),
                        ),
                        if (c.muted)
                          Icon(Icons.notifications_off_outlined,
                              size: 13, color: t.text3),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      c.lastBody == null
                          ? '开始聊天'
                          : '${c.lastMine ? '我：' : ''}${c.lastBody}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: t.text3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(shortAgo(c.lastTs),
                      style: TextStyle(fontSize: 10.5, color: t.text3)),
                  const SizedBox(height: 6),
                  if (c.unread > 0) GlassBadge(count: c.unread),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 会话列表里的时间：刚刚 / 12:30 / 昨天 / 03-12
String shortAgo(int ts) {
  if (ts <= 0) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  final now = DateTime.now();
  final diff = now.difference(d);
  if (diff.inMinutes < 1) return '刚刚';
  final sameDay = d.year == now.year && d.month == now.month && d.day == now.day;
  if (sameDay) {
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
  if (diff.inDays < 1) return '昨天';
  if (diff.inDays < 7) return '${diff.inDays} 天前';
  return '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
