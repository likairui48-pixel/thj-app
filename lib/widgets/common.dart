import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'glass.dart';

/// 四态容器：加载 / 错误 / 空 / 数据
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
    this.skeleton,
  });

  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final Widget child;
  final bool isEmpty;
  final String emptyText;
  final IconData emptyIcon;
  final Widget? skeleton;

  @override
  Widget build(BuildContext context) {
    if (error != null && !loading) {
      return ErrorHint(message: error!, onRetry: onRetry);
    }
    if (loading && skeleton != null) return skeleton!;
    if (isEmpty) return EmptyHint(text: emptyText, icon: emptyIcon);
    return child;
  }
}

class ErrorHint extends StatelessWidget {
  const ErrorHint({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    return GlassPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded, size: 30, color: t.text3),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: t.text2, fontSize: 13.5, height: 1.5),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            GlassButton(
              label: '重试',
              icon: Icons.refresh_rounded,
              expand: false,
              height: 40,
              onTap: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}

class EmptyHint extends StatelessWidget {
  const EmptyHint({super.key, required this.text, this.icon = Icons.inbox_rounded});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    return GlassPanel(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 18),
      child: Column(
        children: [
          Icon(icon, size: 30, color: t.text3),
          const SizedBox(height: 10),
          Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(color: t.text3, fontSize: 13.5)),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.sub, this.trailing});

  final String title;
  final String? sub;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 3,
            height: 15,
            decoration: BoxDecoration(
              color: t.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                color: t.text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              )),
          if (sub != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(sub!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: t.text3, fontSize: 12)),
            ),
          ] else
            const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.highlight = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    return GlassPanel(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            Icon(icon, size: 16, color: highlight ? t.accent : t.text3),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: highlight ? t.accent : t.text,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: t.text3)),
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: t.text3, fontSize: 13)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color ?? t.text,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 玩家头像：优先站点头像接口，失败退化为首字母
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.name,
    this.size = 44,
    this.online = false,
    this.ring = true,
  });

  final String name;
  final double size;
  final bool online;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    final raw = name.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '');
    final url = raw.length >= 3
        ? '${_baseOf(context)}$raw?size=${(size * 2).round()}'
        : null;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: t.fillStrong,
        border: ring
            ? Border.all(
                color: online ? t.accent : t.stroke,
                width: online ? 2 : 1,
              )
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url != null)
            Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallback(t),
              loadingBuilder: (ctx, child, p) =>
                  p == null ? child : _fallback(t),
            )
          else
            _fallback(t),
          if (online)
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                width: size * 0.26,
                height: size * 0.26,
                margin: EdgeInsets.all(size * 0.04),
                decoration: BoxDecoration(
                  color: t.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: t.bgBottom, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fallback(GlassTokens t) => Center(
        child: Text(
          name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
          style: TextStyle(
            color: t.text2,
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  static String _baseOf(BuildContext ctx) {
    return AvatarBase.value;
  }
}

/// 头像基地址（由 main 注入，避免在 widget 里直接依赖 Api 造成循环引用）
class AvatarBase {
  AvatarBase._();
  static String value = '';
}

/// 相对时间：刚刚 / 5 分钟前 / 昨天 / 03-12
String relTime(int? ms) {
  if (ms == null || ms <= 0) return '—';
  final dt = DateTime.fromMillisecondsSinceEpoch(ms);
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
  if (diff.inHours < 24) return '${diff.inHours} 小时前';
  if (diff.inDays == 1) return '昨天';
  if (diff.inDays < 7) return '${diff.inDays} 天前';
  return '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

/// 时长：12.5 小时 / 340 小时
String hoursText(double h) {
  if (h <= 0) return '—';
  if (h < 10) return '${h.toStringAsFixed(1)} 小时';
  return '${h.round()} 小时';
}

/// 大数字缩写：1234 → 1.2k
String shortNum(num n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
  return n.toString();
}
