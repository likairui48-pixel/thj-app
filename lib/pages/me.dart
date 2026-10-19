import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/meta.dart';
import '../core/nav.dart';
import '../core/state.dart';
import '../core/ui.dart';
import '../core/update_ui.dart';
import 'bind.dart';
import 'edit_profile.dart';
import 'friends.dart';
import 'login.dart';
import 'membership.dart';
import 'settings.dart';
import 'shop.dart';

class MePage extends StatefulWidget {
  const MePage({super.key});

  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  final _state = AppState.i;
  bool _loading = false;
  Map<String, dynamic> _myRank = <String, dynamic>{};
  Map<String, dynamic> _member = <String, dynamic>{};
  Map<String, dynamic> _space = <String, dynamic>{};
  List<Map<String, dynamic>> _following = const [];
  List<Map<String, dynamic>> _followers = const [];
  List<Map<String, dynamic>> _collections = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_state.isLoggedIn) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        Api.i.myRank(),
        Api.i.membership(),
        Api.i.space(_state.username),
        Api.i.following(),
        Api.i.followers(),
        Api.i.collections(),
      ]);
      if (!mounted) return;
      setState(() {
        _myRank = results[0];
        _member = results[1];
        _space = results[2];
        _following = asList(results[3]['users']);
        _followers = asList(results[4]['users']);
        _collections = asList(results[5]['items']);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _login() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
    await _state.refreshMe();
    _load();
  }

  Future<void> _logout() async {
    final ok = await showConfirm(
      context,
      title: '退出登录',
      message: '退出后需要重新输入密码才能看消息和个人数据。',
      okText: '退出',
      danger: true,
    );
    if (!ok) return;
    await _state.logout();
    if (mounted) setState(() {});
  }

  Future<void> _checkUpdate() async {
    await _state.checkUpdate();
    if (!mounted) return;
    if (_state.update == null) {
      showToast(context, '暂时无法检查更新，请稍后再试', error: true);
    } else if (!_state.update!.hasNewer) {
      showToast(context, '已是最新版本 ${AppMeta.version}');
    } else {
      await showUpdateDialog(context, _state.update!);
    }
  }

  void _open(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    if (!_state.isLoggedIn) {
      return AppPage(
        title: '我的',
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.brandDeep, AppColors.brand, AppColors.teal],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.person_outline_rounded,
                      color: Colors.white, size: 38),
                  const SizedBox(height: 12),
                  const Text(
                    '还没有登录',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    '登录后绑定游戏 ID，解锁段位、私信、活动、订单',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.brandDeep,
                          ),
                          onPressed: _login,
                          child: const Text('登录'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                          ),
                          onPressed: () => _open(
                            const LoginPage(startRegister: true),
                          ),
                          child: const Text('注册'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                children: [
                  _guestAction(
                    Icons.forum_rounded,
                    '社区论坛',
                    '看帖、发帖、晒建筑',
                    () => Nav.tab('community'),
                  ),
                  const Divider(),
                  _guestAction(
                    Icons.leaderboard_rounded,
                    '玩家排行',
                    '段位 / 时长 / 等级三榜',
                    () => Nav.tab('rank'),
                  ),
                  const Divider(),
                  _guestAction(
                    Icons.celebration_rounded,
                    '活动中心',
                    '签到、相册、商城、SMP',
                    () => Nav.to('/festival'),
                  ),
                  const Divider(),
                  _guestAction(
                    Icons.settings_outlined,
                    '设置',
                    '主题、通知、更新',
                    () => _open(const SettingsPage()),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final user = _state.user!;
    final name = _state.username;
    final mcName = _state.mcName;
    final bio = asStr(user['bio']);
    final bg = asStr(user['profileBg'] ??
        user['bg'] ??
        asMap(user['profile'])['bg'] ??
        asMap(user['profile'])['background']);
    final tags = asStrList(user['tags']);
    final detail = asMap(_myRank['detail']);
    final tier = asMap(detail['tier']);
    final position = asInt(detail['position']);
    final memberActive = asBool(_member['active']);
    final memberTier = asMap(_member['tier']);
    final threads = asList(_space['threads']);

    return AppPage(
      title: null,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
          children: [
            Row(
              children: [
                const Text(
                  '我的',
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _open(const SettingsPage()),
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _profileHeader(context,
                user: user,
                name: name,
                mcName: mcName,
                bio: bio,
                bg: bg,
                tags: tags),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _miniStat(
                    context,
                    '段位',
                    tier.isEmpty ? '—' : asStr(tier['label']),
                    sub: tier.isEmpty ? '未绑定' : '${asInt(tier['score'])} 分',
                    color: parseColor(asStr(tier['color'])),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _miniStat(context, '关注', '${_following.length}',
                      sub: '人'),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _miniStat(context, '粉丝', '${_followers.length}',
                      sub: '人'),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _miniStat(context, '收藏', '${_collections.length}',
                      sub: '条'),
                ),
              ],
            ),
            SectionTitle(
              title: '我的段位',
              trailing: TextButton(
                onPressed: () => Nav.tab('rank'),
                child: const Text('排行榜'),
              ),
            ),
            _rankCard(context, detail, tier, position),
            SectionTitle(
              title: '会员与订单',
              trailing: TextButton(
                onPressed: () => _open(const MembershipPage()),
                child: const Text('会员中心'),
              ),
            ),
            AppCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: (memberActive
                                  ? parseColor(asStr(memberTier['color']))
                                  : Colors.grey)
                              .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          Icons.workspace_premium_rounded,
                          color: memberActive
                              ? parseColor(asStr(memberTier['color']))
                              : Colors.grey,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              memberActive
                                  ? '${asStr(memberTier['label'], '会员')} · 生效中'
                                  : '普通玩家',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              memberActive
                                  ? (asBool(_member['permanent'])
                                      ? '永久有效'
                                      : '有效期至 ${fmtDate(_member['until'])}')
                                  : '开通会员解锁游戏内权益',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!memberActive)
                        FilledButton(
                          onPressed: () => _open(const MembershipPage()),
                          child: const Text('开通'),
                        ),
                    ],
                  ),
                  const Divider(height: 20),
                  _entry(
                    Icons.receipt_long_outlined,
                    '我的订单',
                    '查看订单、卡密、物流',
                    () => _open(const OrdersPage()),
                  ),
                  _entry(
                    Icons.confirmation_number_outlined,
                    '兑换码',
                    '激活卡密 / 活动奖励',
                    () => _open(const RedeemPage()),
                  ),
                ],
              ),
            ),
            SectionTitle(
              title: '我的帖子',
              sub: threads.isEmpty ? null : '${threads.length} 篇',
              trailing: TextButton(
                onPressed: () => Nav.tab('community'),
                child: const Text('去社区'),
              ),
            ),
            if (threads.isEmpty)
              const EmptyView(
                text: '还没发过帖子，去社区聊聊吧',
                icon: Icons.edit_note_rounded,
              )
            else
              ...threads.take(4).map(
                    (t) => Padding(
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
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${asInt(t['replies'])} 回复 · ${fmtAgo(t['at'])}',
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
                            const Icon(Icons.chevron_right_rounded, size: 19),
                          ],
                        ),
                      ),
                    ),
                  ),
            SectionTitle(title: '账号与设置'),
            AppCard(
              child: Column(
                children: [
                  _entry(Icons.edit_outlined, '编辑资料',
                      '头像、背景、签名、标签', () => _open(const EditProfilePage())),
                  _entry(Icons.link_rounded, '绑定游戏账号',
                      mcName.isEmpty ? '未绑定' : '已绑定 $mcName',
                      () => _open(const BindPage())),
                  _entry(Icons.people_outline_rounded, '好友与关注',
                      '好友、申请、关注、粉丝', () => _open(const FriendsPage())),
                  _entry(Icons.lock_outline_rounded, '隐私设置',
                      '谁能看我的资料、加好友、私信', () => _open(const PrivacyPage())),
                  _entry(Icons.notifications_none_rounded, '通知设置',
                      '游戏内提醒与消息偏好', () => _open(const NotifySettingsPage())),
                  _entry(Icons.system_update_alt_rounded, '检查更新',
                      '当前版本 ${AppMeta.version}', _checkUpdate),
                  _entry(Icons.info_outline_rounded, '关于同禾境',
                      '服务器信息、玩家群、开源说明', _about),
                  if (_state.isStaff)
                    _entry(Icons.admin_panel_settings_outlined, '管理后台',
                        '在浏览器打开站点后台', () => Nav.to('/admin')),
                  const Divider(height: 8),
                  _entry(Icons.logout_rounded, '退出登录', null, _logout,
                      danger: true),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                '同禾境 v${AppMeta.version} (${AppMeta.versionCode})',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 10.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileHeader(
    BuildContext context, {
    required Map<String, dynamic> user,
    required String name,
    required String mcName,
    required String bio,
    required String bg,
    required List<String> tags,
  }) {
    final cs = Theme.of(context).colorScheme;
    final hasBg = bg.isNotEmpty;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            height: 174,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasBg)
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
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF174F34), Color(0xFF2E9E63)],
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
                        Colors.black.withOpacity(0.68),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 12,
                  bottom: 14,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      UserAvatar(
                        name: name,
                        avatar: asStrOrNull(user['avatar']),
                        size: 64,
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
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
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
                              mcName.isEmpty ? '未绑定游戏 ID' : '游戏 ID · $mcName',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.18),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _open(const EditProfilePage()),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (bio.isNotEmpty || tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (bio.isNotEmpty)
                    Text(
                      bio,
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
                      children: tags
                          .take(6)
                          .map((t) => Pill(text: t, color: AppColors.teal))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _miniStat(
    BuildContext context,
    String label,
    String value, {
    String? sub,
    Color? color,
  }) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color ?? cs.onSurface,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub == null ? label : '$label $sub',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankCard(
    BuildContext context,
    Map<String, dynamic> detail,
    Map<String, dynamic> tier,
    int position,
  ) {
    final cs = Theme.of(context).colorScheme;
    if (detail.isEmpty || tier.isEmpty) {
      return const EmptyView(
        text: '绑定游戏账号后，这里会显示你的段位分和排名',
        icon: Icons.leaderboard_outlined,
      );
    }
    final color = parseColor(asStr(tier['color']));
    final score = asInt(detail['score']);
    final next = asMap(tier['next']);
    final parts = asMap(asMap(detail['components'])['parts']);
    final labels = <String, String>{
      'playtime': '时长',
      'recency': '活跃',
      'sessions': '上场',
      'placed': '放置',
      'mined': '挖掘',
      'crafted': '合成',
      'advances': '成就',
      'forum': '论坛',
      'likes': '获赞',
      'chat': '聊天',
      'friends': '好友',
      'economy': '经济',
    };
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withOpacity(0.35)),
                ),
                child: Text(
                  asStr(tier['key'], 'C'),
                  style: TextStyle(
                    color: color,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${asStr(tier['label'])} · $score 分',
                      style: TextStyle(
                        color: color,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '全服第 $position / ${asInt(detail['total'])} 名'
                      '${next.isEmpty ? ' · 已达最高段位' : ' · 距 ${asStr(next['label'])} 还差 ${asInt(tier['toNext'])} 分'}',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () => Nav.tab('rank'),
                child: const Text('详情'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (score / 1000).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          if (parts.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...parts.entries.take(5).map((e) {
              final p = asMap(e.value);
              final got = asDouble(p['got']);
              final max = asDouble(p['max'], 1);
              return Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  children: [
                    SizedBox(
                      width: 38,
                      child: Text(
                        labels[e.key] ?? e.key,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: (got / max).clamp(0.0, 1.0),
                          minHeight: 5,
                          backgroundColor: cs.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation(
                            color.withOpacity(0.75),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      '${got.toStringAsFixed(0)}/${max.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _entry(
    IconData icon,
    String title,
    String? sub,
    VoidCallback? onTap, {
    bool danger = false,
  }) {
    return ActionTile(
      icon: icon,
      title: title,
      sub: sub,
      color: danger ? AppColors.danger : null,
      onTap: onTap,
      trailing: danger
          ? null
          : const Icon(Icons.chevron_right_rounded, size: 20),
    );
  }

  Widget _guestAction(
    IconData icon,
    String title,
    String sub,
    VoidCallback onTap,
  ) {
    return ActionTile(
      icon: icon,
      title: title,
      sub: sub,
      onTap: onTap,
    );
  }

  Future<void> _about() async {
    showAboutDialog(
      context: context,
      applicationName: AppMeta.appName,
      applicationVersion: '${AppMeta.version} (${AppMeta.versionCode})',
      applicationLegalese: '同禾境 · 与方块世界同行',
      children: [
        const SizedBox(height: 8),
        Text(
          '服务器：${_state.serverAddress}\n玩家群：${_state.qqGroup}\n\n'
          '这是一个由社区驱动的 Minecraft 服务器客户端。所有数据来自站点接口，'
          'App 只是更顺手的入口。',
          style: const TextStyle(fontSize: 12, height: 1.6),
        ),
      ],
    );
  }
}
