import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../app/config.dart';
import 'api.dart';

/// ============================================================
///  实时通道（私信 / 通知 / 好友申请）
///
///  为什么手写而不用 socket_io_client 插件：
///   1) 少一个依赖 = 少一个构建/兼容风险（沙箱连不上 pub.dev，只能靠 CI 试错）；
///   2) 站点用的是 Socket.IO 4.x（Engine.IO 协议 4），
///      而这个协议的「websocket-only」形态非常简单，100 多行就能覆盖：
///        ← 0{"sid":...}          握手
///        → 40                    CONNECT 到默认命名空间
///        ← 40{"sid":...}
///        ← 2 / → 3               ping / pong 心跳
///        ← 42["dm",{...}]        事件
///        → 42["dmTyping",{...}]  我们发事件
///   3) 认证靠握手头里的 Cookie —— dart:io 的 WebSocket.connect 支持自定义头，
///      这样就能复用 App 已经存好的会话 Cookie，不需要再折腾一套登录。
///
///  连不上时不是死路：界面层会自动降级为轮询（Realtime.connected == false）。
/// ============================================================
class RtEvent {
  RtEvent(this.type, this.data);

  final String type;
  final Map<String, dynamic> data;

  @override
  String toString() => 'RtEvent($type)';
}

class Realtime {
  Realtime._();
  static final Realtime i = Realtime._();

  final StreamController<RtEvent> _ctrl = StreamController<RtEvent>.broadcast();
  Stream<RtEvent> get stream => _ctrl.stream;

  /// 连接状态（给界面显示「实时/轮询」小标）
  final ValueNotifier<bool> live = ValueNotifier<bool>(false);
  final ValueNotifier<String> status =
      ValueNotifier<String>('未连接'); // 未连接 / 连接中 / 实时 / 轮询

  WebSocket? _ws;
  StreamSubscription<dynamic>? _sub;
  Timer? _watchdog;
  Timer? _retry;
  int _attempt = 0;
  bool _want = false;
  int _pingInterval = 25;

  bool get connected => live.value;

  String get _wsUrl {
    final base = Api.i.base;
    final u = Uri.parse(base);
    final scheme = u.scheme == 'https' ? 'wss' : 'ws';
    return '$scheme://${u.host}${u.port > 0 ? ':${u.port}' : ''}/socket.io/?EIO=4&transport=websocket';
  }

  /// 开始保持连接（登录后调用；设置里选「仅在打开时」则不会调用）
  void start() {
    _want = true;
    if (_ws != null) return;
    _connect();
  }

  void stop() {
    _want = false;
    _retry?.cancel();
    _watchdog?.cancel();
    _sub?.cancel();
    _sub = null;
    try {
      _ws?.close();
    } catch (_) {}
    _ws = null;
    _setStatus(false, '已关闭');
  }

  void _setStatus(bool isLive, String text) {
    if (live.value != isLive) live.value = isLive;
    if (status.value != text) status.value = text;
  }

  Future<void> _connect() async {
    if (!_want) return;
    _retry?.cancel();
    final cookie = Api.i.cookieRaw;
    if (cookie == null || cookie.isEmpty) {
      _setStatus(false, '未登录');
      return;
    }
    _setStatus(false, '连接中');
    try {
      final ws = await WebSocket.connect(
        _wsUrl,
        headers: <String, String>{
          'Cookie': cookie,
          'User-Agent': '${AppMeta.appNameEn}/1.1 (Android)',
          // 注意：不要带 Origin —— 站点把它当浏览器同源校验的信号
        },
      ).timeout(const Duration(seconds: 10));
      _ws = ws;
      _attempt = 0;
      ws.pingInterval = null;
      _sub = ws.listen(
        _onFrame,
        onError: (Object e) => _drop('连接出错'),
        onDone: () => _drop('连接断开'),
        cancelOnError: true,
      );
      _armWatchdog();
    } catch (e) {
      _drop('连不上（${e.toString().split('\n').first}）');
    }
  }

  void _drop(String why) {
    _sub?.cancel();
    _sub = null;
    _watchdog?.cancel();
    try {
      _ws?.close();
    } catch (_) {}
    _ws = null;
    _setStatus(false, _want ? '轮询中（$why）' : '未连接');
    if (!_want) return;
    final wait = Duration(seconds: [1, 2, 4, 8, 15, 30][_attempt.clamp(0, 5)]);
    _attempt++;
    _retry?.cancel();
    _retry = Timer(wait, _connect);
  }

  /// 心跳看门狗：服务端每 _pingInterval 秒 ping 一次，
  /// 两个周期没动静就当作掉线（手机切网/待机回来后很常见）
  void _armWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer.periodic(Duration(seconds: _pingInterval + 5), (_) {
      if (_lastSeen != null &&
          DateTime.now().difference(_lastSeen!).inSeconds > _pingInterval * 2 + 10) {
        _drop('心跳超时');
      }
    });
  }

  DateTime? _lastSeen;

  void _onFrame(dynamic raw) {
    _lastSeen = DateTime.now();
    final text = raw is String ? raw : utf8.decode(raw as List<int>, allowMalformed: true);
    if (text.isEmpty) return;
    final code = text[0];
    final rest = text.substring(1);

    switch (code) {
      case '0': // 握手
        try {
          final j = asMap(jsonDecode(rest));
          final pi = asInt(j['pingInterval'], 25000);
          _pingInterval = (pi / 1000).round().clamp(5, 120);
          _armWatchdog();
        } catch (_) {}
        _send('40'); // 连接默认命名空间
        return;
      case '2': // 服务端 ping
        _send('3');
        return;
      case '4':
        if (rest.startsWith('0')) {
          // CONNECT 成功 → 服务端已把本连接加入 u:<uid> 房间
          _setStatus(true, '实时');
          return;
        }
        return;
      default:
        break;
    }

    if (!text.startsWith('42')) return; // 41=断开, 43/44=错误等，忽略即可
    try {
      final payload = jsonDecode(text.substring(2));
      if (payload is! List || payload.isEmpty) return;
      final type = asStr(payload[0]);
      final data = payload.length > 1 ? asMap(payload[1]) : <String, dynamic>{};
      _ctrl.add(RtEvent(type, data));
    } catch (e) {
      debugPrint('[rt] 事件解析失败：$e');
    }
  }

  void _send(String frame) {
    try {
      _ws?.add(frame);
    } catch (e) {
      debugPrint('[rt] 发送失败：$e');
    }
  }

  /// 发事件：Realtime.emit('dmTyping', {'to': 5})
  void emit(String type, Map<String, dynamic> data) {
    if (!connected) return;
    _send('42${jsonEncode(<dynamic>[type, data])}');
  }

  /// 「正在输入」节流发送
  DateTime? _lastTyping;
  void typing(int to) {
    final now = DateTime.now();
    if (_lastTyping != null && now.difference(_lastTyping!).inMilliseconds < 2500) {
      return;
    }
    _lastTyping = now;
    emit('dmTyping', <String, dynamic>{'to': to});
  }
}
