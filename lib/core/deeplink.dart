import 'package:flutter/services.dart';

import 'nav.dart';

/// 接收 Android 侧传来的站内链接。
/// 支持 https://thjmc.duckdns.org:8443/... 以及 thj://open?path=/...
class DeepLinks {
  DeepLinks._();
  static const MethodChannel _ch = MethodChannel('thj/deeplink');

  static Future<void> init() async {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'link') {
        final raw = call.arguments;
        if (raw is String && raw.isNotEmpty) _handle(raw);
      }
      return null;
    });
    try {
      final initial = await _ch.invokeMethod<String>('initial');
      if (initial != null && initial.isNotEmpty) _handle(initial);
    } catch (_) {
      // 非 Android / 未实现时忽略
    }
  }

  static void _handle(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    if (uri.scheme == 'thj') {
      final path = uri.queryParameters['path'] ?? uri.path;
      if (path.isNotEmpty) Nav.to(path);
      return;
    }
    final path = uri.path.isEmpty ? '/' : uri.path;
    final query = uri.hasQuery ? '?${uri.query}' : '';
    Nav.to('$path$query');
  }
}
