import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app/theme.dart';

/// ============================================================
///  液态玻璃组件库
///  结构：ClipRRect → BackdropFilter(模糊) → 渐变染色 → 1px 亮边 → 顶部内高光
/// ============================================================

/// 语义图标名 → IconData（远程配置只能传字符串，统一在这里映射）
IconData iconFor(String name) {
  switch (name) {
    case 'home':
      return Icons.cottage_rounded;
    case 'rank':
      return Icons.leaderboard_rounded;
    case 'community':
      return Icons.forum_rounded;
    case 'message':
      return Icons.notifications_rounded;
    case 'person':
      return Icons.person_rounded;
    case 'search':
      return Icons.search_rounded;
    case 'settings':
      return Icons.tune_rounded;
    case 'gift':
      return Icons.card_giftcard_rounded;
    case 'more':
      return Icons.more_horiz_rounded;
    default:
      return Icons.circle_outlined;
  }
}

/// ------------------------------------------------------------
/// 背景：黑白双色的缓慢流动光晕（不抢内容，只给玻璃提供折射源）
/// ------------------------------------------------------------
class AuroraBg extends StatefulWidget {
  const AuroraBg({super.key, required this.child});

  final Widget child;

  @override
  State<AuroraBg> createState() => _AuroraBgState();
}

class _AuroraBgState extends State<AuroraBg>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    final isDark = t.brightness == Brightness.dark;
    return Stack(
      children: [
        // 底：两层渐变
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [t.bgTop, t.bgBottom],
              ),
            ),
          ),
        ),
        // 光晕（刻意低对比：黑白主题下就是「一团雾」）
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final p = _c.value * 2 * math.pi;
            return Stack(
              children: [
                _blob(
                  t,
                  align: Alignment(
                    -0.7 + 0.5 * math.sin(p),
                    -0.55 + 0.25 * math.cos(p * 0.8),
                  ),
                  size: 320,
                  color: t.glowA,
                ),
                _blob(
                  t,
                  align: Alignment(
                    0.75 + 0.35 * math.cos(p * 0.7),
                    0.35 + 0.3 * math.sin(p * 0.9),
                  ),
                  size: 280,
                  color: t.glowB,
                ),
                if (isDark)
                  _blob(
                    t,
                    align: Alignment(
                      0.1 + 0.4 * math.sin(p * 1.3),
                      -0.85 + 0.2 * math.cos(p * 1.1),
                    ),
                    size: 220,
                    color: t.glowA,
                  ),
              ],
            );
          },
        ),
        widget.child,
      ],
    );
  }

  Widget _blob(GlassTokens t,
      {required Alignment align, required double size, required Color color}) {
    return Align(
      alignment: align,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, color.withOpacity(0)],
            ),
          ),
        ),
      ),
    );
  }
}

/// ------------------------------------------------------------
/// 玻璃面板（所有卡片/栏/弹层的基座）
/// ------------------------------------------------------------
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.radius = R.card,
    this.padding = const EdgeInsets.all(16),
    this.strong = false,
    this.blurBoost = 0,
    this.border = true,
    this.shadow = true,
    this.width,
    this.height,
    this.onTap,
    this.alignment,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool strong; // 更强的染色（选中态/浮层）
  final double blurBoost;
  final bool border;
  final bool shadow;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final AlignmentGeometry? alignment;

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    final fill = strong ? t.fillStrong : t.fill;
    final content = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: t.blur + blurBoost,
          sigmaY: t.blur + blurBoost,
        ),
        child: Container(
          width: width,
          height: height,
          alignment: alignment,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                fill,
                Color.alphaBlend(
                  t.highlight.withOpacity(0.35),
                  fill,
                ).withOpacity(fill.opacity * 0.75),
              ],
            ),
            border: border
                ? Border.all(color: t.stroke, width: 1)
                : null,
          ),
          child: child,
        ),
      ),
    );

    final wrapped = shadow
        ? DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(
                  color: t.shadow,
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: content,
          )
        : content;

    if (onTap == null) return wrapped;
    return _PressScale(onTap: onTap!, child: wrapped);
  }
}

/// 按下轻微缩放 + 镜面流光（液态感的关键）
class _PressScale extends StatefulWidget {
  const _PressScale({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: Motion.quick,
        curve: Motion.ease,
        child: widget.child,
      ),
    );
  }
}

/// ------------------------------------------------------------
/// 椭圆形液态玻璃底部栏（浮动胶囊）
/// ------------------------------------------------------------
class GlassPillNav extends StatefulWidget {
  const GlassPillNav({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
    this.badges = const <String, int>{},
  });

  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onChanged;
  /// featureId -> 未读数（0 不显示）
  final Map<String, int> badges;

  /// 页面底部需要预留的高度（含外边距）
  static const double barHeight = 64;
  static const double bottomMargin = 14;
  static double reserved(BuildContext ctx) =>
      barHeight + bottomMargin + MediaQuery.of(ctx).padding.bottom + 8;

  @override
  State<GlassPillNav> createState() => _GlassPillNavState();
}

class NavItem {
  const NavItem({required this.id, required this.label, required this.icon});
  final String id;
  final String label;
  final IconData icon;
}

class _GlassPillNavState extends State<GlassPillNav> {
  int _last = 0;

  @override
  void initState() {
    super.initState();
    _last = widget.index;
  }

  @override
  void didUpdateWidget(covariant GlassPillNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) _last = widget.index;
  }

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    final n = widget.items.length;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        0,
        18,
        GlassPillNav.bottomMargin + MediaQuery.of(context).padding.bottom,
      ),
      child: GlassPanel(
        radius: GlassPillNav.barHeight / 2, // ★ 椭圆形
        padding: EdgeInsets.zero,
        strong: true,
        blurBoost: 6,
        height: GlassPillNav.barHeight,
        child: LayoutBuilder(
          builder: (context, box) {
            final itemW = box.maxWidth / n;
            return Stack(
              alignment: Alignment.centerLeft,
              children: [
                // 滑动的高光胶囊（选中指示器）
                AnimatedPositioned(
                  duration: Motion.medium,
                  curve: Motion.spring,
                  left: itemW * widget.index + 6,
                  top: 6,
                  bottom: 6,
                  width: itemW - 12,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(GlassPillNav.barHeight),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          t.highlight.withOpacity(t.brightness == Brightness.dark ? 0.22 : 0.9),
                          t.fillStrong.withOpacity(0.35),
                        ],
                      ),
                      border: Border.all(color: t.stroke),
                      boxShadow: [
                        BoxShadow(
                          color: t.shadow.withOpacity(0.5),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: List<Widget>.generate(n, (i) {
                    final it = widget.items[i];
                    final active = i == widget.index;
                    final badge = widget.badges[it.id] ?? 0;
                    return SizedBox(
                      width: itemW,
                      child: _navButton(t, it, active, badge, () {
                        if (i != widget.index) widget.onChanged(i);
                      }),
                    );
                  }),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _navButton(
      GlassTokens t, NavItem it, bool active, int badge, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedScale(
                scale: active ? 1.12 : 1,
                duration: Motion.medium,
                curve: Motion.spring,
                child: Icon(
                  it.icon,
                  size: 22,
                  color: active ? t.text : t.text3,
                ),
              ),
              if (badge > 0)
                Positioned(
                  right: -8,
                  top: -4,
                  child: GlassBadge(count: badge),
                ),
            ],
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: Motion.quick,
            style: TextStyle(
              fontSize: active ? 11.5 : 10.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? t.text : t.text3,
            ),
            child: Text(it.label),
          ),
        ],
      ),
    );
  }
}

/// 未读红点
class GlassBadge extends StatelessWidget {
  const GlassBadge({super.key, required this.count, this.max = 99});

  final int count;
  final int max;

  @override
  Widget build(BuildContext context) {
    final label = count > max ? '$max+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      constraints: const BoxConstraints(minWidth: 16),
      decoration: BoxDecoration(
        color: GlassTokens.danger,
        borderRadius: BorderRadius.circular(R.pill),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF0B0C0E)
              : Colors.white,
          width: 1.5,
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
    );
  }
}

/// ------------------------------------------------------------
/// 按钮 / 芯片 / 进度条 / 骨架
/// ------------------------------------------------------------
class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.primary = false,
    this.expand = true,
    this.height = 46,
    this.loading = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool primary;
  final bool expand;
  final double height;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    final disabled = onTap == null || loading;
    final child = Container(
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2), // 椭圆
        gradient: primary
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [t.accent, const Color(0xFF2FA6A0)],
              )
            : null,
        color: primary ? null : t.fill,
        border: Border.all(color: primary ? Colors.transparent : t.stroke),
        boxShadow: primary
            ? [
                BoxShadow(
                  color: t.accent.withOpacity(0.32),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: loading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  primary ? Colors.white : t.text,
                ),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon,
                      size: 18,
                      color: primary ? Colors.white : t.text),
                  const SizedBox(width: 7),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: primary ? Colors.white : t.text,
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                  ),
                ),
              ],
            ),
    );

    final wrapped = Opacity(opacity: disabled ? 0.55 : 1, child: child);
    final tappable = GestureDetector(
      onTap: disabled ? null : onTap,
      child: wrapped,
    );
    return expand ? SizedBox(width: double.infinity, child: tappable) : tappable;
  }
}

class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 42,
    this.tooltip,
    this.badge = 0,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final String? tooltip;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    final btn = GlassPanel(
      radius: size / 2,
      padding: EdgeInsets.zero,
      width: size,
      height: size,
      strong: true,
      shadow: false,
      onTap: onTap,
      alignment: Alignment.center,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, size: size * 0.46, color: t.text),
          if (badge > 0)
            Positioned(right: -4, top: -4, child: GlassBadge(count: badge)),
        ],
      ),
    );
    if (tooltip == null) return btn;
    return Tooltip(message: tooltip!, child: btn);
  }
}

class GlassChip extends StatelessWidget {
  const GlassChip({
    super.key,
    required this.label,
    this.active = false,
    this.onTap,
    this.icon,
    this.color,
  });

  final String label;
  final bool active;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    final c = color ?? t.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.quick,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? c.withOpacity(0.18) : t.fill,
          borderRadius: BorderRadius.circular(R.pill),
          border: Border.all(
            color: active ? c.withOpacity(0.55) : t.stroke,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: active ? c : t.text2),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? c : t.text2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GlassProgress extends StatelessWidget {
  const GlassProgress({super.key, required this.value, this.height = 8});
  final double value; // 0..1
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: t.fill,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: v,
            child: AnimatedContainer(
              duration: Motion.medium,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [t.accent, const Color(0xFF2FA6A0)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GlassSkeleton extends StatefulWidget {
  const GlassSkeleton({
    super.key,
    this.height = 16,
    this.width,
    this.radius = 8,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  State<GlassSkeleton> createState() => _GlassSkeletonState();
}

class _GlassSkeletonState extends State<GlassSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: t.fill.withOpacity(0.35 + 0.35 * _c.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// ------------------------------------------------------------
/// 玻璃底部弹层 / 弹窗（统一入口，避免各页写法不一）
/// ------------------------------------------------------------
class GlassSheet {
  GlassSheet._();

  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    bool dismissible = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.45),
      enableDrag: dismissible,
      isDismissible: dismissible,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: MediaQuery.of(ctx).padding.bottom + 12,
        ),
        child: GlassPanel(
          radius: R.sheet,
          strong: true,
          blurBoost: 8,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: GlassTokens.of(ctx).stroke,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class GlassDialog {
  GlassDialog._();

  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String okLabel = '确定',
    String cancelLabel = '取消',
    bool danger = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: GlassPanel(
          strong: true,
          blurBoost: 8,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: GlassTokens.of(ctx).text,
                  )),
              const SizedBox(height: 10),
              Text(message,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: GlassTokens.of(ctx).text2,
                  )),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: GlassButton(
                      label: cancelLabel,
                      onTap: () => Navigator.of(ctx).pop(false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _dialogPrimary(ctx, okLabel, danger),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _dialogPrimary(BuildContext ctx, String label, bool danger) {
    final t = GlassTokens.of(ctx);
    return GestureDetector(
      onTap: () => Navigator.of(ctx).pop(true),
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(23),
          gradient: LinearGradient(
            colors: danger
                ? [GlassTokens.danger, const Color(0xFFE0645A)]
                : [t.accent, const Color(0xFF2FA6A0)],
          ),
        ),
        child: Text(label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14.5,
            )),
      ),
    );
  }
}
