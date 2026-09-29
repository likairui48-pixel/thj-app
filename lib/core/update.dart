import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/config.dart';
import 'api.dart';

/// ============================================================
///  在线更新（预留接口）
///
///  站点在 `/api/app/version` 返回清单即可生效，App 端**无需再改代码**：
///  {
///    "ok": true,
///    "latest": {
///      "version": "1.1.0",
///      "versionCode": 2,
///      "url": "https://.../thj-app-arm64.apk",
///      "notes": ["新增聊天室", "修复夜间模式"],
///      "force": false,
///      "minVersionCode": 1
///    }
///  }
///  接口不存在 / 返回异常时静默降级（不打扰用户）。
/// ============================================================
class UpdateInfo {
  UpdateInfo({
    required this.version,
    required this.versionCode,
    this.url,
    this.notes = const <String>[],
    this.force = false,
    this.size,
  });

  final String version;
  final int versionCode;
  final String? url;
  final List<String> notes;
  final bool force;
  final int? size;

  bool get hasNewer => versionCode > AppMeta.versionCode;
  bool get canDownload => url != null && url!.isNotEmpty;

  String get sizeLabel {
    if (size == null || size! <= 0) return '';
    final mb = size! / 1024 / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class UpdateService {
  UpdateService._();

  /// 检查更新：失败一律返回 null（离线/未实现都当"已是最新"）
  static Future<UpdateInfo?> check() async {
    try {
      final j = await Api.i.get(Endpoints.versionPath);
      final src = j['latest'] is Map ? asMap(j['latest']) : j;
      final code = asInt(src['versionCode'] ?? src['version_code'] ?? src['build']);
      final ver = asStr(src['version'] ?? src['versionName'], '');
      if (code <= 0 && ver.isEmpty) return null;
      final notesRaw = src['notes'] ?? src['changelog'];
      final notes = <String>[];
      if (notesRaw is List) {
        for (final n in notesRaw) {
          notes.add(asStr(n));
        }
      } else if (notesRaw is String) {
        notes.addAll(notesRaw
            .split(RegExp(r'[\r\n]+'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty));
      }
      return UpdateInfo(
        version: ver.isEmpty ? AppMeta.version : ver,
        versionCode: code <= 0 ? AppMeta.versionCode : code,
        url: asStrOrNull(src['url'] ?? src['apk'] ?? src['download']),
        notes: notes,
        force: asBool(src['force']),
        size: src['size'] == null ? null : asInt(src['size']),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<bool> openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    try {
      var ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        ok = await launchUrl(uri);
      }
      return ok;
    } catch (_) {
      // 兜底：复制链接，用户可粘到浏览器
      await Clipboard.setData(ClipboardData(text: url));
      return false;
    }
  }

  /// 用户手机装了哪个架构就下哪个包（服务端可给多架构地址）
  static Future<bool> download(UpdateInfo info) async {
    if (!info.canDownload) return false;
    return openUrl(info.url!);
  }
}
