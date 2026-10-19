import 'dart:convert';
import 'dart:io';

import 'package:image_picker/image_picker.dart';

/// 选图并转成站点接受的 data URL（服务端只吃 base64）。
class ImgPicker {
  ImgPicker._();

  static Future<String?> one({
    int maxWidth = 1600,
    int quality = 82,
    ImageSource source = ImageSource.gallery,
  }) async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: source,
      maxWidth: maxWidth.toDouble(),
      maxHeight: maxWidth.toDouble(),
      imageQuality: quality,
    );
    if (x == null) return null;
    return _toDataUrl(x);
  }

  static Future<List<String>> multi({int limit = 9}) async {
    final picker = ImagePicker();
    final list = await picker.pickMultiImage(
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 82,
    );
    final out = <String>[];
    for (final x in list) {
      final d = await _toDataUrl(x);
      if (d != null) out.add(d);
      if (out.length >= limit) break;
    }
    return out;
  }

  static Future<String?> _toDataUrl(XFile x) async {
    final bytes = await x.readAsBytes();
    if (bytes.length > 4 * 1024 * 1024) {
      throw Exception('图片超过 4MB，请换一张或先压缩');
    }
    var mime = x.mimeType;
    if (mime == null || mime.isEmpty) {
      final n = x.name.toLowerCase();
      if (n.endsWith('.png')) {
        mime = 'image/png';
      } else if (n.endsWith('.webp')) {
        mime = 'image/webp';
      } else if (n.endsWith('.gif')) {
        mime = 'image/gif';
      } else {
        mime = 'image/jpeg';
      }
    }
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  static Future<String?> fromPath(String path) async {
    final f = File(path);
    if (!await f.exists()) return null;
    final bytes = await f.readAsBytes();
    if (bytes.length > 4 * 1024 * 1024) return null;
    var mime = 'image/jpeg';
    final n = path.toLowerCase();
    if (n.endsWith('.png')) mime = 'image/png';
    if (n.endsWith('.webp')) mime = 'image/webp';
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }
}
