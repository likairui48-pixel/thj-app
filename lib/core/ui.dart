import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'api.dart';

/* ============================================================
 * 品牌色 / 主题
 * ============================================================ */

class AppColors {
  AppColors._();
  static const Color brand = Color(0xFF2E9E63);
  static const Color brandDeep = Color(0xFF1E7C4A);
  static const Color teal = Color(0xFF2FA6A0);
  static const Color danger = Color(0xFFD0473D);
  static const Color warning = Color(0xFFD08A1C);
  static const Color gold = Color(0xFFD9A441);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: brightness,
    );
    final cs = base.copyWith(
      primary: AppColors.brand,
      onPrimary: Colors.white,
      secondary: AppColors.teal,
      onSecondary: Colors.white,
      surface: isDark ? const Color(0xFF141A16) : Colors.white,
      onSurface: isDark ? const Color(0xFFF1F6F2) : const Color(0xFF15201A),
      onSurfaceVariant:
          isDark ? const Color(0xFF9AA9A0) : const Color(0xFF66766C),
      outline: isDark ? const Color(0xFF53645A) : const Color(0xFF8C9C92),
      outlineVariant:
          isDark ? const Color(0xFF28342C) : const Color(0xFFE0E7E1),
      error: AppColors.danger,
      onError: Colors.white,
      surfaceTint: AppColors.brand,
    );

    final bg = isDark ? const Color(0xFF0A0E0B) : const Color(0xFFF4F7F2);
    final inputFill =
        isDark ? const Color(0xFF1B231E) : const Color(0xFFEDF2EC);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: cs,
      scaffoldBackgroundColor: bg,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: cs.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: cs.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: cs.onSurface, size: 22),
      ),
      cardTheme: CardTheme(
        color: cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: cs.outlineVariant),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: cs.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 13.5),
        labelStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.brand, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.onSurface,
          minimumSize: const Size(0, 44),
          side: BorderSide(color: cs.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brand,
          textStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: inputFill,
        selectedColor: AppColors.brand.withOpacity(0.14),
        side: BorderSide(color: cs.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        labelStyle: TextStyle(
          color: cs.onSurface,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cs.surface,
        elevation: 0,
        height: 70,
        indicatorColor: AppColors.brand.withOpacity(0.14),
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(size: 23, color: cs.onSurfaceVariant),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF26312A) : const Color(0xFF1C2921),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brand,
      ),
    );
  }
}

/* ============================================================
 * 页面骨架
 * ============================================================ */

class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    this.title,
    required this.child,
    this.actions,
    this.leading,
    this.bottom,
    this.fab,
    this.autoBack = true,
    this.resizeToAvoidBottomInset = true,
  });

  final String? title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? leading;
  final Widget? bottom;
  final Widget? fab;
  final bool autoBack;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: cs.surface,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: title == null
          ? null
          : AppBar(
              title: Text(title!),
              actions: actions,
              leading: leading ??
                  (autoBack && canPop ? const BackButton() : null),
            ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark
                ? const [Color(0xFF111813), Color(0xFF080B09)]
                : const [Color(0xFFF7FAF5), Color(0xFFF0F4EE)],
          ),
        ),
        child: SafeArea(top: title == null, child: child),
      ),
      bottomNavigationBar: bottom,
      floatingActionButton: fab,
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.onLongPress,
    this.color,
    this.radius = 18,
    this.border = true,
    this.clip = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final double radius;
  final bool border;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final content = Container(
      decoration: BoxDecoration(
        color: color ?? cs.surface,
        borderRadius: BorderRadius.circular(radius),
        border: border ? Border.all(color: cs.outlineVariant) : null,
      ),
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null && onLongPress == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: content,
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.sub,
    this.trailing,
  });

  final String title;
  final String? sub;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 20, 2, 10),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.brand,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (sub != null && sub!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      sub!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/* ============================================================
 * 状态视图
 * ============================================================ */

class AsyncView extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.child,
    this.isEmpty = false,
    this.emptyText = '这里还什么都没有',
    this.emptyIcon = Icons.inbox_rounded,
  });

  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final Widget child;
  final bool isEmpty;
  final String emptyText;
  final IconData emptyIcon;

  @override
  Widget build(BuildContext context) {
    if (error != null && !loading) {
      return ErrorView(message: error!, onRetry: onRetry);
    }
    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    }
    if (isEmpty) return EmptyView(text: emptyText, icon: emptyIcon);
    return child;
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.text,
    this.icon = Icons.inbox_rounded,
    this.action,
  });

  final String text;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: cs.onSurfaceVariant, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 14),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, color: cs.onSurfaceVariant, size: 32),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 13,
                height: 1.55,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('重试'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/* ============================================================
 * 通用小组件
 * ============================================================ */

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.avatar,
    this.size = 44,
    this.online = false,
    this.onTap,
    this.ring = false,
  });

  final String name;
  final String? avatar;
  final double size;
  final bool online;
  final VoidCallback? onTap;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final url = (avatar != null && avatar!.isNotEmpty)
        ? Api.i.abs(avatar!)
        : Api.i.avatarUrl(name, size: (size * 2).round());
    final image = ClipOval(
      child: Container(
        width: size,
        height: size,
        color: cs.surfaceContainerHighest,
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => Center(
            child: Text(
              name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.4,
              ),
            ),
          ),
        ),
      ),
    );
    final body = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: ring ? const EdgeInsets.all(2) : EdgeInsets.zero,
          decoration: ring
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.brand, width: 1.6),
                )
              : null,
          child: image,
        ),
        if (online)
          Positioned(
            right: 1,
            bottom: 1,
            child: Container(
              width: size * 0.24,
              height: size * 0.24,
              decoration: BoxDecoration(
                color: AppColors.brand,
                shape: BoxShape.circle,
                border: Border.all(color: cs.surface, width: 2),
              ),
            ),
          ),
      ],
    );
    if (onTap == null) return body;
    return GestureDetector(onTap: onTap, child: body);
  }
}

class NetImage extends StatelessWidget {
  const NetImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius = 14,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        Api.i.abs(url),
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (c, child, progress) {
          if (progress == null) return child;
          return Container(
            width: width,
            height: height,
            color: cs.surfaceContainerHighest,
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (c, e, s) => Container(
          width: width,
          height: height,
          color: cs.surfaceContainerHighest,
          child: Icon(
            Icons.broken_image_outlined,
            color: cs.onSurfaceVariant,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class AnyImage extends StatelessWidget {
  const AnyImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius = 12,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget child;
    if (url.startsWith('data:')) {
      try {
        final raw = url.substring(url.indexOf(',') + 1);
        child = Image.memory(
          base64Decode(raw),
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (c, e, s) => Container(
            width: width,
            height: height,
            color: cs.surfaceContainerHighest,
            child: Icon(Icons.broken_image_outlined,
                color: cs.onSurfaceVariant, size: 20),
          ),
        );
      } catch (_) {
        child = Container(
          width: width,
          height: height,
          color: cs.surfaceContainerHighest,
        );
      }
    } else {
      child = Image.network(
        Api.i.abs(url),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (c, e, s) => Container(
          width: width,
          height: height,
          color: cs.surfaceContainerHighest,
          child: Icon(Icons.broken_image_outlined,
              color: cs.onSurfaceVariant, size: 20),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: child,
    );
  }
}

class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.text,
    this.color = AppColors.brand,
    this.icon,
    this.filled = false,
  });

  final String text;
  final Color color;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color : color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: filled ? color : color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11.5, color: filled ? Colors.white : color),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              color: filled ? Colors.white : color,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class TierPill extends StatelessWidget {
  const TierPill({super.key, required this.tier, this.showScore = false});
  final Map<String, dynamic> tier;
  final bool showScore;

  @override
  Widget build(BuildContext context) {
    final color = parseColor(asStr(tier['color']), AppColors.brand);
    final label = asStr(tier['label'] ?? tier['key'], '段位');
    final score = asInt(tier['score']);
    return Pill(
      text: showScore && score > 0 ? '$label · $score' : label,
      color: color,
    );
  }
}

class RolePill extends StatelessWidget {
  const RolePill({super.key, required this.role, this.isAdmin = false});
  final String role;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final r = isAdmin && role == 'user' ? 'admin' : role;
    switch (r) {
      case 'owner':
        return const Pill(text: '服主', color: AppColors.gold, icon: Icons.star_rounded);
      case 'admin':
        return const Pill(text: '管理', color: AppColors.danger);
      case 'moderator':
      case 'mod':
        return const Pill(text: '版主', color: AppColors.teal);
      default:
        return const SizedBox.shrink();
    }
  }
}

class MembershipPill extends StatelessWidget {
  const MembershipPill({super.key, required this.membership});
  final Map<String, dynamic> membership;

  @override
  Widget build(BuildContext context) {
    if (membership.isEmpty) return const SizedBox.shrink();
    final label = asStr(membership['label'] ?? membership['group']);
    if (label.isEmpty) return const SizedBox.shrink();
    final color = parseColor(asStr(membership['color']), AppColors.gold);
    return Pill(text: label, color: color, icon: Icons.workspace_premium_rounded);
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.onSurface;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: c.withOpacity(0.8)),
            const SizedBox(height: 6),
          ],
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: c,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: color ?? cs.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.icon,
    required this.title,
    this.sub,
    this.trailing,
    this.onTap,
    this.color,
  });

  final IconData icon;
  final String title;
  final String? sub;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (color ?? AppColors.brand).withOpacity(0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: color ?? AppColors.brand, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (sub != null && sub!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      sub!,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: cs.onSurfaceVariant,
                  size: 20,
                ),
          ],
        ),
      ),
    );
  }
}

class AsyncButton extends StatefulWidget {
  const AsyncButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = true,
    this.expand = true,
    this.height = 46,
  });

  final String label;
  final Future<void> Function()? onPressed;
  final IconData? icon;
  final bool primary;
  final bool expand;
  final double height;

  @override
  State<AsyncButton> createState() => _AsyncButtonState();
}

class _AsyncButtonState extends State<AsyncButton> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy || widget.onPressed == null) return;
    setState(() => _busy = true);
    try {
      await widget.onPressed!();
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = _busy
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.primary ? Colors.white : AppColors.brand,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 18),
                const SizedBox(width: 7),
              ],
              Text(widget.label),
            ],
          );
    final button = widget.primary
        ? FilledButton(
            onPressed: widget.onPressed == null || _busy ? null : _run,
            child: child,
          )
        : OutlinedButton(
            onPressed: widget.onPressed == null || _busy ? null : _run,
            child: child,
          );
    final sized = SizedBox(height: widget.height, child: button);
    return widget.expand ? SizedBox(width: double.infinity, child: sized) : sized;
  }
}

/* ============================================================
 * 弹层 / 提示
 * ============================================================ */

Future<T?> showAppSheet<T>(
  BuildContext context, {
  required Widget child,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: SafeArea(top: false, child: child),
      );
    },
  );
}

Future<bool> showConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String okText = '确认',
  String cancelText = '取消',
  bool danger = false,
}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message, style: const TextStyle(height: 1.55)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelText),
        ),
        FilledButton(
          style: danger
              ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(okText),
        ),
      ],
    ),
  );
  return res ?? false;
}

void showImageViewer(BuildContext context, List<String> urls, int index) {
  if (urls.isEmpty) return;
  var i = index.clamp(0, urls.length - 1);
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.94),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 5,
                child: Center(
                  child: AnyImage(
                    url: urls[i],
                    fit: BoxFit.contain,
                    radius: 0,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 20,
              right: 12,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
            if (urls.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 30,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: i > 0 ? () => setSt(() => i--) : null,
                      icon: const Icon(Icons.chevron_left_rounded,
                          color: Colors.white, size: 30),
                    ),
                    Text(
                      '${i + 1} / ${urls.length}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    IconButton(
                      onPressed: i < urls.length - 1
                          ? () => setSt(() => i++)
                          : null,
                      icon: const Icon(Icons.chevron_right_rounded,
                          color: Colors.white, size: 30),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

void showToast(BuildContext context, String message, {bool error = false}) {
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : null,
        duration: Duration(seconds: error ? 4 : 2),
      ),
    );
}

/* ============================================================
 * 格式化
 * ============================================================ */

String fmtAgo(dynamic ms) {
  final v = asInt(ms);
  if (v <= 0) return '';
  final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(v));
  if (d.inSeconds < 60) return '刚刚';
  if (d.inMinutes < 60) return '${d.inMinutes} 分钟前';
  if (d.inHours < 24) return '${d.inHours} 小时前';
  if (d.inDays == 1) return '昨天';
  if (d.inDays < 7) return '${d.inDays} 天前';
  final dt = DateTime.fromMillisecondsSinceEpoch(v);
  return '${dt.month}-${dt.day.toString().padLeft(2, '0')}';
}

String fmtTime(dynamic ms) {
  final v = asInt(ms);
  if (v <= 0) return '';
  final dt = DateTime.fromMillisecondsSinceEpoch(v);
  return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

String fmtDate(dynamic ms) {
  final v = asInt(ms);
  if (v <= 0) return '—';
  final dt = DateTime.fromMillisecondsSinceEpoch(v);
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

String fmtDateTime(dynamic ms) {
  final v = asInt(ms);
  if (v <= 0) return '—';
  final dt = DateTime.fromMillisecondsSinceEpoch(v);
  return '${dt.month}-${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

String fmtNumber(dynamic v) {
  final n = asInt(v);
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return n < 0 ? '-$b' : b.toString();
}

String fmtMoney(int cents) {
  if (cents <= 0) return '免费';
  final v = cents / 100;
  return v == v.roundToDouble()
      ? '¥${v.toStringAsFixed(0)}'
      : '¥${v.toStringAsFixed(2)}';
}

String fmtCountdown(int ms) {
  if (ms <= 0) return '已结束';
  final d = ms ~/ 86400000;
  final h = (ms % 86400000) ~/ 3600000;
  final m = (ms % 3600000) ~/ 60000;
  final s = (ms % 60000) ~/ 1000;
  if (d > 0) return '$d 天 ${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

Color parseColor(String? s, [Color def = AppColors.brand]) {
  if (s == null || s.isEmpty) return def;
  var h = s.replaceAll('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  return v == null ? def : Color(v);
}

String roleLabel(String role) {
  switch (role) {
    case 'owner':
      return '服主';
    case 'admin':
      return '管理员';
    case 'moderator':
    case 'mod':
      return '版主';
    default:
      return '成员';
  }
}

String statusLabel(String status) {
  switch (status) {
    case 'pending':
      return '待付款';
    case 'paid':
      return '已付款';
    case 'shipped':
      return '已发货';
    case 'done':
      return '已完成';
    case 'closed':
      return '已关闭';
    case 'cancelled':
      return '已取消';
    default:
      return status.isEmpty ? '未知' : status;
  }
}

Color statusColor(String status) {
  switch (status) {
    case 'pending':
      return AppColors.warning;
    case 'paid':
      return AppColors.teal;
    case 'shipped':
      return AppColors.brand;
    case 'done':
      return AppColors.brand;
    case 'closed':
    case 'cancelled':
      return Colors.grey;
    default:
      return Colors.grey;
  }
}
