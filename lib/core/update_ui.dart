import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'state.dart';
import 'ui.dart';

Future<void> showUpdateDialog(
  BuildContext context,
  UpdateInfo info, {
  bool force = false,
}) async {
  final cs = Theme.of(context).colorScheme;
  await showDialog<void>(
    context: context,
    barrierDismissible: !force,
    builder: (ctx) => PopScope(
      canPop: !force,
      child: AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.system_update_alt_rounded,
                color: AppColors.brand, size: 22),
            const SizedBox(width: 8),
            Text('新版本 ${info.version}'),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                force
                    ? '当前版本过旧，需要更新后才能继续使用。'
                    : '有新的版本可用，更新后体验更完整。',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 12.5,
                  height: 1.55,
                ),
              ),
              if (info.notes.isNotEmpty) ...[
                const SizedBox(height: 14),
                ...info.notes.map(
                  (n) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('· ', style: TextStyle(color: AppColors.brand)),
                        Expanded(
                          child: Text(
                            n,
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 12.5,
                              height: 1.55,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (info.sizeLabel.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '安装包 ${info.sizeLabel}',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11.5),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (!force)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('稍后'),
            ),
          if (force)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('我已下载'),
            ),
          FilledButton.icon(
            onPressed: () async {
              final url = info.url;
              if (url == null || url.isEmpty) {
                showToast(ctx, '下载地址暂未配置', error: true);
                return;
              }
              final uri = Uri.tryParse(url);
              if (uri == null) return;
              final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
              if (!ok && ctx.mounted) {
                showToast(ctx, '无法打开下载页面，请复制链接到浏览器', error: true);
              }
            },
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('去下载'),
          ),
        ],
      ),
    ),
  );
}
