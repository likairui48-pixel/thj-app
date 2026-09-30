import 'dart:async';

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/api.dart';
import '../core/img.dart';
import '../core/realtime.dart';
import '../core/store.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import 'user_profile_page.dart';

/// ============================================================
///  聊天页（原生，不跳网页）
///
///  能力：历史分页 / 实时收发 / 图片消息 / 正在输入 / 已读回执 /
///       撤回（2 分钟内）/ 置顶 / 免打扰 / 删除会话
///
///  实时策略：优先走长连接（Realtime）；一旦长连接不可用，
///  自动降级为 3 秒轮询拉取最新一页（界面完全一样，只是慢一点），
///  所以「收不到消息」这件事不会发生。
/// ============================================================
class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.userId,
    this.peerName,
  });

  final int userId;
  final String? peerName;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _msgs = <DmMessage>[];
  final _scroll = ScrollController();
  final _input = TextEditingController();
  final _focus = FocusNode();

  UserLite? _peer;
  DmMeta _meta = DmMeta();
  bool _loading = true;
  bool _loadingMore = false;
  bool _sending = false;
  bool _hasMore = true;
  String? _err;

  DateTime? _peerTypingAt;
  bool _peerRead = false;
  Timer? _tick;
  Timer? _poll;
  StreamSubscription<RtPing>? _pingSub;
  StreamSubscription<RtEvent>? _rtSub;

  @override
  void initState() {
    super.initState();
    _pingSub = RtBus.i.stream.listen(_onPing);
    _rtSub = Realtime.i.stream.listen(_onRt);
    _load();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_peerTypingAt != null &&
          DateTime.now().difference(_peerTypingAt!).inSeconds > 3) {
        setState(() => _peerTypingAt = null);
      }
    });
    // 长连接不可用时兜底轮询
    _poll = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      if (!Realtime.i.connected) _fetchLatest(silent: true);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _poll?.cancel();
    _pingSub?.cancel();
    _rtSub?.cancel();
    _scroll.dispose();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ---------------- 数据 ----------------

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final j = await Api.i.dmHistory(widget.userId, limit: 50);
      final list = asList(j['messages']).map(DmMessage.fromJson).toList();
      if (!mounted) return;
      setState(() {
        _peer = UserLite.fromJson(asMap(j['user']));
        _msgs
          ..clear()
          ..addAll(list);
        _hasMore = list.length >= 50;
        _loading = false;
      });
      _jumpBottom();
      _markRead();
      _loadMeta();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = e is ApiError ? e.message : e.toString();
      });
    }
  }

  Future<void> _loadMeta() async {
    try {
      final j = await Api.i.dmMeta(widget.userId);
      if (!mounted) return;
      setState(() => _meta = DmMeta.fromJson(j));
    } catch (_) {}
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _msgs.isEmpty) return;
    setState(() => _loadingMore = true);
    final oldest = _msgs.first.id;
    try {
      final j =
          await Api.i.dmHistory(widget.userId, before: oldest, limit: 50);
      final list = asList(j['messages']).map(DmMessage.fromJson).toList();
      if (!mounted) return;
      setState(() {
        _msgs.insertAll(0, list);
        _hasMore = list.length >= 50;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      _toast(e is ApiError ? e.message : '加载失败');
    }
  }

  /// 拉最新一页并合并（轮询 / 收到推送时用）
  Future<void> _fetchLatest({bool silent = false}) async {
    try {
      final j = await Api.i.dmHistory(widget.userId, limit: 30);
      if (!mounted) return;
      final list = asList(j['messages']).map(DmMessage.fromJson).toList();
      final added = _merge(list);
      if (added && _nearBottom) _jumpBottom();
      _markRead();
    } catch (e) {
      if (!silent && mounted) _toast(e is ApiError ? e.message : '刷新失败');
    }
  }

  /// 合并消息（按 id 去重）；返回是否有新增
  bool _merge(List<DmMessage> incoming) {
    var added = false;
    final byId = <int, DmMessage>{for (final m in _msgs) m.id: m};
    for (final m in incoming) {
      final old = byId[m.id];
      if (old == null) {
        // 服务端确认了我们的乐观消息（id 是负数）→ 用真 id 替换
        final idx = _msgs.indexWhere((x) =>
            x.pending &&
            x.mine &&
            x.body == m.body &&
            (x.image ?? '') == (m.image ?? ''));
        if (idx >= 0) {
          _msgs[idx] = m;
        } else {
          _msgs.add(m);
          added = true;
        }
      } else {
        // 已存在的消息只有「撤回」状态会变
        old.revoked = m.revoked;
      }
    }
    if (added || _msgs.any((m) => m.pending)) {
      _msgs.sort((a, b) => a.ts.compareTo(b.ts));
      setState(() {});
    }
    for (final m in incoming) {
      byId[m.id] = m;
    }
    return added;
  }

  Future<void> _markRead() async {
    try {
      await Api.i.dmRead(widget.userId);
      AppState.i.refreshUnread(silent: true);
    } catch (_) {}
  }

  void _jumpBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  bool get _nearBottom {
    if (!_scroll.hasClients) return true;
    return _scroll.position.maxScrollExtent - _scroll.position.pixels < 120;
  }

  // ---------------- 事件 ----------------

  void _onPing(RtPing p) {
    if (!mounted) return;
    if (p.tag == 'dm:${widget.userId}' || p.tag == 'login') {
      _fetchLatest(silent: true);
      _loadMeta();
      return;
    }
    if (p.tag.startsWith('dmRevoke:')) {
      _fetchLatest(silent: true);
      return;
    }
    if (p.tag == 'dmRead:${widget.userId}') {
      setState(() => _peerRead = true);
      return;
    }
    if (p.tag == 'dmTyping:${widget.userId}') {
      setState(() => _peerTypingAt = DateTime.now());
    }
  }

  /// 直接监听底层事件（RtBus 只带 tag，这里需要更多细节时用）
  void _onRt(RtEvent e) {
    if (!mounted) return;
    if (e.type == 'dmTyping' && asInt(e.data['from']) == widget.userId) {
      setState(() => _peerTypingAt = DateTime.now());
    }
    if (e.type == 'dm' && asInt(e.data['from']) == widget.userId) {
      // 消息体直接可用，省一次请求
      final m = DmMessage.fromJson(e.data);
      if (m.id > 0) {
        _merge(<DmMessage>[m]);
        _markRead();
        if (_nearBottom) _jumpBottom();
      }
    }
  }

  // ---------------- 发送 ----------------

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    _input.clear();
    await _push(text: text);
  }

  Future<void> _sendImage() async {
    if (_sending) return;
    try {
      final data = await Img.pickDataUrl(maxEdge: 1600, quality: 85);
      if (data == null) return;
      setState(() => _sending = true);
      final up = await Api.i.uploadImage(data);
      final url = asStr(up['url']);
      if (url.isEmpty) throw ApiError('上传失败，请重试');
      await _push(text: '', image: url);
    } catch (e) {
      _toast(e is ApiError ? e.message : '图片发送失败');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// 乐观插入 + 真发
  Future<void> _push({String text = '', String? image}) async {
    final tmp = DmMessage(
      id: -DateTime.now().millisecondsSinceEpoch,
      ts: DateTime.now().millisecondsSinceEpoch,
      from: AppState.i.me?.id ?? 0,
      body: text,
      mine: true,
      kind: image == null ? 'text' : 'image',
      image: image,
      pending: true,
    );
    setState(() {
      _msgs.add(tmp);
      _msgs.sort((a, b) => a.ts.compareTo(b.ts));
    });
    _jumpBottom();

    try {
      final r = await Api.i.dmSend(widget.userId, text: text, image: image);
      final real = DmMessage.fromJson(asMap(r['message']));
      if (!mounted) return;
      setState(() {
        final i = _msgs.indexWhere((m) => m.id == tmp.id);
        if (i >= 0) {
          _msgs[i] = real;
        } else {
          _msgs.add(real);
        }
        _msgs.sort((a, b) => a.ts.compareTo(b.ts));
      });
      _jumpBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final i = _msgs.indexWhere((m) => m.id == tmp.id);
        if (i >= 0) {
          _msgs[i].pending = false;
          _msgs[i].failed = true;
        }
      });
      _toast(e is ApiError ? e.message : '发送失败');
    }
  }

  void _retry(DmMessage m) {
    setState(() => _msgs.remove(m));
    _push(text: m.body, image: m.image);
  }

  // ---------------- 交互 ----------------

  Future<void> _showActions(DmMessage m) async {
    if (m.pending || m.failed) return;
    final canRevoke = m.mine &&
        !m.revoked &&
        DateTime.now().millisecondsSinceEpoch - m.ts < 120000;
    await GlassSheet.show(context, child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (m.body.isNotEmpty)
          _sheetItem(
            icon: Icons.copy_rounded,
            label: '复制文字',
            onTap: () {
              Navigator.pop(context);
              _toast('已复制');
            },
          ),
        if (m.isImage)
          _sheetItem(
            icon: Icons.download_rounded,
            label: '图片地址已复制到输入框',
            onTap: () {
              Navigator.pop(context);
              _input.text = m.imageUrl ?? '';
            },
          ),
        if (canRevoke)
          _sheetItem(
            icon: Icons.undo_rounded,
            label: '撤回这条消息（2 分钟内）',
            danger: true,
            onTap: () async {
              Navigator.pop(context);
              try {
                await Api.i.dmRevoke(widget.userId, m.id);
                setState(() => m.revoked = true);
                _fetchLatest(silent: true);
              } catch (e) {
                _toast(e is ApiError ? e.message : '撤回失败');
              }
            },
          ),
        if (!m.mine)
          _sheetItem(
            icon: Icons.person_rounded,
            label: '查看对方主页',
            onTap: () {
              Navigator.pop(context);
              if (_peer != null) _openProfile(_peer!.username);
            },
          ),
      ],
    ));
  }

  Widget _sheetItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final t = GlassTokens.of(context);
    return ListTile(
      leading: Icon(icon,
          size: 20, color: danger ? GlassTokens.danger : t.text2),
      title: Text(label,
          style: TextStyle(
              fontSize: 14, color: danger ? GlassTokens.danger : t.text)),
      onTap: onTap,
    );
  }

  Future<void> _openProfile(String username) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => UserProfilePage(username: username)),
    );
    _loadMeta();
  }

  void _menu(String action) async {
    switch (action) {
      case 'pin':
        try {
          final r = await Api.i.dmPin(widget.userId, value: !_meta.pinned);
          setState(() => _meta = DmMeta(
              pinned: asBool(r['pinned']),
              muted: _meta.muted,
              online: _meta.online));
          _toast(_meta.pinned ? '已置顶会话' : '已取消置顶');
        } catch (e) {
          _toast(e is ApiError ? e.message : '操作失败');
        }
        break;
      case 'mute':
        try {
          final r = await Api.i.dmMute(widget.userId, value: !_meta.muted);
          setState(() => _meta = DmMeta(
              pinned: _meta.pinned,
              muted: asBool(r['muted']),
              online: _meta.online));
          _toast(_meta.muted ? '已开启免打扰' : '已关闭免打扰');
        } catch (e) {
          _toast(e is ApiError ? e.message : '操作失败');
        }
        break;
      case 'profile':
        if (_peer != null) _openProfile(_peer!.username);
        break;
      case 'delete':
        final ok = await GlassDialog.confirm(
          context,
          title: '删除这个会话？',
          message: '聊天记录会从你的列表里移除（对方那边也会一起清空），不可恢复。',
          okLabel: '删除',
          danger: true,
        );
        if (ok == true) {
          try {
            await Api.i.dmDelete(widget.userId);
            if (mounted) Navigator.of(context).pop(true);
          } catch (e) {
            _toast(e is ApiError ? e.message : '删除失败');
          }
        }
        break;
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  // ---------------- 视图 ----------------

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    final title = _peer?.display ?? widget.peerName ?? '聊天';
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: t.text)),
                  Text(
                    _peerTypingAt != null
                        ? '对方正在输入…'
                        : (_meta.online
                            ? '在线'
                            : (_peer?.mcName != null
                                ? '游戏 ID ${_peer!.mcName}'
                                : '离线')),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: _peerTypingAt != null ? t.accent : t.text3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_meta.pinned
                ? Icons.push_pin_rounded
                : Icons.push_pin_outlined),
            tooltip: '置顶会话',
            onPressed: () => _menu('pin'),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: _menu,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'mute',
                child: Text(_meta.muted ? '取消免打扰' : '免打扰'),
              ),
              const PopupMenuItem(value: 'profile', child: Text('查看主页')),
              const PopupMenuItem(value: 'delete', child: Text('删除会话')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (!Realtime.i.connected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 14),
              color: GlassTokens.warn.withOpacity(0.14),
              child: Text(
                '实时连接不可用，正在用 3 秒轮询收消息',
                style: TextStyle(fontSize: 11, color: t.text2),
              ),
            ),
          Expanded(child: _bodyArea(t)),
          _inputBar(t),
        ],
      ),
    );
  }

  Widget _bodyArea(GlassTokens t) {
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List<Widget>.generate(
            6,
            (i) => const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: GlassSkeleton(height: 48, radius: 14),
            ),
          ),
        ),
      );
    }
    if (_err != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: ErrorPanel(message: _err!, onRetry: _load),
      );
    }
    if (_msgs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: EmptyHint(
            text: '还没有聊天记录，打个招呼吧 👋',
            icon: Icons.waving_hand_rounded),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels < 60 && _hasMore && !_loadingMore) _loadMore();
        return false;
      },
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        itemCount: _msgs.length + 1,
        itemBuilder: (ctx, i) {
          if (i == 0) {
            if (_loadingMore) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))),
              );
            }
            if (_hasMore) {
              return Center(
                child: TextButton(
                  onPressed: _loadMore,
                  child: Text('加载更早的消息',
                      style: TextStyle(fontSize: 12, color: t.text3)),
                ),
              );
            }
            return const SizedBox(height: 4);
          }
          final m = _msgs[i - 1];
          final prev = i - 2 >= 0 ? _msgs[i - 2] : null;
          final showTime = prev == null || m.ts - prev.ts > 5 * 60 * 1000;
          final isLast = i == _msgs.length;
          return Column(
            children: [
              if (showTime) _timeMark(m.ts, t),
              _bubble(m, isLast, t),
            ],
          );
        },
      ),
    );
  }

  Widget _timeMark(int ts, GlassTokens t) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    final now = DateTime.now();
    final sameDay =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final label = sameDay
        ? '$hh:$mm'
        : '${dt.month}-${dt.day} $hh:$mm';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(label,
          style: TextStyle(fontSize: 10.5, color: t.text3)),
    );
  }

  Widget _bubble(DmMessage m, bool isLast, GlassTokens t) {
    final align = m.mine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Row(
            mainAxisAlignment:
                m.mine ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!m.mine) ...[
                _miniAvatar(t),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: GestureDetector(
                  onTap: m.isImage ? () => _viewImage(m) : null,
                  onLongPress: () => _showActions(m),
                  child: Container(
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.68),
                    padding: m.isImage
                        ? const EdgeInsets.all(4)
                        : const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 9),
                    decoration: BoxDecoration(
                      color: m.mine
                          ? t.accent.withOpacity(0.18)
                          : t.fillStrong,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(m.mine ? 16 : 4),
                        bottomRight: Radius.circular(m.mine ? 4 : 16),
                      ),
                      border: Border.all(
                        color: m.mine
                            ? t.accent.withOpacity(0.35)
                            : t.stroke,
                      ),
                    ),
                    child: m.revoked
                        ? Text(
                            m.mine ? '你撤回了一条消息' : '对方撤回了一条消息',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontStyle: FontStyle.italic,
                                color: t.text3),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (m.isImage)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    m.imageUrl!,
                                    width: 200,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (c, w, p) => p == null
                                        ? w
                                        : Container(
                                            width: 200,
                                            height: 140,
                                            color: t.fill,
                                            child: const Center(
                                                child: SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                            strokeWidth: 2))),
                                          ),
                                    errorBuilder: (c, e, s) => Container(
                                      width: 200,
                                      height: 90,
                                      alignment: Alignment.center,
                                      color: t.fill,
                                      child: Text('图片加载失败',
                                          style: TextStyle(
                                              fontSize: 11, color: t.text3)),
                                    ),
                                  ),
                                ),
                              if (m.body.isNotEmpty)
                                Padding(
                                  padding: EdgeInsets.only(
                                      top: m.isImage ? 6 : 0),
                                  child: Text(
                                    m.body,
                                    style: TextStyle(
                                        fontSize: 14.5,
                                        height: 1.4,
                                        color: t.text),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(
                top: 3,
                left: m.mine ? 0 : 46,
                right: m.mine ? 4 : 0),
            child: _metaLine(m, isLast, t),
          ),
        ],
      ),
    );
  }

  Widget _metaLine(DmMessage m, bool isLast, GlassTokens t) {
    if (m.failed) {
      return GestureDetector(
        onTap: () => _retry(m),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 13, color: GlassTokens.danger),
            const SizedBox(width: 4),
            Text('发送失败，点我重试',
                style: TextStyle(fontSize: 10.5, color: GlassTokens.danger)),
          ],
        ),
      );
    }
    if (m.pending) {
      return Text('发送中…',
          style: TextStyle(fontSize: 10.5, color: t.text3));
    }
    if (m.mine && isLast && _peerRead) {
      return Text('已读', style: TextStyle(fontSize: 10.5, color: t.accent));
    }
    return const SizedBox(height: 2);
  }

  Widget _miniAvatar(GlassTokens t) {
    final url = _peer?.avatarUrl;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: t.fillStrong,
        border: Border.all(color: t.stroke),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? Center(
              child: Text(
                (_peer?.username ?? '?').substring(0, 1).toUpperCase(),
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: t.text2),
              ),
            )
          : Image.network(url, fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Icon(Icons.person_rounded,
                  size: 18, color: t.text3)),
    );
  }

  Widget _inputBar(GlassTokens t) {
    return Container(
      padding: EdgeInsets.only(
        left: 10,
        right: 10,
        top: 8,
        bottom: 8 + MediaQuery.of(context).padding.bottom * 0.4,
      ),
      decoration: BoxDecoration(
        color: t.bgBottom.withOpacity(0.55),
        border: Border(top: BorderSide(color: t.stroke)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            GlassIconButton(
              icon: Icons.add_photo_alternate_outlined,
              size: 40,
              tooltip: '发送图片',
              onTap: _sending ? null : _sendImage,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _input,
                focusNode: _focus,
                maxLines: 4,
                minLines: 1,
                maxLength: 500,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                onChanged: (v) {
                  if (v.isNotEmpty) Realtime.i.typing(widget.userId);
                },
                style: TextStyle(fontSize: 14.5, color: t.text),
                decoration: InputDecoration(
                  hintText: '说点什么…',
                  hintStyle: TextStyle(fontSize: 14, color: t.text3),
                  counterText: '',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
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
              icon: Icons.send_rounded,
              size: 40,
              tooltip: '发送',
              onTap: _send,
            ),
          ],
        ),
      ),
    );
  }

  void _viewImage(DmMessage m) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: Image.network(
              m.imageUrl!,
              fit: BoxFit.contain,
              errorBuilder: (c, e, s) => const Text('图片加载失败',
                  style: TextStyle(color: Colors.white70)),
            ),
          ),
        ),
      ),
    );
  }
}
