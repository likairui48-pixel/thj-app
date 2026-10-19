import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'meta.dart';

class RtEvent {
  RtEvent(this.type, this.data);
  final String type;
  final Map<String, dynamic> data;

  @override
  String toString() => 'RtEvent($type)';
}

/// 与站点保持一条 Socket.IO（Engine.IO v4）长连接。
///
/// 只实现 websocket-only 形态，足够覆盖私信、通知、聊天、好友申请：
///   0{...} 握手 → 40 连接命名空间 → 2/3 心跳 → 42["event",{...}] 业务事件
class Realtime {
  Realtime._();
  static final Realtime i = Realtime._();

  final StreamController<RtEvent> _events =
      StreamController<RtEvent>.broadcast();
  Stream<RtEvent> get stream => _events.stream;

  final ValueNotifier<String> status = ValueNotifier<String>('未连接');
  bool get connected => _ws != null && status.value == '实时';

  WebSocket? _ws;
  StreamSubscription<dynamic>? _sub;
  Timer? _retryTimer;
  Timer? _watchdog;
  bool _want = false;
  int _attempt = 0;

  String get _url {
    final u = Uri.parse(AppMeta.baseUrl);
    final scheme = u.scheme == 'https' ? 'wss' : 'ws';
    final port = u.hasPort ? ':${u.port}' : '';
    return '$scheme://${u.host}$port/socket.io/?EIO=4&transport=websocket';
  }

  void start() {
    _want = true;
    if (_ws != null) return;
    _connect();
  }

  void stop() {
    _want = false;
    _retryTimer?.cancel();
    _watchdog?.cancel();
    _sub?.cancel();
    _sub = null;
    try {
      _ws?.close();
    } catch (_) {}
    _ws = null;
    status.value = '已关闭';
  }

  Future<void> _connect() async {
    if (!_want) return;
    final cookie = Api.i.cookie;
    if (cookie == null || cookie.isEmpty) {
      status.value = '未登录';
      return;
    }
    status.value = '连接中';
    try {
      final ws = await WebSocket.connect(
        _url,
        headers: <String, String>{
          'Cookie': cookie,
          'User-Agent': '${AppMeta.appNameEn}/${AppMeta.version} (Android)',
        },
      ).timeout(const Duration(seconds: 12));
      _ws = ws;
      _attempt = 0;
      ws.pingInterval = null;
      _sub = ws.listen(
        _onFrame,
        onError: (_) => _drop(),
        onDone: _drop,
        cancelOnError: true,
      );
      _armWatchdog();
    } catch (_) {
      _scheduleRetry();
    }
  }

  void _armWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(const Duration(seconds: 75), () {
      // 长时间没收到任何帧，主动重连（服务端异常/网络半死）
      _drop();
    });
  }

  void _onFrame(dynamic raw) {
    _armWatchdog();
    final text = raw is String ? raw : utf8.decode(raw as List<int>);
    if (text.isEmpty) return;

    if (text.startsWith('0')) {
      // Engine.IO 握手完成 → 连接默认命名空间
      _send('40');
      return;
    }
    if (text == '2') {
      _send('3');
      return;
    }
    if (text.startsWith('40')) {
      status.value = '实时';
      return;
    }
    if (text.startsWith('41')) {
      _drop();
      return;
    }
    if (text.startsWith('42')) {
      try {
        final arr = jsonDecode(text.substring(2));
        if (arr is List && arr.isNotEmpty) {
          final type = arr[0].toString();
          final data = arr.length > 1 ? asMap(arr[1]) : <String, dynamic>{};
          _events.add(RtEvent(type, data));
        }
      } catch (_) {
        // 忽略坏帧
      }
    }
  }

  bool _send(String raw) {
    final ws = _ws;
    if (ws == null) return false;
    try {
      ws.add(raw);
      return true;
    } catch (_) {
      _drop();
      return false;
    }
  }

  bool emit(String event, [Map<String, dynamic> data = const {}]) {
    return _send('42${jsonEncode([event, data])}');
  }

  void typing(int userId) => emit('dmTyping', {'to': userId});

  void _drop() {
    _watchdog?.cancel();
    _sub?.cancel();
    _sub = null;
    try {
      _ws?.close();
    } catch (_) {}
    _ws = null;
    if (_want) _scheduleRetry();
  }

  void _scheduleRetry() {
    if (!_want) return;
    status.value = '轮询';
    _retryTimer?.cancel();
    final seconds = <int>[2, 5, 10, 20, 30][_attempt.clamp(0, 4)];
    _attempt = (_attempt + 1).clamp(0, 4);
    _retryTimer = Timer(Duration(seconds: seconds), _connect);
  }
}

/// 前台服务开关：后台保持长连接（通知栏一条静默通知）。
class AppKeepAlive {
  AppKeepAlive._();
  static const MethodChannel _ch = MethodChannel('thj/keepalive');

  static Future<void> set(bool on) async {
    try {
      await _ch.invokeMethod('set', {'on': on});
    } catch (_) {
      // 非 Android / 未实现时静默忽略
    }
  }
}
