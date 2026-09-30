import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// ============================================================
///  与安卓原生的一点点交互（保持后台连接 / 省电白名单引导）
///
///  说明：安卓 8.0 起，想在后台长期存活只能开「前台服务」，
///  而前台服务**必须**在通知栏留一条通知（系统硬性规定，所有 App 一样）。
///  所以这条通知被刻意做成：静默、不响、不震动、不显示状态栏图标，
///  只在通知栏里可折叠看到 —— 业界（音乐/同步/输入法）都是这么干的。
///
///  不想看到它的人，把「消息提醒」设为「仅在打开时」即可，完全不留通知。
/// ============================================================
class NativeKeepAlive {
  NativeKeepAlive._();

  static const MethodChannel _ch = MethodChannel('cn.mcfuns.thj/keepalive');

  /// 当前是否在跑前台服务
  static Future<bool> isRunning() async {
    try {
      final v = await _ch.invokeMethod<bool>('isRunning');
      return v ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 开/关前台服务（失败静默：功能降级为「只在打开时收」）
  static Future<void> set(bool on) async {
    try {
      await _ch.invokeMethod<bool>(on ? 'start' : 'stop');
    } catch (e) {
      debugPrint('[keepalive] 切换失败：$e');
    }
  }

  /// 是否已被加入「电池不优化」白名单
  static Future<bool> ignoringBatteryOptimizations() async {
    try {
      final v = await _ch.invokeMethod<bool>('ignoringBatteryOptimizations');
      return v ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 跳系统设置让用户手动允许（各家 ROM 位置不同，尽量直接到位）
  static Future<void> openBatterySettings() async {
    try {
      await _ch.invokeMethod<bool>('openBatterySettings');
    } catch (e) {
      debugPrint('[keepalive] 打开设置失败：$e');
    }
  }

  static Future<void> openAutoStartSettings() async {
    try {
      await _ch.invokeMethod<bool>('openAutoStartSettings');
    } catch (e) {
      debugPrint('[keepalive] 打开自启动设置失败：$e');
    }
  }
}
