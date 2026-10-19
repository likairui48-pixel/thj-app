import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/nav.dart';
import '../core/state.dart';
import '../core/ui.dart';
import 'chat.dart';
import 'edit_profile.dart';
import 'report.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.username});

  final String username;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _state = AppState.i;
  final _gb = TextEditingController();
  bool _loading = true;
  String? _err;
  Map<String, dynamic> _profile = <String, dynamic>{};
  Map<String, dynamic> _space = <String, dynamic>{};
  List<Map<String, dynamic>> _guestbook = const [];
  int _tab = 0;
  bool _sendingGb = false;
  bool _following = false;
  int? _replyTo;

  bool get _isSelf => widget.username == _state.username;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _gb.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final results = await Future.wait([
        Api.i.profile(widget.username),
        Api.i.space(widget.username),
        Api.i.guestbook(widget.username),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0];
        _space = results[1];
        _guestbook = asList(results[2]['entries']);
        _following = asBool(results[1]['isFollowing']);
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

  Future<void> _follow() async {
    if (!_state.isLoggedIn) {
      showToast(context, '登录后才能关注');
      return;
    }
    try {
      final j = await Api.i.follow(widget.username);
      if (!mounted) return;
      setState(() => _following = asBool(j['following'], !_following));
      await _load();
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    }
  }

  Future<void> _addFriend() async {
    final user = asMap(_profile['user']);
    try {
      await Api.i.friendRequest(asInt(user['id']));
      if (mounted) showToast(context, '好友申请已发送');
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    }
  }

  Future<void> _block() async {
    final user = asMap(_profile['user']);
    final relation = asStr(_profile['relation']);
    final blocked = relation == 'blocked';
    final ok = await showConfirm(
      context,
      title: blocked ? '解除屏蔽' : '屏蔽用户',
      message: blocked
          ? '解除后可重新收到对方的消息和申请。'
          : '屏蔽后对方无法给你发消息，也不再收到对方申请。',
      okText: blocked ? '解除' : '屏蔽',
      danger: !blocked,
    );
    if (!ok) return;
    try {
      if (blocked) {
        await Api.i.friendUnblock(asInt(user['id']));
      } else {
        await Api.i.friendBlock(asInt(user['id']));
      }
      await _load();
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    }
  }

  Future<void> _sendGb() async {
    final text = _gb.text.trim();
    if (text.isEmpty) return;
    setState(() => _sendingGb = true);
    try {
      await Api.i.postGuestbook(widget.username, text, replyTo: _replyTo);
      _gb.clear();
      setState(() => _replyTo = null);
      final j = await Api.i.guestbook(widget.username);
      if (!mounted) return;
      setState(() => _guestbook = asList(j['entries']));
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _sendingGb = false);
    }
  }

  Future<void> _deleteGb(int id) async {
    try {
      await Api.i.deleteGuestbook(id);
      final j = await Api.i.guestbook(widget.username);
      if (!mounted) return;
      setState(() => _guestbook = asList(j['entries']));
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    }
  }

  void _openReport() {
    final user = asMap(_profile['user']);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportPage(
          targetType: 'user',
          targetId: '${asInt(user['id'])}',
          targetLabel: '用户 ${widget.username}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: widget.username,
      actions: [
        if (!_isSelf)
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'report') _openReport();
              if (v == 'block') _block();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'report', child: Text('举报用户')),
              PopupMenuItem(
                value: 'block',
                child: Text(
                  asStr(_profile['relation']) == 'blocked' ? '解除屏蔽' : '屏蔽用户',
                ),
              ),
            ],
          ),
      ],
      child: AsyncView(
        loading: _loading,
        error: _err,
        onRetry: _load,
        isEmpty: !_loading && _profile.isEmpty,
        emptyText: '没有找到这位用户',
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
            children: [
              _header(context),
              const SizedBox(height: 12),
              _actions(context),
              const SizedBox(height: 12),
              _stats(context),
              const SizedBox(height: 12),
              _gameCard(context),
              const SizedBox(height: 12),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('动态')),
                  ButtonSegment(value: 1, label: Text('帖子')),
                  ButtonSegment(value: 2, label: Text('留言')),
                ],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
                showSelectedIcon: false,
              ),
              const SizedBox(height: 12),
              if (_tab == 0) ..._activity(context),
              if (_tab == 1) ..._threads(context),
              if (_tab == 2) _guestbookSection(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = asMap(_profile['user']);
    final prof = asMap(_profile['profile']);
    final bg = asStr(prof['bg']);
    final bio = asStr(prof['bio'] ?? user['bio']);
    final tags = asStrList(prof['tags'] ?? user['tags']);
    final self = _isSelf || asBool(_profile['isSelf']);

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Column(
        children: [
          SizedBox(
            height: 160,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (bg.isNotEmpty)
                  Image.network(
                    Api.i.abs(bg),
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(
                      color: AppColors.brandDeep,
                    ),
                  )
                else
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF174F34), Color(0xFF2E9E63)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 12,
                  bottom: 12,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      UserAvatar(
                        name: widget.username,
                        avatar: asStrOrNull(user['avatar']),
                        size: 66,
                        ring: true,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.username,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 21,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                RolePill(
                                  role: asStr(user['role'], 'user'),
                                  isAdmin: asBool(user['isAdmin']),
                                ),
                                const SizedBox(width: 4),
                                MembershipPill(
                                  membership: asMap(user['membership']),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '游戏 ID · ${asStr(user['mcName'], '未绑定')}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: cs.surface,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bio.isEmpty ? '这个人很神秘，什么都没写。' : bio,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 12,
                    height: 1.55,
                  ),
                ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children:
                        tags.take(6).map((t) => Pill(text: t)).toList(),
                  ),
                ],
                if (self)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const EditProfilePage()),
                        ).then((_) => _load()),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('编辑我的资料'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context) {
    if (_isSelf) return const SizedBox.shrink();
    final user = asMap(_profile['user']);
    final relation = asStr(_profile['relation']);
    final isFriend = relation == 'friend' || asBool(_space['isFriend']);
    final blocked = relation == 'blocked';
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: blocked ? null : () => _openChat(asInt(user['id'])),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
            label: const Text('私信'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _following ? _follow : _follow,
            icon: Icon(
              _following
                  ? Icons.check_rounded
                  : Icons.person_add_alt_1_rounded,
              size: 17,
            ),
            label: Text(_following ? '已关注' : '关注'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: blocked ? _block : (isFriend ? null : _addFriend),
            icon: Icon(
              blocked ? Icons.person_off_outlined : Icons.people_outline,
              size: 17,
            ),
            label: Text(blocked ? '解除屏蔽' : (isFriend ? '已好友' : '加好友')),
          ),
        ),
      ],
    );
  }

  Future<void> _openChat(int userId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatPage(userId: userId)),
    );
  }

  Widget _stats(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tier = asMap(_space['tier']);
    final cells = <List<String>>[
      ['${asInt(_space['followers'])}', '粉丝'],
      ['${asInt(_space['following'])}', '关注'],
      ['${fmtNumber(_space['views'])}', '浏览'],
      ['${fmtNumber(_space['likesReceived'])}', '获赞'],
      ['${asInt(_space['guestbookCount'])}', '留言'],
    ];
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
      child: Column(
        children: [
          Row(
            children: cells
                .map(
                  (c) => Expanded(
                    child: Column(
                      children: [
                        Text(
                          c[0],
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          c[1],
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          if (tier.isNotEmpty) ...[
            const SizedBox(height: 10),
            TierPill(tier: tier, showScore: true),
          ],
        ],
      ),
    );
  }

  Widget _gameCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final player = asMap(_profile['player']);
    final hidden = asMap(_profile['hidden']);
    if (player.isEmpty) return const SizedBox.shrink();
    if (asBool(hidden['stats'])) {
      return AppCard(
        child: Row(
          children: [
            Icon(Icons.lock_outline_rounded,
                color: cs.onSurfaceVariant, size: 18),
            const SizedBox(width: 8),
            Text(
              '对方设置了游戏数据仅好友可见',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
      );
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sports_esports_rounded,
                  color: AppColors.brand, size: 18),
              const SizedBox(width: 6),
              Text(
                '游戏数据',
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              if (asBool(player['online']))
                const Pill(text: '在线', color: AppColors.brand)
              else
                const Pill(text: '离线', color: Colors.grey),
              const Spacer(),
              if (asBool(player['banned']))
                const Pill(text: '封禁中', color: AppColors.danger),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _gameStat(context, '等级', 'Lv.${asInt(player['level'])}'),
              ),
              Expanded(
                child: _gameStat(context, '时长',
                    '${asDouble(player['playtimeHours']).toStringAsFixed(1)}h'),
              ),
              Expanded(
                child: _gameStat(context, '挖掘',
                    fmtNumber(player['blocksMined'])),
              ),
              Expanded(
                child: _gameStat(context, '死亡', '${asInt(player['deaths'])}'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _gameStat(BuildContext context, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 9.5),
        ),
      ],
    );
  }

  List<Widget> _activity(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = <Map<String, dynamic>>[];
    for (final t in asList(_space['threads'])) {
      items.add({
        'at': t['at'],
        'kind': '发帖',
        'text': asStr(t['title']),
        'id': asInt(t['id']),
      });
    }
    for (final r in asList(_space['replies'])) {
      items.add({
        'at': r['at'],
        'kind': '回帖',
        'text': asStr(r['excerpt']),
        'id': asInt(r['threadId']),
      });
    }
    items.sort((a, b) => asInt(b['at']).compareTo(asInt(a['at'])));
    if (items.isEmpty) {
      return [
        const EmptyView(
          text: '还没有动态',
          icon: Icons.dynamic_feed_outlined,
        ),
      ];
    }
    return items.take(12).map((it) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AppCard(
          padding: const EdgeInsets.all(12),
          onTap: it['id'] == 0
              ? null
              : () => Nav.to('/forum/thread/${asInt(it['id'])}'),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.brand.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  asStr(it['kind']).substring(0, 1),
                  style: const TextStyle(
                    color: AppColors.brand,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asStr(it['text']).isEmpty ? '（无内容）' : asStr(it['text']),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${asStr(it['kind'])} · ${fmtAgo(it['at'])}',
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
        ),
      );
    }).toList();
  }

  List<Widget> _threads(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final threads = asList(_space['threads']);
    if (threads.isEmpty) {
      return [
        const EmptyView(
          text: '还没有发过帖子',
          icon: Icons.edit_note_rounded,
        ),
      ];
    }
    return threads.map((t) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AppCard(
          padding: const EdgeInsets.all(12),
          onTap: () => Nav.to('/forum/thread/${asInt(t['id'])}'),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asStr(t['title'], '无标题'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${asInt(t['replies'])} 回复 · ${asInt(t['views'])} 浏览 · ${fmtAgo(t['at'])}',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 18),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _guestbookSection(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_state.isLoggedIn)
          AppCard(
            child: Column(
              children: [
                if (_replyTo != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '回复 #$_replyTo',
                        style: const TextStyle(
                          color: AppColors.brand,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _gb,
                        maxLength: 500,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: '留个言吧，支持 @昵称 提及',
                          isDense: true,
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filled(
                      onPressed: _sendingGb ? null : _sendGb,
                      icon: _sendingGb
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          AppCard(
            child: Text(
              '登录后可以留言',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
          ),
        const SizedBox(height: 10),
        if (_guestbook.isEmpty)
          const EmptyView(
            text: '还没有人留言，来抢沙发吧',
            icon: Icons.chat_bubble_outline_rounded,
          )
        else
          ..._guestbook.map((g) {
            final author = asMap(g['author']);
            final mine = asInt(author['id']) == _state.userId;
            final canDelete = mine || _isSelf;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UserAvatar(
                      name: asStr(author['username']),
                      avatar: asStrOrNull(author['avatar']),
                      size: 32,
                      onTap: () => Nav.to(
                        '/u/${Uri.encodeComponent(asStr(author['username']))}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                asStr(author['username'], '玩家'),
                                style: TextStyle(
                                  color: cs.onSurface,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                fmtAgo(g['at']),
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 9.5,
                                ),
                              ),
                              if (asInt(g['replyTo']) > 0) ...[
                                const SizedBox(width: 4),
                                const Pill(
                                    text: '回复', color: AppColors.teal),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            asStr(g['body']),
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 12,
                              height: 1.55,
                            ),
                          ),
                          Row(
                            children: [
                              if (_state.isLoggedIn && !mine)
                                TextButton(
                                  onPressed: () {
                                    setState(() => _replyTo = asInt(g['id']));
                                    _gb.text = '@${asStr(author['username'])} ';
                                  },
                                  child: const Text('回复'),
                                ),
                              if (canDelete)
                                TextButton(
                                  onPressed: () => _deleteGb(asInt(g['id'])),
                                  child: const Text('删除'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
