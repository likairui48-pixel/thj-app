import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 极简离线缓存：只缓存 JSON，页面先展示旧数据，再静默刷新。
class Cache {
  Cache._();
  static const String _prefix = 'thj_cache_';

  static Future<void> save(String key, Map<String, dynamic> value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('$_prefix$key', jsonEncode({
      'at': DateTime.now().millisecondsSinceEpoch,
      'v': value,
    }));
  }

  static Future<Map<String, dynamic>?> load(
    String key, {
    Duration maxAge = const Duration(days: 7),
  }) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString('$_prefix$key');
    if (raw == null || raw.isEmpty) return null;
    try {
      final box = jsonDecode(raw);
      if (box is! Map) return null;
      final at = (box['at'] as num?)?.toInt() ?? 0;
      if (DateTime.now().millisecondsSinceEpoch - at > maxAge.inMilliseconds) {
        return null;
      }
      final v = box['v'];
      if (v is Map) {
        return v.map((k, val) => MapEntry(k.toString(), val));
      }
    } catch (_) {
      // 坏缓存直接忽略
    }
    return null;
  }

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    for (final k in sp.getKeys().where((k) => k.startsWith(_prefix)).toList()) {
      await sp.remove(k);
    }
  }
}
