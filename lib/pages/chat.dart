import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/img.dart';
import '../core/nav.dart';
import '../core/realtime.dart';
import '../core/state.dart';
import '../core/ui.dart';
import 'login.dart';
import 'report.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, this.userId});

  final int? userId;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _state = AppState.i;
  final _text = TextEditingController();
  final _scroll = ScrollController();
  StreamSubscription<RtEvent>? _rtSub;
  Timer? _typingTimer;
  bool _loading = true;
  bool _sending = false;
  String? _err;
  List<Map<String, dynamic>> _msgs = const [];
  Map<String, dynamic> _peer = <String, dynamic>{};
  String _typing = '';
  bool _pinned = false;
  bool _muted = false;

  bool get _isWorld => widget.userId == null;
  int get _uid => widget.userId ?? 0;

  @override
  void initState() {
    super.initState();
    _load();
    _rtSub = Realtime.i.stream.listen(_onRt);
  }

  @override
  void dispose() {
    _rtSub?.cancel();
    _typingTimer?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!_state.isLoggedIn) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      if (_isWorld) {
        final j = await Api.i.chatRecent(limit: 100);
        if (!mounted) return;
        setState(() {
          _msgs = asList(j['messages']);
          _loading = false;
        });
      } else {
        final j = await Api.i.dmHistory(_uid, limit: 60);
        if (!mounted) return;
        setState(() {
          _peer = asMap(j['user']);
          _msgs = asList(j['messages']);
          _loading = false;
        });
        await Api.i.dmRead(_uid);
        _loadMeta();
      }
      _scrollBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMeta() async {
    try {
      final j = await Api.i.dmMeta(_uid);
      final meta = asMap(j['meta']);
      if (!mounted) return;
      setState(() {
        _pinned = asBool(meta['pinned']);
        _muted = asBool(meta['muted']);
        if (asMap(j['user']).isNotEmpty) _peer = asMap(j['user']);
      });
    } catch (_) {}
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onRt(RtEvent e) {
    if (!mounted) return;
    switch (e.type) {
      case 'chat':
        if (!_isWorld) return;
        if (_append({
          ...e.data,
          'player': e.data['player'],
          'body': e.data['message'] ?? e.data['body'],
        })) {
          _scrollBottom();
        }
        break;
      case 'dm':
        final from = asInt(e.data['from']);
        final to = asInt(e.data['to']);
        if (_isWorld || (from != _uid && to != _uid)) return;
        final mine = from == _state.userId;
        if (_append({...e.data, 'mine': mine})) {
          _scrollBottom();
          if (!mine) Api.i.dmRead(_uid);
        }
        break;
      case 'dmTyping':
        if (_isWorld || asInt(e.data['from']) != _uid) return;
        setState(() =>
            _typing = '${asStr(_peer['username'], '对方')} 正在输入…');
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _typing = '');
        });
        break;
      case 'dmRead':
        if (_isWorld || asInt(e.data['by']) != _uid) return;
        setState(() {
          for (final m in _msgs) {
            if (asBool(m['mine'])) m['read'] = true;
          }
        });
        break;
      case 'dmRevoke':
        if (_isWorld) return;
        final id = asInt(e.data['id']);
        setState(() {
          for (final m in _msgs) {
            if (asInt(m['id']) == id) {
              m['revoked'] = true;
              m['body'] = '';
            }
          }
        });
        break;
    }
  }

  bool _append(Map<String, dynamic> m) {
    final id = asInt(m['id']);
    if (id > 0 && _msgs.any((x) => asInt(x['id']) == id)) return false;
    setState(() => _msgs = [..._msgs, m]);
    return true;
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty || _sending) return;
    if (!_state.isLoggedIn) {
      await _login();
      return;
    }
    setState(() => _sending = true);
    try {
      if (_isWorld) {
        final j = await Api.i.chatSend(text);
        final m = asMap(j['message']);
        if (m.isNotEmpty) {
          _append({
            ...m,
            'player': asStr(m['player'], _state.mcName),
            'body': asStr(m['message'], text),
          });
        } else {
          _append({
            'id': DateTime.now().millisecondsSinceEpoch,
            'player': _state.mcName.isEmpty ? _state.username : _state.mcName,
            'body': text,
            'ts': DateTime.now().millisecondsSinceEpoch,
            'kind': 'web',
          });
        }
      } else {
        final j = await Api.i.dmSend(_uid, text: text);
        final m = asMap(j['message']);
        if (m.isNotEmpty) _append({...m, 'mine': true});
        await Api.i.dmRead(_uid);
      }
      _text.clear();
      _scrollBottom();
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendImage() async {
    if (_isWorld) {
      showToast(context, '图片只能私聊发送');
      return;
    }
    try {
      final d = await ImgPicker.one(maxWidth: 1600, quality: 82);
      if (d == null) return;
      setState(() => _sending = true);
      final up = await Api.i.uploadImage(d, kind: 'photo');
      final url = asStr(up['url']);
      if (url.isEmpty) throw Exception('上传失败');
      final j = await Api.i.dmSend(_uid, image: url);
      final m = asMap(j['message']);
      if (m.isNotEmpty) _append({...m, 'mine': true});
      _scrollBottom();
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _login() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
    if (mounted) _load();
  }

  Future<void> _messageMenu(Map<String, dynamic> m) async {
    final mine = asBool(m['mine']);
    final id = asInt(m['id']);
    final text = asStr(m['body']);
    final revoked = asBool(m['revoked']);
    if (revoked) return;
    await showAppSheet<void>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.copy_rounded),
            title: const Text('复制内容'),
            onTap: () {
              Clipboard.setData(ClipboardData(text: text));
              Navigator.pop(context);
              showToast(context, '已复制');
            },
          ),
          if (!_isWorld && mine && id > 0)
            ListTile(
              leading: const Icon(Icons.undo_rounded),
              title: const Text('撤回消息'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await Api.i.dmRevoke(_uid, id);
                  setState(() {
                    for (final x in _msgs) {
                      if (asInt(x['id']) == id) {
                        x['revoked'] = true;
                        x['body'] = '';
                      }
                    }
                  });
                } catch (e) {
                  if (mounted) showToast(context, e.toString(), error: true);
                }
              },
            ),
          if (!_isWorld)
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: const Text('查看对方主页'),
              onTap: () {
                Navigator.pop(context);
                Nav.to('/u/${Uri.encodeComponent(asStr(_peer['username']))}');
              },
            ),
          ListTile(
            leading: const Icon(Icons.flag_outlined, color: AppColors.danger),
            title: const Text('举报这条消息',
                style: TextStyle(color: AppColors.danger)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReportPage(
                    targetType: _isWorld ? 'chat' : 'user',
                    targetId: _isWorld
                        ? '$id'
                        : '${asInt(_peer['id'])}',
                    targetLabel: _isWorld
                        ? '聊天发言 · ${asStr(m['player'] ?? m['name'])}'
                        : '用户 ${asStr(_peer['username'])}',
                    detail: text.isEmpty ? '' : '引用消息：$text',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = _isWorld ? '世界频道' : asStr(_peer['username'], '私聊');
    return AppPage(
      title: title,
      actions: [
        if (!_isWorld) ...[
          IconButton(
            tooltip: _pinned ? '取消置顶' : '置顶',
            onPressed: () async {
              try {
                final j = await Api.i.dmPin(_uid, value: !_pinned);
                setState(() => _pinned = asBool(j['pinned'], !_pinned));
              } catch (e) {
                if (mounted) showToast(context, e.toString(), error: true);
              }
            },
            icon: Icon(_pinned ? Icons.push_pin : Icons.push_pin_outlined),
          ),
          IconButton(
            tooltip: _muted ? '取消免打扰' : '免打扰',
            onPressed: () async {
              try {
                final j = await Api.i.dmMute(_uid, value: !_muted);
                setState(() => _muted = asBool(j['muted'], !_muted));
              } catch (e) {
                if (mounted) showToast(context, e.toString(), error: true);
              }
            },
            icon: Icon(_muted
                ? Icons.volume_off_rounded
                : Icons.volume_up_outlined),
          ),
          IconButton(
            tooltip: '主页',
            onPressed: () =>
                Nav.to('/u/${Uri.encodeComponent(asStr(_peer['username']))}'),
            icon: const Icon(Icons.person_outline_rounded),
          ),
        ],
      ],
      child: !_state.isLoggedIn
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.forum_outlined,
                        color: AppColors.brand, size: 44),
                    const SizedBox(height: 12),
                    const Text('登录后才能看聊天和发消息'),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: _login,
                      child: const Text('去登录'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                if (_isWorld)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    color: AppColors.teal.withOpacity(0.08),
                    child: Text(
                      '世界频道与游戏内互通。绑定游戏 ID 后，手机发的话会出现在服务器聊天框。',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 10.5,
                        height: 1.5,
                      ),
                    ),
                  ),
                Expanded(
                  child: AsyncView(
                    loading: _loading,
                    error: _err,
                    onRetry: _load,
                    isEmpty: !_loading && _msgs.isEmpty,
                    emptyText: _isWorld ? '还没有人说话，来第一句' : '还没有聊天记录，打个招呼吧',
                    emptyIcon: Icons.chat_bubble_outline_rounded,
                    child: ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
                      itemCount: _msgs.length,
                      itemBuilder: (context, i) =>
                          _bubble(context, _msgs[i]),
                    ),
                  ),
                ),
                if (_typing.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 18, bottom: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _typing,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                  ),
                _composer(context),
              ],
            ),
    );
  }

  Widget _bubble(BuildContext context, Map<String, dynamic> m) {
    final cs = Theme.of(context).colorScheme;
    final mine = asBool(m['mine']) ||
        (!_isWorld &&
            asInt(m['from']) == _state.userId &&
            asInt(m['from']) > 0);
    final revoked = asBool(m['revoked']);
    final body = asStr(m['body'] ?? m['message']);
    final image = asStr(m['image']);
    final kind = asStr(m['kind']);
    final player = asStr(m['player'] ?? m['name'] ?? _peer['username']);
    final ts = asInt(m['ts'] ?? m['created_at']);
    final read = asBool(m['read']);
    final isBot = kind == 'bot';

    if (revoked) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Center(
          child: Text(
            mine ? '你撤回了一条消息' : '对方撤回了一条消息',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10.5),
          ),
        ),
      );
    }

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.74,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: mine ? AppColors.brand : cs.surface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(15),
          topRight: const Radius.circular(15),
          bottomLeft: Radius.circular(mine ? 15 : 4),
          bottomRight: Radius.circular(mine ? 4 : 15),
        ),
        border: mine ? null : Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (image.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: GestureDetector(
                onTap: () => showImageViewer(context, [image], 0),
                child: AnyImage(url: image, width: 180, height: 150),
              ),
            ),
          if (body.isNotEmpty)
            Text(
              body,
              style: TextStyle(
                color: mine ? Colors.white : cs.onSurface,
                fontSize: 13.5,
                height: 1.55,
              ),
            ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                fmtTime(ts),
                style: TextStyle(
                  color: mine ? Colors.white60 : cs.onSurfaceVariant,
                  fontSize: 9,
                ),
              ),
              if (mine && !_isWorld && read) ...[
                const SizedBox(width: 4),
                Text(
                  '已读',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 9,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!mine) ...[
            UserAvatar(
              name: player,
              size: 34,
              onTap: player.isEmpty
                  ? null
                  : () => Nav.to('/u/${Uri.encodeComponent(player)}'),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!mine)
                  Padding(
                    padding: const EdgeInsets.only(left: 3, bottom: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          player.isEmpty ? '玩家' : player,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isBot) ...[
                          const SizedBox(width: 4),
                          const Pill(text: 'AI 助手', color: AppColors.gold),
                        ],
                      ],
                    ),
                  ),
                GestureDetector(
                  onLongPress: () => _messageMenu(m),
                  child: bubble,
                ),
              ],
            ),
          ),
          if (mine) const SizedBox(width: 2),
        ],
      ),
    );
  }

  Widget _composer(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 9),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (!_isWorld)
              IconButton(
                onPressed: _sending ? null : _sendImage,
                icon: Icon(Icons.image_outlined,
                    color: cs.onSurfaceVariant, size: 21),
              ),
            Expanded(
              child: TextField(
                controller: _text,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                onChanged: (_) {
                  if (!_isWorld && _state.isLoggedIn) {
                    Realtime.i.typing(_uid);
                  }
                },
                decoration: InputDecoration(
                  hintText: _isWorld
                      ? (_state.mcName.isEmpty
                          ? '绑定游戏 ID 后可发到游戏里…'
                          : '发到游戏里…')
                      : '发私信给 ${asStr(_peer['username'], '好友')}…',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 19),
            ),
          ],
        ),
      ),
    );
  }
}
