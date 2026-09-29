import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// ============================================================
///  消息提示（系统通知）
///  - Android 13+ 需要运行时通知权限
///  - 通知点击回传 payload，由 AppState 决定跳哪个 Tab
/// ============================================================
class NotifyService {
  NotifyService._();
  static final NotifyService i = NotifyService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;
  bool permission = false;
  void Function(String? payload)? _onTap;

  static const String _channelId = 'thj_news';
  static const String _channelName = '同禾境消息';
  static const String _channelDesc = '站内通知、私信与好友申请提醒';

  Future<void> init({void Function(String? payload)? onTap}) async {
    _onTap = onTap;
    if (_ready) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(android: android);
      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: (resp) => _onTap?.call(resp.payload),
      );
      await _createChannel();
      _ready = true;
    } catch (e) {
      debugPrint('[notify] 初始化失败：$e');
    }
  }

  Future<void> _createChannel() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    final channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );
    await android.createNotificationChannel(channel);
  }

  /// 请求通知权限（Android 13+ 会弹系统对话框）
  Future<bool> ensurePermission() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      permission = granted ?? true;
      notifyPermissionChanged();
      return permission;
    } catch (_) {
      return false;
    }
  }

  final ValueNotifier<bool> permissionListenable = ValueNotifier<bool>(true);
  void notifyPermissionChanged() => permissionListenable.value = permission;

  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
    bool bigText = true,
  }) async {
    if (!_ready) await init(onTap: _onTap);
    try {
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          autoCancel: true,
          icon: '@mipmap/ic_launcher',
          styleInformation:
              bigText ? BigTextStyleInformation(body) : null,
        ),
      );
      await _plugin.show(id, title, body, details, payload: payload);
    } catch (e) {
      debugPrint('[notify] 发送失败：$e');
    }
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
