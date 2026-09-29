import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../app/theme.dart';
import '../core/api.dart';
import '../core/update.dart';
import '../widgets/glass.dart';

/// ============================================================
///  网页容器：登录 / 充值 / 论坛详情 / 完整主页 等复用
///  关键：把 App 的会话 Cookie 注入 WebView，做到「一次登录，全站通用」
///  站点 Cookie 名：mcw_sid（httpOnly、SameSite=Lax，有效期 7 天）
/// ============================================================
class WebPage extends StatefulWidget {
  const WebPage({
    super.key,
    required this.title,
    required this.path,
    this.absolute = false,
  });

  final String title;
  /// 站内路径（如 /login）或绝对地址（absolute = true）
  final String path;
  final bool absolute;

  @override
  State<WebPage> createState() => _WebPageViewState();
}

class _WebPageViewState extends State<WebPage> {
  late final WebViewController _c;
  int _progress = 0;
  bool _failed = false;
  String _currentTitle = '';
  bool _canGoBack = false;

  @override
  void initState() {
    super.initState();
    _currentTitle = widget.title;
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _failed = false;
                _progress = 0;
              });
            }
          },
          onPageFinished: (url) async {
            final can = await _c.canGoBack();
            final title = await _c.getTitle();
            if (!mounted) return;
            setState(() {
              _canGoBack = can;
              if (title != null && title.trim().isNotEmpty) {
                _currentTitle = title.trim();
              }
            });
          },
          onWebResourceError: (e) {
            // 只处理主文档失败，子资源失败忽略
            if (e.isForMainFrame == false) return;
            if (mounted) setState(() => _failed = true);
          },
        ),
      );
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Api.i.load();
    final url = widget.absolute
        ? widget.path
        : '${Api.i.base}${widget.path}';
    await _injectCookie(url);
    await _c.loadRequest(Uri.parse(url));
  }

  /// 把 App 侧会话 Cookie 写入 WebView 的 Cookie 存储
  Future<void> _injectCookie(String url) async {
    final raw = Api.i.cookieRaw;
    if (raw == null || raw.isEmpty) return;
    final host = Uri.tryParse(url)?.host;
    if (host == null || host.isEmpty) return;
    try {
      final manager = WebViewCookieManager();
      for (final part in raw.split(';')) {
        final kv = part.trim().split('=');
        if (kv.length < 2) continue;
        final name = kv[0].trim();
        final value = kv.sublist(1).join('=').trim();
        if (name.isEmpty || value.isEmpty) continue;
        await manager.setCookie(
          WebViewCookie(name: name, value: value, domain: host, path: '/'),
        );
      }
    } catch (_) {
      // 注入失败不阻塞浏览（用户仍可在网页里重新登录）
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Row(
                children: [
                  GlassIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () async {
                      if (_canGoBack) {
                        await _c.goBack();
                      } else if (mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: t.text,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          Uri.tryParse('${Api.i.base}${widget.path}')?.host ??
                              '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: t.text3, fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                  GlassIconButton(
                    icon: Icons.refresh_rounded,
                    onTap: () => _c.reload(),
                  ),
                  const SizedBox(width: 8),
                  GlassIconButton(
                    icon: Icons.open_in_browser_rounded,
                    onTap: () => UpdateService.openUrl(
                      widget.absolute
                          ? widget.path
                          : '${Api.i.base}${widget.path}',
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 2,
              child: _progress > 0 && _progress < 100
                  ? LinearProgressIndicator(
                      value: _progress / 100,
                      minHeight: 2,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(t.accent),
                    )
                  : null,
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(R.sheet),
                ),
                child: _failed
                    ? _errorView(t)
                    : WebViewWidget(controller: _c),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView(GlassTokens t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: GlassPanel(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 32, color: t.text3),
              const SizedBox(height: 12),
              Text('网页加载失败',
                  style: TextStyle(
                      color: t.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                '检查一下网络，或到「我的 → 服务器设置」换个访问地址',
                textAlign: TextAlign.center,
                style: TextStyle(color: t.text3, fontSize: 12.5, height: 1.5),
              ),
              const SizedBox(height: 16),
              GlassButton(
                label: '重新加载',
                icon: Icons.refresh_rounded,
                expand: false,
                onTap: () {
                  setState(() => _failed = false);
                  _c.reload();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 内嵌网页（用于底部 Tab 里的「社区」，没有返回按钮）
class WebInline extends StatefulWidget {
  const WebInline({super.key, required this.title, required this.path});

  final String title;
  final String path;

  @override
  State<WebInline> createState() => _WebInlineState();
}

class _WebInlineState extends State<WebInline> {
  late final WebViewController _c;
  int _progress = 0;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _failed = false;
                _progress = 0;
              });
            }
          },
          onWebResourceError: (e) {
            if (e.isForMainFrame == false) return;
            if (mounted) setState(() => _failed = true);
          },
        ),
      );
    _boot();
  }

  Future<void> _boot() async {
    await Api.i.load();
    final url = '${Api.i.base}${widget.path}';
    final raw = Api.i.cookieRaw;
    final host = Uri.tryParse(url)?.host;
    if (raw != null && raw.isNotEmpty && host != null) {
      try {
        final manager = WebViewCookieManager();
        for (final part in raw.split(';')) {
          final kv = part.trim().split('=');
          if (kv.length < 2) continue;
          await manager.setCookie(WebViewCookie(
            name: kv[0].trim(),
            value: kv.sublist(1).join('=').trim(),
            domain: host,
            path: '/',
          ));
        }
      } catch (_) {}
    }
    await _c.loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            R.page,
            MediaQuery.of(context).padding.top + 10,
            R.page,
            6,
          ),
          child: Row(
            children: [
              Text(widget.title,
                  style: TextStyle(
                      color: t.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1)),
              const Spacer(),
              GlassIconButton(
                icon: Icons.refresh_rounded,
                size: 38,
                onTap: () => _c.reload(),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 2,
          child: _progress > 0 && _progress < 100
              ? LinearProgressIndicator(
                  value: _progress / 100,
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(t.accent),
                )
              : null,
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(R.sheet),
            ),
            child: _failed
                ? Center(
                    child: GlassButton(
                      label: '网页加载失败，点我重试',
                      icon: Icons.refresh_rounded,
                      expand: false,
                      onTap: () {
                        setState(() => _failed = false);
                        _c.reload();
                      },
                    ),
                  )
                : WebViewWidget(controller: _c),
          ),
        ),
        SizedBox(height: GlassPillNav.reserved(context) - 40),
      ],
    );
  }
}
