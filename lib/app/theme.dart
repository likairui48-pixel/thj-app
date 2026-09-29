import 'package:flutter/material.dart';

/// ============================================================
///  同禾境 · 黑白双主题 + 液态玻璃代币
///
///  设计语言：
///   底：墨黑 / 素白，两层渐变
///   面上浮着「液态玻璃」——模糊 + 半透明染色 + 1px 亮边 + 内高光 + 镜面流光
///   强调色只用站点品牌绿（#2E9E63），其余全部黑白灰
/// ============================================================

/// 玻璃代币：明暗各一套
class GlassTokens {
  const GlassTokens({
    required this.brightness,
    required this.bgTop,
    required this.bgBottom,
    required this.glowA,
    required this.glowB,
    required this.fill,
    required this.fillStrong,
    required this.stroke,
    required this.highlight,
    required this.shadow,
    required this.text,
    required this.text2,
    required this.text3,
    required this.divider,
    required this.blur,
    required this.accent,
  });

  final Brightness brightness;
  final Color bgTop;
  final Color bgBottom;
  final Color glowA;
  final Color glowB;
  final Color fill;        // 玻璃填充（普通）
  final Color fillStrong;  // 玻璃填充（强调，如选中态）
  final Color stroke;      // 玻璃边缘
  final Color highlight;   // 顶部内高光
  final Color shadow;      // 阴影
  final Color text;
  final Color text2;
  final Color text3;
  final Color divider;
  final double blur;
  final Color accent;

  static const Color brand = Color(0xFF2E9E63);
  static const Color brandDark = Color(0xFF1E7C4A);
  static const Color warn = Color(0xFFCF8A1C);
  static const Color danger = Color(0xFFD2473D);

  /// 夜（黑）：不是纯黑，留一点层次才像玻璃而不是贴纸
  static const GlassTokens dark = GlassTokens(
    brightness: Brightness.dark,
    bgTop: Color(0xFF000000),
    bgBottom: Color(0xFF0B0C0E),
    glowA: Color(0x1FFFFFFF),
    glowB: Color(0x14FFFFFF),
    fill: Color(0x14FFFFFF),
    fillStrong: Color(0x24FFFFFF),
    stroke: Color(0x29FFFFFF),
    highlight: Color(0x1AFFFFFF),
    shadow: Color(0x66000000),
    text: Color(0xFFFFFFFF),
    text2: Color(0xB3FFFFFF),
    text3: Color(0x80FFFFFF),
    divider: Color(0x1AFFFFFF),
    blur: 26,
    accent: brand,
  );

  /// 昼（白）：奶白而非死白，玻璃才有厚度
  static const GlassTokens light = GlassTokens(
    brightness: Brightness.light,
    bgTop: Color(0xFFFBFAF8),
    bgBottom: Color(0xFFEDECE8),
    glowA: Color(0x33FFFFFF),
    glowB: Color(0x22000000),
    fill: Color(0x8CFFFFFF),
    fillStrong: Color(0xCCFFFFFF),
    stroke: Color(0x14000000),
    highlight: Color(0xCCFFFFFF),
    shadow: Color(0x1A000000),
    text: Color(0xFF111214),
    text2: Color(0x99111214),
    text3: Color(0x66111214),
    divider: Color(0x14000000),
    blur: 22,
    accent: brandDark,
  );

  static GlassTokens of(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark ? dark : light;
}

/// 圆角与间距
class R {
  R._();
  static const double card = 22;
  static const double tile = 16;
  static const double pill = 999; // 椭圆/胶囊
  static const double sheet = 28;
  static const double gap = 12;
  static const double page = 16;
}

/// 动效（系统「减少动画」时自动降级）
class Motion {
  Motion._();
  static bool reduce = false;

  static Duration get quick =>
      Duration(milliseconds: reduce ? 90 : 180);
  static Duration get medium =>
      Duration(milliseconds: reduce ? 140 : 280);
  static Duration get page =>
      Duration(milliseconds: reduce ? 160 : 320);
  static Curve get spring => reduce ? Curves.easeOut : Curves.easeOutBack;
  static Curve get ease => Curves.easeOutCubic;
}

/// 主题装配
class ThjTheme {
  ThjTheme._();

  static ThemeData dark() => _build(GlassTokens.dark);
  static ThemeData light() => _build(GlassTokens.light);

  static ThemeData _build(GlassTokens t) {
    final isDark = t.brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: t.brightness,
      primary: t.accent,
      onPrimary: Colors.white,
      secondary: t.accent,
      onSecondary: Colors.white,
      error: GlassTokens.danger,
      onError: Colors.white,
      surface: isDark ? const Color(0xFF0B0C0E) : const Color(0xFFFBFAF8),
      onSurface: t.text,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: t.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      dividerColor: t.divider,
      fontFamily: null,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: t.text,
        titleTextStyle: TextStyle(
          color: t.text,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
      textTheme: TextTheme(
        titleLarge: TextStyle(color: t.text, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: t.text, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: t.text, height: 1.45),
        bodyMedium: TextStyle(color: t.text2, height: 1.45),
        bodySmall: TextStyle(color: t.text3),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xF21C1D20) : const Color(0xF2FFFFFF),
        contentTextStyle: TextStyle(color: t.text),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(R.tile),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.card)),
      ),
    );
  }
}
