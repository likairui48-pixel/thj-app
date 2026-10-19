import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/deeplink.dart';
import 'core/meta.dart';
import 'core/nav.dart';
import 'core/state.dart';
import 'core/ui.dart';
import 'core/update_ui.dart';
import 'pages/bind.dart';
import 'pages/chat.dart';
import 'pages/community.dart';
import 'pages/events.dart';
import 'pages/login.dart';
import 'pages/membership.dart';
import 'pages/player.dart';
import 'pages/profile.dart';
import 'pages/report.dart';
import 'pages/search.dart';
import 'pages/settings.dart';
import 'pages/shell.dart';
import 'pages/smp.dart';
import 'pages/thread.dart';

class ThjApp extends StatefulWidget {
  const ThjApp({super.key});

  @override
  State<ThjApp> createState() => _ThjAppState();
}

class _ThjAppState extends State<ThjApp> with WidgetsBindingObserver {
  final _state = AppState.i;
  bool _dialogsRunning = false;
  bool _annShown = false;
  bool _forceShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _state.addListener(_onState);
    Nav.resolver = _openPath;
    _boot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _state.removeListener(_onState);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _state.setForeground(state == AppLifecycleState.resumed);
  }

  Future<void> _boot() async {
    await _state.init();
    await DeepLinks.init();
  }

  void _onState() {
    if (mounted) setState(() {});
    _maybeDialogs();
  }

  Future<void> _maybeDialogs() async {
    if (!mounted || !_state.booted || _dialogsRunning) return;
    _dialogsRunning = true;
    try {
      if (_state.forceUpdate && _state.update != null && !_forceShown) {
        _forceShown = true;
        await showUpdateDialog(context, _state.update!, force: true);
        return;
      }
      final ann = _state.config.announcement;
      if (ann != null && !_annShown) {
        _annShown = true;
        final sp = await SharedPreferences.getInstance();
        final seen = sp.getString('ann_seen') ?? '';
        if (seen == ann.id) return;
        await sp.setString('ann_seen', ann.id);
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(ann.title),
            content: Text(
              ann.body.isEmpty ? '请留意站点最新公告。' : ann.body,
              style: const TextStyle(height: 1.6),
            ),
            actions: [
              if (ann.link != null && ann.link!.isNotEmpty)
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Nav.to(ann.link!);
                  },
                  child: const Text('查看详情'),
                ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
      }
    } finally {
      _dialogsRunning = false;
    }
  }

  void _openPath(String path) {
    final uri = Uri.tryParse(path);
    if (uri == null) return;
    final p = uri.path;

    if (p == '/chat') {
      final uid = int.tryParse(uri.queryParameters['u'] ?? '');
      Nav.push(ChatPage(userId: uid));
      return;
    }
    if (p.startsWith('/u/')) {
      final name = Uri.decodeComponent(p.substring(3));
      if (name.isNotEmpty) Nav.push(ProfilePage(username: name));
      return;
    }
    if (p.startsWith('/p/')) {
      final name = Uri.decodeComponent(p.substring(3));
      if (name.isNotEmpty) Nav.push(PlayerPage(name: name));
      return;
    }
    final thread = RegExp(r'^/forum/thread/(\d+)').firstMatch(p);
    if (thread != null) {
      Nav.push(ThreadPage(threadId: int.tryParse(thread.group(1)!) ?? 0));
      return;
    }
    if (p.startsWith('/forum')) {
      final board = uri.queryParameters['board'];
      if (board != null && board.isNotEmpty) {
        Nav.push(CommunityPage(initialBoard: board));
      } else {
        Nav.tab('community');
      }
      return;
    }
    if (p.startsWith('/festival') || p.startsWith('/event')) {
      Nav.push(EventsPage(initialTab: uri.queryParameters['tab']));
      return;
    }
    if (p.startsWith('/shop')) {
      Nav.push(const EventsPage(initialTab: 'shop'));
      return;
    }
    if (p.startsWith('/pay') || p.startsWith('/membership')) {
      Nav.push(const MembershipPage());
      return;
    }
    if (p.startsWith('/smp')) {
      Nav.push(const SmpPage());
      return;
    }
    if (p.startsWith('/report')) {
      Nav.push(const ReportPage());
      return;
    }
    if (p.startsWith('/search')) {
      Nav.push(SearchPage(initialQuery: uri.queryParameters['q'] ?? ''));
      return;
    }
    if (p.startsWith('/bind')) {
      Nav.push(const BindPage());
      return;
    }
    if (p.startsWith('/login')) {
      Nav.push(const LoginPage());
      return;
    }
    if (p.startsWith('/settings')) {
      Nav.push(const SettingsPage());
      return;
    }
    if (p.startsWith('/me') || p.startsWith('/profile')) {
      Nav.tab('me');
      return;
    }
    if (p.startsWith('/rank') || p.startsWith('/leaderboard')) {
      Nav.tab('rank');
      return;
    }
    if (p.startsWith('/messages')) {
      Nav.tab('messages');
      return;
    }
    // 未内置的路径：用系统浏览器兜底（如 /admin、协议页）
    final url = Uri.tryParse('${AppMeta.baseUrl}$path');
    if (url != null) {
      launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppMeta.appName,
      debugShowCheckedModeBanner: false,
      navigatorKey: Nav.key,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _state.themeMode,
      home: _state.booted ? const Shell() : const SplashPage(),
      builder: (context, child) {
        final brightness = Theme.of(context).brightness;
        final dark = brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            statusBarIconBrightness:
                dark ? Brightness.light : Brightness.dark,
            systemNavigationBarIconBrightness:
                dark ? Brightness.light : Brightness.dark,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final glow = 12.0 + 22.0 * _c.value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 92,
                  height: 92,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.brand, AppColors.teal],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brand.withOpacity(0.35),
                        blurRadius: glow,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Text(
                    '禾',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  AppMeta.appName,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 5,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '正在连接同禾境…',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
