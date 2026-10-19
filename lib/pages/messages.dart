import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/nav.dart';
import '../core/state.dart';
import '../core/ui.dart';
import 'chat.dart';
import 'friends.dart';
import 'login.dart';
import 'settings.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage>
    with SingleTickerProviderStateMixin {
  final _state = AppState.i;
  late final TabController _tab = TabController(length: 3, vsync: this);
  bool _loading = true;
  String? _err;
  List<Map<String, dynamic>> _convs = const [];
  Map<String, dynamic> _friends = <String, dynamic>{};
  String _group = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
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
        Api.i.dmConversations(),
        Api.i.friends(),
      ]);
      if (!mounted) return;
      setState(() {
        _convs = asList(results[0]['conversations']);
        _friends = results[1];
        _loading = false;
      });
      await _state.refreshNotifications(silent: true);
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

  Future<void> _openChat(int? uid) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatPage(userId: uid)),
    );
    _load();
  }

  Future<void> _convMenu(Map<String, dynamic> c) async {
    final u = asMap(c['user']);
    final uid = asInt(u['id']);
    final pinned = asBool(c['pinned']);
    final muted = asBool(c['muted']);
    await showAppSheet<void>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline_rounded),
            title: Text('打开与 ${asStr(u['username'])} 的会话'),
            onTap: () {
              Navigator.pop(context);
              _openChat(uid);
            },
          ),
          ListTile(
            leading: Icon(pinned ? Icons.push_pin : Icons.push_pin_outlined),
            title: Text(pinned ? '取消置顶' : '置顶会话'),
            onTap: () async {
              Navigator.pop(context);
              try {
                await Api.i.dmPin(uid, value: !pinned);
                await _load();
              } catch (e) {
                if (mounted) showToast(context, e.toString(), error: true);
              }
            },
          ),
          ListTile(
            leading: Icon(muted ? Icons.volume_up_outlined : Icons.volume_off_outlined),
            title: Text(muted ? '取消免打扰' : '免打扰'),
            onTap: () async {
              Navigator.pop(context);
              try {
                await Api.i.dmMute(uid, value: !muted);
                await _load();
              } catch (e) {
                if (mounted) showToast(context, e.toString(), error: true);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded,
                color: AppColors.danger),
            title: const Text('删除会话',
                style: TextStyle(color: AppColors.danger)),
            onTap: () async {
              Navigator.pop(context);
              final ok = await showConfirm(
                context,
                title: '删除会话',
                message: '聊天记录会从你的列表里移除（对方那边也会一起清空），不可恢复。',
                okText: '删除',
                danger: true,
              );
              if (!ok) return;
              try {
                await Api.i.dmDelete(uid);
                await _load();
              } catch (e) {
                if (mounted) showToast(context, e.toString(), error: true);
              }
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (!_state.isLoggedIn) {
      return AppPage(
        title: '消息',
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.forum_outlined,
                    color: AppColors.brand, size: 46),
                const SizedBox(height: 14),
                const Text(
                  '登录后，通知、私信、好友申请都会在这里',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _login,
                  icon: const Icon(Icons.login_rounded, size: 18),
                  label: const Text('登录 / 注册'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final incoming = asList(_friends['incoming']);
    final notifications = _state.notifications;
    final filtered = _group == 'all'
        ? notifications
        : notifications.where((n) => _groupOf(n) == _group).toList();

    return AppPage(
      title: '消息',
      actions: [
        IconButton(
          tooltip: '全部已读',
          onPressed: () async {
            await _state.markAllRead();
            if (mounted) showToast(context, '已全部标记为已读');
          },
          icon: const Icon(Icons.done_all_rounded),
        ),
        IconButton(
          tooltip: '设置',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsPage()),
          ),
          icon: const Icon(Icons.tune_rounded),
        ),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            child: TabBar(
              controller: _tab,
              tabs: [
                Tab(
                  text:
                      '通知${_state.unread > 0 ? ' ${_state.unread}' : ''}',
                ),
                Tab(
                  text: '私信${_state.dmUnread > 0 ? ' ${_state.dmUnread}' : ''}',
                ),
                Tab(
                  text:
                      '好友${incoming.isNotEmpty ? ' ${incoming.length}' : ''}',
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncView(
              loading: _loading,
              error: _err,
              onRetry: _load,
              child: TabBarView(
                controller: _tab,
                children: [
                  _notificationsTab(context, filtered),
                  _dmTab(context),
                  _friendsTab(context, incoming),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notificationsTab(
      BuildContext context, List<Map<String, dynamic>> list) {
    final cs = Theme.of(context).colorScheme;
    final groups = <String, String>{
      'all': '全部',
      'dm': '私聊',
      'mention': '@我',
      'friend': '好友',
      'report': '举报',
      'membership': '会员',
      'rank': '段位',
      'system': '系统',
    };
    return RefreshIndicator(
      onRefresh: () => _state.refreshNotifications(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: groups.entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: _group == e.key,
                    onSelected: (_) => setState(() => _group = e.key),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          if (list.isEmpty)
            const EmptyView(
              text: '暂时没有通知，有新动态会显示在这里',
              icon: Icons.notifications_none_rounded,
            )
          else
            ...list.map(
              (n) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _notifCard(context, n),
              ),
            ),
        ],
      ),
    );
  }

  Widget _notifCard(BuildContext context, Map<String, dynamic> n) {
    final cs = Theme.of(context).colorScheme;
    final unread = asInt(n['read_at']) == 0;
    final kind = asStr(n['kind']);
    final icon = _notifIcon(kind);
    final color = _notifColor(kind);
    return AppCard(
      color: unread ? color.withOpacity(0.05) : null,
      onTap: () => _state.openNotification(n),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        asStr(n['title'], '通知'),
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 13,
                          fontWeight:
                              unread ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (unread)
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                if (asStr(n['body']).isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    asStr(n['body']),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 11.5,
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  fmtAgo(n['created_at']),
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dmTab(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          AppCard(
            onTap: () => _openChat(null),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.brand, AppColors.teal],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.public_rounded,
                      color: Colors.white, size: 23),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '世界频道',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '和游戏内玩家互通，绑定游戏 ID 后可发言',
                        style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (_convs.isEmpty)
            const EmptyView(
              text: '还没有私聊。去好友列表找人聊聊吧',
              icon: Icons.chat_bubble_outline_rounded,
            )
          else
            ..._convs.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _convCard(context, c),
              ),
            ),
        ],
      ),
    );
  }

  Widget _convCard(BuildContext context, Map<String, dynamic> c) {
    final cs = Theme.of(context).colorScheme;
    final u = asMap(c['user']);
    final last = asMap(c['last']);
    final unread = asInt(c['unread']);
    final online = asBool(c['online']);
    final pinned = asBool(c['pinned']);
    final muted = asBool(c['muted']);
    final body = asStr(last['body']);
    return AppCard(
      onTap: () => _openChat(asInt(u['id'])),
      onLongPress: () => _convMenu(c),
      child: Row(
        children: [
          UserAvatar(
            name: asStr(u['username']),
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
                        asStr(u['username'], '会话'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (pinned) ...[
                      const SizedBox(width: 5),
                      const Icon(Icons.push_pin,
                          size: 12, color: AppColors.warning),
                    ],
                    if (muted) ...[
                      const SizedBox(width: 5),
                      Icon(Icons.volume_off,
                          size: 12, color: cs.onSurfaceVariant),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  body.isEmpty
                      ? '开始聊天'
                      : '${asBool(last['mine']) ? '我：' : ''}$body',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                fmtAgo(last['ts']),
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 9.5,
                ),
              ),
              if (unread > 0) ...[
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _friendsTab(
      BuildContext context, List<Map<String, dynamic>> incoming) {
    final outgoing = asList(_friends['outgoing']);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              Text(
                '好友申请',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FriendsPage()),
                  );
                  _load();
                },
                child: const Text('好友管理'),
              ),
            ],
          ),
          if (incoming.isEmpty)
            const EmptyView(
              text: '没有新的好友申请',
              icon: Icons.person_add_alt_1_rounded,
            )
          else
            ...incoming.map(
              (u) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  child: Row(
                    children: [
                      UserAvatar(
                        name: asStr(u['username']),
                        avatar: asStrOrNull(u['avatar']),
                        size: 42,
                        online: asBool(u['online']),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              asStr(u['username'], '玩家'),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${asStr(u['mcName'], '未绑定')} · ${fmtAgo(u['reqAt'])}',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await Api.i.friendReject(asInt(u['id']));
                          _load();
                        },
                        child: const Text('拒绝'),
                      ),
                      FilledButton(
                        onPressed: () async {
                          await Api.i.friendAccept(asInt(u['id']));
                          _load();
                        },
                        child: const Text('同意'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (outgoing.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              '我发出的申请',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            ...outgoing.map(
              (u) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  child: Row(
                    children: [
                      UserAvatar(
                        name: asStr(u['username']),
                        avatar: asStrOrNull(u['avatar']),
                        size: 38,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          asStr(u['username'], '玩家'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Pill(text: '等待对方同意', color: AppColors.warning),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _groupOf(Map<String, dynamic> n) {
    final kind = asStr(n['kind']);
    switch (kind) {
      case 'dm':
        return 'dm';
      case 'mention':
        return 'mention';
      case 'friend_request':
      case 'friend':
        return 'friend';
      case 'report':
        return 'report';
      case 'membership':
        return 'membership';
      case 'rank':
        return 'rank';
      default:
        return 'system';
    }
  }

  IconData _notifIcon(String kind) {
    switch (kind) {
      case 'dm':
        return Icons.chat_bubble_outline_rounded;
      case 'mention':
        return Icons.alternate_email_rounded;
      case 'friend_request':
        return Icons.person_add_alt_1_rounded;
      case 'friend':
        return Icons.people_outline_rounded;
      case 'report':
        return Icons.flag_outlined;
      case 'membership':
        return Icons.workspace_premium_outlined;
      case 'rank':
        return Icons.emoji_events_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _notifColor(String kind) {
    switch (kind) {
      case 'dm':
        return AppColors.teal;
      case 'friend_request':
        return AppColors.brand;
      case 'report':
        return AppColors.danger;
      case 'membership':
        return AppColors.gold;
      case 'rank':
        return const Color(0xFF8B5CF6);
      default:
        return AppColors.brand;
    }
  }
}
