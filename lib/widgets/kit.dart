import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/api.dart';
import '../core/img.dart';
import 'glass.dart';

/// 相对时间：刚刚 / n分钟前 / n小时前 / 昨天 / n天前 / 月-日
String ago(dynamic ms) {
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

/// 金额：分 → 元
String yuan(int cents) {
  if (cents <= 0) return '免费';
  final v = cents / 100;
  return v == v.roundToDouble() ? '¥${v.round()}' : '¥${v.toStringAsFixed(2)}';
}

/// 全屏看图（可缩放）
void showImageViewer(BuildContext context, String url, [List<String>? all]) {
  final list = (all == null || all.isEmpty) ? <String>[url] : all;
  var i = list.indexOf(url);
  if (i < 0) i = 0;
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
                  child: Image.network(
                    Api.i.abs(list[i]),
                    fit: BoxFit.contain,
                    errorBuilder: (c, e, s) => const Text('图片加载失败',
                        style: TextStyle(color: Colors.white70)),
                  ),
                ),
              ),
            ),
            if (list.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 26,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: i > 0 ? () => setSt(() => i--) : null,
                      icon: const Icon(Icons.chevron_left_rounded,
                          color: Colors.white, size: 30),
                    ),
                    Text('${i + 1} / ${list.length}',
                        style: const TextStyle(color: Colors.white70)),
                    IconButton(
                      onPressed: i < list.length - 1
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

/// 图片九宫格（点开看大图）
class ImageGrid extends StatelessWidget {
  const ImageGrid({super.key, required this.urls, this.height = 108});

  final List<String> urls;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    if (urls.isEmpty) return const SizedBox.shrink();
    final all = urls.map((e) => Api.i.abs(e)).toList();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: urls.map((u) {
        final full = Api.i.abs(u);
        return GestureDetector(
          onTap: () => showImageViewer(context, full, all),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(R.tile - 4),
            child: Container(
              width: urls.length == 1 ? 200 : 100,
              height: height,
              color: t.fill,
              child: Image.network(full,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Icon(Icons.broken_image_rounded,
                      color: t.text3, size: 22)),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// 发帖/回复用的选图条：缩略图 + 加号 + 删除
class ImagePickerStrip extends StatelessWidget {
  const ImagePickerStrip({
    super.key,
    required this.images,
    required this.onChanged,
    this.max = 3,
  });

  final List<String> images;
  final ValueChanged<List<String>> onChanged;
  final int max;

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < images.length; i++)
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(R.tile - 4),
                child: Image.network(Api.i.abs(images[i]),
                    width: 74,
                    height: 74,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) =>
                        Container(width: 74, height: 74, color: t.fill)),
              ),
              Positioned(
                right: -6,
                top: -6,
                child: GestureDetector(
                  onTap: () {
                    final next = List<String>.from(images)..removeAt(i);
                    onChanged(next);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: t.bgTop.withOpacity(0.9),
                      shape: BoxShape.circle,
                      border: Border.all(color: t.stroke),
                    ),
                    child: Icon(Icons.close_rounded, size: 13, color: t.text),
                  ),
                ),
              ),
            ],
          ),
        if (images.length < max)
          GestureDetector(
            onTap: () async {
              final d = await Img.pickDataUrl(maxEdge: 1400, quality: 82);
              if (d == null) return;
              onChanged([...images, d]);
            },
            child: Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: t.fill,
                borderRadius: BorderRadius.circular(R.tile - 4),
                border: Border.all(color: t.stroke),
              ),
              child: Icon(Icons.add_photo_alternate_outlined,
                  color: t.text3, size: 24),
            ),
          ),
      ],
    );
  }
}

/// 会员 / 身份小徽章
class MiniBadge extends StatelessWidget {
  const MiniBadge({super.key, required this.text, this.color, this.icon});

  final String text;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    final c = color ?? t.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: c.withOpacity(0.16),
        borderRadius: BorderRadius.circular(R.pill),
        border: Border.all(color: c.withOpacity(0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10.5, color: c),
            const SizedBox(width: 3),
          ],
          Text(text,
              style: TextStyle(
                  color: c, fontSize: 10.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// 统一的「作者一行」：头像 + 名字 + 徽章 + 时间
class AuthorRow extends StatelessWidget {
  const AuthorRow({
    super.key,
    required this.username,
    this.avatar,
    this.time,
    this.badges = const <Widget>[],
    this.onTap,
    this.trailing,
    this.avatarSize = 34,
  });

  final String username;
  final String? avatar;
  final dynamic time;
  final List<Widget> badges;
  final VoidCallback? onTap;
  final Widget? trailing;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    final av = (avatar != null && avatar!.isNotEmpty)
        ? Api.i.abs(avatar!)
        : Api.i.avatarUrl(username, size: 72);
    return Row(
      children: [
        GestureDetector(
          onTap: onTap,
          child: ClipOval(
            child: Container(
              width: avatarSize,
              height: avatarSize,
              color: t.fill,
              child: Image.network(av,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Center(
                        child: Text(
                          username.isEmpty ? '?' : username.substring(0, 1),
                          style: TextStyle(
                              color: t.text2,
                              fontSize: avatarSize * 0.42,
                              fontWeight: FontWeight.w700),
                        ),
                      )),
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: onTap,
                child: Row(
                  children: [
                    Flexible(
                      child: Text(username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: t.text,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600)),
                    ),
                    for (final b in badges) ...[
                      const SizedBox(width: 5),
                      b,
                    ],
                  ],
                ),
              ),
              if (time != null)
                Text(ago(time),
                    style: TextStyle(color: t.text3, fontSize: 11)),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
