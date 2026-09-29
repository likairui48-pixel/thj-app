import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/api.dart';
import '../core/store.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import 'web_page.dart';

/// 消息中心：通知 / 私信 / 好友申请 三类未读 + 系统通知开关
class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key, this.onNeedLogin});

  final VoidCallback? onNeedLogin;

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage>
    with AutomaticKeepAliveClientMixin {
  final _state = AppState.i;
  List<NotifItem> _items = const <NotifItem>[];
  Map<String, List<NotifItem>> _groups = <String, List<NotifItem>>{};
  List<Map<String, dynamic>> _convs = <Map<String, dynamic>>[];
  bool _loading = false;
  String? _err;
  int _tab = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _state.addListener(_onChange);
    _load();
  }

  @override
  void dispose() {
    _state.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    if (!Api.i.hasSession) return;
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final j = await Api.i.notifications();
      final grouped = await Api.i.notificationsGrouped();
      List<Map<String, dynamic>> convs = <Map<String, dynamic>>[];
      try {
        final cj = await Api.i.conversations();
        convs = asList(cj['conversations']);
      } catch (_) {}
      final groups = <String, List<NotifItem>>{};
      final g = asMap(grouped['groups']);
      g.forEach((k, v) {
        groups[k] = asList(v).map(NotifItem.fromJson).toList();
      });
      setState(() {
        _items = asList(j['notifications']).map(NotifItem.fromJson).toList();
        _groups = groups;
        _convs = convs;
      });
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = GlassTokens.of(context);
    final unread = _state.unread;
    return RefreshIndicator(
      onRefresh: () async {
        await _state.refreshUnread();
        await _load();
      },
      color: t.accent,
      backgroundColor: t.brightness == Brightness.dark
          ? const Color(0xFF16171A)
          : Colors.white,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          R.page,
          MediaQuery.of(context).padding.top + 8,
          R.page,
          GlassPillNav.reserved(context),
        ),
        children: [
          Row(
            children: [
              Text('消息',
                  style: TextStyle(
                      color: t.text,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1)),
              const Spacer(),
              if (_state.unread.total > 0)
                GlassChip(
                  label: '全部已读',
                  icon: Icons.done_all_rounded,
                  onTap: () async {
                    await _state.markAllRead();
                    await _load();
                  },
                ),
            ],
          ),
          const SizedBox(height: 14),
          _summary(t, unread),
          if (!Api.i.hasSession) ...[
            const SizedBox(height: 14),
            GlassPanel(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Icon(Icons.lock_outline_rounded, size: 30, color: t.text3),
                  const SizedBox(height: 10),
                  Text('登录后才能收消息',
                      style: TextStyle(
                          color: t.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    '登录后，站内通知、私信、好友申请都会推到这里，\n还能收到系统级通知提醒。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: t.text3, fontSize: 12.5, height: 1.6),
                  ),
                  const SizedBox(height: 16),
                  GlassButton(
                    label: '去登录',
                    icon: Icons.login_rounded,
                    primary: true,
                    onTap: widget.onNeedLogin,
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            _tabs(t),
            const SizedBox(height: 12),
            if (_loading && _items.isEmpty)
              Column(
                children: List<Widget>.generate(
                  4,
                  (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: GlassSkeleton(height: 64, radius: 18),
                  ),
                ),
              )
            else if (_err != null)
              ErrorHint(message: _err!, onRetry: _load)
            else
              ..._list(t),
          ],
          const SizedBox(height: 16),
          _notifySetting(t),
        ],
      ),
    );
  }

  Widget _summary(GlassTokens t, UnreadInfo u) {
    final cells = <({String label, int value, IconData icon, String key})>[
      (
        label: '通知',
        value: u.notifications,
        icon: Icons.notifications_active_rounded,
        key: 'notify'
      ),
      (
        label: '私信',
        value: u.dm,
        icon: Icons.chat_bubble_rounded,
        key: 'dm'
      ),
      (
        label: '好友申请',
        value: u.friendReq,
        icon: Icons.person_add_alt_1_rounded,
        key: 'friend'
      ),
    ];
    return Row(
      children: [
        for (var i = 0; i < cells.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: GlassPanel(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
              radius: R.tile,
              strong: cells[i].value > 0,
              onTap: () {
                setState(() => _tab = i);
                if (cells[i].key == 'dm') {
                  _openWeb('私信', '/dm');
                } else if (cells[i].key == 'friend') {
                  _openWeb('好友', '/friends');
                }
              },
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(cells[i].icon,
                          size: 20,
                          color: cells[i].value > 0 ? t.accent : t.text3),
                      if (cells[i].value > 0)
                        Positioned(
                          right: -10,
                          top: -4,
                          child: GlassBadge(count: cells[i].value),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('${cells[i].value}',
                      style: TextStyle(
                          color: t.text,
                          fontSize: 17,
                          height: 1,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(cells[i].label,
                      style: TextStyle(color: t.text3, fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _tabs(GlassTokens t) {
    const labels = <String, String>{
      'all': '全部',
      'interaction': '互动',
      'social': '社交',
      'system': '系统',
    };
    final keys = labels.keys.toList();
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < keys.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Center(
              child: GlassChip(
                label: labels[keys[i]]!,
                active: _tab == i,
                onTap: () => setState(() => _tab = i),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _list(GlassTokens t) {
    if (_tab == 0) {
      if (_items.isEmpty) {
        return [
          const EmptyHint(
              text: '暂时没有新消息', icon: Icons.notifications_none_rounded)
        ];
      }
      return _items.map((n) => _notifTile(t, n)).toList();
    }
    final keys = <String>['all', 'interaction', 'social', 'system'];
    final groupKey = _tab < keys.length ? keys[_tab] : 'system';
    if (groupKey == 'all') return _items.map((n) => _notifTile(t, n)).toList();
    final list = _groups[groupKey] ?? const <NotifItem>[];
    if (list.isEmpty) {
      return [const EmptyHint(text: '这一类还没有消息', icon: Icons.inbox_rounded)];
    }
    return list.map((n) => _notifTile(t, n)).toList();
  }

  Widget _notifTile(GlassTokens t, NotifItem n) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: GlassPanel(
        radius: R.tile,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: () {
          if (n.link != null && n.link!.isNotEmpty) {
            _openWeb(n.title, n.link!);
          }
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: (n.read ? t.text3 : t.accent).withOpacity(0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                _iconOf(n.kind),
                size: 17,
                color: n.read ? t.text3 : t.accent,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: t.text,
                            fontSize: 14,
                            fontWeight:
                                n.read ? FontWeight.w500 : FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(relTime(n.createdAt),
                          style: TextStyle(color: t.text3, fontSize: 10.5)),
                    ],
                  ),
                  if (n.body.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      n.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: t.text2, fontSize: 12.5, height: 1.45),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconOf(String kind) {
    switch (kind) {
      case 'dm':
      case 'message':
        return Icons.chat_bubble_rounded;
      case 'friend':
        return Icons.person_add_alt_rounded;
      case 'forum':
      case 'reply':
      case 'like':
        return Icons.forum_rounded;
      case 'rank':
        return Icons.leaderboard_rounded;
      case 'pay':
      case 'membership':
        return Icons.card_giftcard_rounded;
      case 'system':
        return Icons.campaign_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Widget _notifySetting(GlassTokens t) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _state.notifyEnabled,
            activeColor: t.accent,
            title: Text('系统通知提醒',
                style: TextStyle(color: t.text, fontSize: 14)),
            subtitle: Text(
              NotifyServicePermissionText.of(context),
              style: TextStyle(color: t.text3, fontSize: 11.5),
            ),
            onChanged: (v) => _state.setNotifyEnabled(v),
          ),
          Divider(color: t.divider, height: 1),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _state.reduceMotion,
            activeColor: t.accent,
            title: Text('减弱动画效果',
                style: TextStyle(color: t.text, fontSize: 14)),
            subtitle: Text('省电 / 老机型更流畅',
                style: TextStyle(color: t.text3, fontSize: 11.5)),
            onChanged: (v) => _state.setReduceMotion(v),
          ),
        ],
      ),
    );
  }

  void _openWeb(String title, String path) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WebPage(title: title, path: path),
      ),
    );
  }
}

/// 通知权限文案（避免在页面里直接依赖插件细节）
class NotifyServicePermissionText {
  NotifyServicePermissionText._();
  static String of(BuildContext context) =>
      '新消息会以系统通知提醒你（Android 13+ 需授权）';
}
