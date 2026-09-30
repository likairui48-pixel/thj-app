import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// ============================================================
///  相册选图 → data URL（服务端只吃 base64）
///
///  关键技巧：把「压到多少像素」交给 image_picker 的原生实现去做
///  （maxWidth/maxHeight/imageQuality），它会直接输出压缩后的 JPEG，
///  这样就既不用引额外图像库，也天然满足站点的体积限制：
///    上传配图 ≤6MB、头像 ≤3MB、主页背景 ≤6MB
/// ============================================================
class Img {
  Img._();

  static final ImagePicker _picker = ImagePicker();

  /// 从相册选一张，返回 data URL；用户取消返回 null
  static Future<String?> pickDataUrl({
    int maxEdge = 1600,
    int quality = 85,
  }) async {
    final f = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: maxEdge.toDouble(),
      maxHeight: maxEdge.toDouble(),
      imageQuality: quality,
      requestFullMetadata: false,
    );
    if (f == null) return null;
    return _toDataUrl(f);
  }

  /// 拍照
  static Future<String?> shootDataUrl({
    int maxEdge = 1600,
    int quality = 85,
  }) async {
    final f = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: maxEdge.toDouble(),
      maxHeight: maxEdge.toDouble(),
      imageQuality: quality,
      requestFullMetadata: false,
    );
    if (f == null) return null;
    return _toDataUrl(f);
  }

  static Future<String> _toDataUrl(XFile f) async {
    final bytes = await f.readAsBytes();
    final mime = _mimeOf(f, bytes);
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  static String _mimeOf(XFile f, List<int> bytes) {
    final n = f.name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    // 魔数兜底（有些 ROM 的临时文件名没有扩展名）
    if (bytes.length > 8 && bytes[0] == 0x89 && bytes[1] == 0x50) return 'image/png';
    if (bytes.length > 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[8] == 0x57) return 'image/webp';
    return 'image/jpeg';
  }

  /// 小工具：data URL 大约的 KB 数（用于提示用户）
  static int approxKb(String dataUrl) {
    try {
      final i = dataUrl.indexOf(',');
      if (i < 0) return 0;
      return (dataUrl.length - i) * 3 ~/ 4 ~/ 1024;
    } catch (_) {
      return 0;
    }
  }

  static void log(String msg) => debugPrint('[img] $msg');
}

/// 判断文件是否像图片（备用）
bool looksLikeImage(File f) {
  try {
    final head = f.openSync().readSync(4);
    return head.length >= 3 && head[0] == 0xFF && head[1] == 0xD8;
  } catch (_) {
    return false;
  }
}
