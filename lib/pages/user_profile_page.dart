import 'dart:async';

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/api.dart';
import '../core/store.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import 'chat_page.dart';
import 'edit_profile_page.dart';
import 'login_page.dart';
import 'player_page.dart';

/// ============================================================
///  个人主页（原生）
///  - 看别人：头像 / 背景 / 签名 / 标签 / 统计 / 帖子 / 加好友 / 发私信
///  - 看自己：多一个「编辑资料」入口
///  - 隐私受限时按服务端返回的 hidden/restricted 隐藏对应区块
/// ============================================================
class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key, required this.username});

  final String username;

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  ProfileData? _p;
  SpaceData? _space;
  bool _loading = true;
  String? _err;
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
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final j = await Api.i.profile(widget.username);
      final p = ProfileData.fromJson(j);
      SpaceData? sp;
      if (!p.restricted) {
        try {
          sp = SpaceData.fromJson(await Api.i.space(widget.username));
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _p = p;
        _space = sp;
        _loading = false;
        _err = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = e is ApiError ? e.message : e.toString();
      });
    }
  }

  Future<void> _chat() async {
    final p = _p;
    if (p == null) return;
    if (!await requireLogin(context, reason: '登录后才能发私信')) return;
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatPage(userId: p.user.id, peerName: p.user.display)));
    _load(silent: true);
  }

  Future<void> _addFriend() async {
    final p = _p;
    if (p == null) return;
    if (!await requireLogin(context, reason: '登录后才能加好友')) return;
    try {
      await Api.i.friendRequest(p.user.id);
      _toast('已发送好友申请，对方同意后就能聊天了');
      _load(silent: true);
    } catch (e) {
      _toast(e is ApiError ? e.message : '申请失败');
    }
  }

  Future<void> _unblock() async {
    final p = _p;
    if (p == null) return;
    try {
      await Api.i.friendUnblock(p.user.id);
      _toast('已解除拉黑');
      _load(silent: true);
    } catch (e) {
      _toast(e is ApiError ? e.message : '操作失败');
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
          title: Text(widget.username),
          actions: [
            if (_p != null && !_p!.restricted)
              GlassIconButton(
                icon: Icons.refresh_rounded,
                size: 38,
                tooltip: '刷新',
                onTap: () => _load(),
              ),
            const SizedBox(width: 10),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => _load(silent: true),
          child: _content(t),
        ),
      ),
    );
  }

  Widget _content(GlassTokens t) {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          GlassSkeleton(height: 150, radius: 20),
          SizedBox(height: 12),
          GlassSkeleton(height: 60, radius: 16),
          SizedBox(height: 12),
          GlassSkeleton(height: 60, radius: 16),
        ],
      );
    }
    if (_err != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [ErrorPanel(message: _err!, onRetry: _load)],
      );
    }
    final p = _p!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 100),
      children: [
        _header(p, t),
        const SizedBox(height: 12),
        if (p.restricted) _restrictedCard(p, t) else ..._fullBody(p, t),
      ],
    );
  }

  Widget _header(ProfileData p, GlassTokens t) {
    final bg = p.bg != null && p.bg!.isNotEmpty ? Api.i.abs(p.bg!) : null;
    final avatarUrl = p.user.avatarUrl;
    return GlassPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // 背景横幅
          Container(
            height: 118,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(R.card)),
              gradient: bg == null
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2E9E63), Color(0xFF2FA6A0)],
                    )
                  : null,
              image: bg == null
                  ? null
                  : DecorationImage(image: NetworkImage(bg), fit: BoxFit.cover),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -34),
            child: Column(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.fillStrong,
                    border: Border.all(color: t.bgBottom, width: 3),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: avatarUrl == null
                      ? Center(
                          child: Text(
                            p.user.username.isEmpty
                                ? '?'
                                : p.user.username.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: t.text2),
                          ),
                        )
                      : Image.network(avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (a, b, s) => Icon(
                              Icons.person_rounded,
                              size: 30,
                              color: t.text3)),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(p.user.username,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: t.text)),
                    if (p.user.mcName != null) ...[
                      const SizedBox(width: 8),
                      GlassChip(label: '游戏 ${p.user.mcName}', icon: Icons.sports_esports_rounded),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  children: [
                    if (p.user.role != 'user')
                      GlassChip(
                        label: p.user.role == 'owner'
                            ? '站长'
                            : (p.user.role == 'mod' ? '版主' : '管理员'),
                        active: true,
                        color: t.accent,
                      ),
                    if (p.user.membership != null)
                      GlassChip(
                          label: p.user.membership!.label,
                          color: Color(p.user.membership!.color)),
                    if (p.isFriend) const GlassChip(label: '好友'),
                    if (p.hiddenOnline || !p.user.online)
                      const SizedBox.shrink()
                    else
                      GlassChip(label: '在线', active: true),
                  ],
                ),
                if (p.bio.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Text(
                      p.bio,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13, color: t.text2, height: 1.55),
                    ),
                  ),
                ],
                if (p.tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      runSpacing: 6,
                      children: p.tags
                          .map((x) => GlassChip(label: '#$x'))
                          .toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _actions(p, t),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(ProfileData p, GlassTokens t) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        if (p.isSelf)
          GlassButton(
            label: '编辑资料',
            expand: false,
            height: 38,
            primary: true,
            icon: Icons.edit_rounded,
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const EditProfilePage()));
              _load(silent: true);
            },
          ),
        if (!p.isSelf)
          GlassButton(
            label: '发私信',
            expand: false,
            height: 38,
            primary: true,
            icon: Icons.chat_bubble_outline_rounded,
            onTap: _chat,
          ),
        if (!p.isSelf && !p.isFriend && !p.hasPending && p.canFriendRequest)
          GlassButton(
            label: '加好友',
            expand: false,
            height: 38,
            icon: Icons.person_add_alt_1_rounded,
            onTap: _addFriend,
          ),
        if (p.hasPending)
          GlassChip(label: '好友申请已发出', icon: Icons.hourglass_top_rounded),
        if (p.relation == 'blocked')
          GlassButton(
            label: '解除拉黑',
            expand: false,
            height: 38,
            icon: Icons.lock_open_rounded,
            onTap: _unblock,
          ),
        if (p.user.mcName != null && !p.hiddenCard)
          GlassButton(
            label: '游戏名片',
            expand: false,
            height: 38,
            icon: Icons.badge_outlined,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PlayerPage(name: p.user.mcName!))),
          ),
      ],
    );
  }

  Widget _restrictedCard(ProfileData p, GlassTokens t) {
    final reason = p.reason == 'friends' ? '对方设置了「仅好友可见」' : '对方设置了隐私保护';
    return Column(
      children: [
        GlassPanel(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Icon(Icons.lock_outline_rounded, size: 30, color: t.text3),
              const SizedBox(height: 10),
              Text(reason,
                  style: TextStyle(fontSize: 13.5, color: t.text2)),
              const SizedBox(height: 6),
              Text('加为好友后即可查看完整主页',
                  style: TextStyle(fontSize: 12, color: t.text3)),
              if (p.canFriendRequest) ...[
                const SizedBox(height: 14),
                GlassButton(
                    label: '加好友',
                    icon: Icons.person_add_alt_1_rounded,
                    onTap: _addFriend),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _fullBody(ProfileData p, GlassTokens t) {
    final sp = _space;
    return [
      Row(
        children: [
          Expanded(
            child: StatTile(
                label: '好友',
                value: '${p.friendCount}',
                icon: Icons.people_alt_rounded),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StatTile(
                label: '主页浏览',
                value: '${sp?.views ?? 0}',
                icon: Icons.visibility_rounded),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StatTile(
                label: '获赞',
                value: '${sp?.likesReceived ?? 0}',
                icon: Icons.favorite_rounded),
          ),
        ],
      ),
      if (p.player != null && !p.hiddenStats) ...[
        const SectionTitle(title: '游戏数据'),
        GlassPanel(
          child: Column(
            children: [
              InfoRow(label: '等级', value: '${p.player!.level}'),
              InfoRow(label: '游戏时长', value: hoursText(p.player!.hours)),
              InfoRow(label: '挖掘方块', value: shortNum(p.player!.blocksMined)),
              InfoRow(label: '死亡次数', value: '${p.player!.deaths}'),
              InfoRow(label: '击杀生物', value: '${p.player!.mobKills}'),
              if (p.player!.rank > 0)
                InfoRow(
                    label: '段位排名',
                    value: '第 ${p.player!.rank} 名（共 ${p.player!.total}）'),
            ],
          ),
        ),
      ],
      if (p.hiddenStats && p.player == null)
        GlassPanel(
          child: Row(
            children: [
              Icon(Icons.visibility_off_rounded, size: 18, color: t.text3),
              const SizedBox(width: 8),
              Expanded(
                child: Text('对方把游戏数据设为不公开',
                    style: TextStyle(fontSize: 12.5, color: t.text3)),
              ),
            ],
          ),
        ),
      if (sp != null && sp.threads.isNotEmpty && !p.hiddenPosts) ...[
        const SectionTitle(title: 'TA 的帖子'),
        ...sp.threads.take(5).map((th) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassPanel(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.article_outlined, size: 16, color: t.text3),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        asStr(th['title'], '帖子'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13.5, color: t.text),
                      ),
                    ),
                    Text('${asInt(th['reply_count'])} 回复',
                        style: TextStyle(fontSize: 11, color: t.text3)),
                  ],
                ),
              ),
            )),
      ],
      const SizedBox(height: 8),
      GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.forum_outlined, size: 17, color: t.text3),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '留言板与完整动态已移到网页版（原生留言板下一版做）',
                style: TextStyle(fontSize: 12, color: t.text3),
              ),
            ),
          ],
        ),
      ),
    ];
  }
}
