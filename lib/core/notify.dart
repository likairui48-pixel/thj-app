import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 本地通知：私信、通知、好友申请、活动提醒。
/// 不依赖服务端推送，App 进程活着时由长连接/轮询触发；被系统杀掉后由系统策略决定。
class NotifyService {
  NotifyService._();
  static final NotifyService i = NotifyService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  Future<void> Function(String? payload)? _onTap;
  bool _ready = false;

  Future<void> init({Future<void> Function(String? payload)? onTap}) async {
    if (_ready) return;
    _onTap = onTap;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (resp) async {
        final payload = resp.payload;
        if (payload != null && payload.isNotEmpty) {
          await _onTap?.call(payload);
        }
      },
    );
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'thj_messages',
        '同禾境消息',
        description: '私信、回复、好友申请、活动提醒',
        importance: Importance.high,
        playSound: true,
      ),
    );
    _ready = true;
  }

  Future<bool> ensurePermission() async {
    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await androidPlugin?.requestNotificationsPermission() ?? true;
    } catch (_) {
      return false;
    }
  }

  Future<void> show({
    required int id,
    required String title,
    String body = '',
    String? payload,
  }) async {
    if (!_ready) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'thj_messages',
        '同禾境消息',
        channelDescription: '私信、回复、好友申请、活动提醒',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );
    try {
      await _plugin.show(id, title, body.isEmpty ? '点我查看' : body, details,
          payload: payload);
    } catch (e) {
      debugPrint('notification failed: $e');
    }
  }
}
