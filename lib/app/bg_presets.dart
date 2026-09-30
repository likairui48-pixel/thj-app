import 'package:flutter/material.dart';

/// ============================================================
///  主页背景预设（对应站点 CSS 里的 g1~g8 / d1~d4 十二种预设）
///
///  站点把预设存成代号（g1…d4），真正的图案在网页 CSS 里。
///  原生端不引网页资源，用等价的渐变色近似呈现，
///  保证「选了什么，两端看起来是一路人」。
/// ============================================================
class BgPreset {
  const BgPreset(this.code, this.label, this.colors);
  final String code;
  final String label;
  final List<Color> colors;
}

const List<BgPreset> kBgPresets = <BgPreset>[
  BgPreset('g1', '禾风', [Color(0xFF2E9E63), Color(0xFF7FD1A8)]),
  BgPreset('g2', '青禾', [Color(0xFF1E7C4A), Color(0xFF4FBF8B)]),
  BgPreset('g3', '晨雾', [Color(0xFF6FA8A0), Color(0xFFBEE3DA)]),
  BgPreset('g4', '稻香', [Color(0xFFB08A3E), Color(0xFFE7CF91)]),
  BgPreset('g5', '苔石', [Color(0xFF4A5D4E), Color(0xFF8CA593)]),
  BgPreset('g6', '晴空', [Color(0xFF3A7AC9), Color(0xFF9CC7F0)]),
  BgPreset('g7', '暮山', [Color(0xFF7A5CA8), Color(0xFFC9B4E8)]),
  BgPreset('g8', '夜露', [Color(0xFF243B4A), Color(0xFF5D8598)]),
  BgPreset('d1', '墨竹', [Color(0xFF1C1F1D), Color(0xFF3A4A3F)]),
  BgPreset('d2', '暗河', [Color(0xFF12181F), Color(0xFF2C3B47)]),
  BgPreset('d3', '深林', [Color(0xFF14201A), Color(0xFF2E4A38)]),
  BgPreset('d4', '残霞', [Color(0xFF241A20), Color(0xFF5A3A44)]),
];

/// 代号 → 渐变；不是代号返回 null（说明是上传的图片 URL）
LinearGradient? gradientForBg(String? code) {
  if (code == null || code.isEmpty) return null;
  for (final p in kBgPresets) {
    if (p.code == code) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: p.colors,
      );
    }
  }
  return null;
}

BgPreset? presetForBg(String? code) {
  if (code == null) return null;
  for (final p in kBgPresets) {
    if (p.code == code) return p;
  }
  return null;
}
