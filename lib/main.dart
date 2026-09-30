import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/config.dart';
import 'app/theme.dart';
import 'core/api.dart';
import 'core/store.dart';
import 'pages/shell.dart';
import 'widgets/common.dart';
import 'widgets/glass.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ThjApp());
}

class ThjApp extends StatefulWidget {
  const ThjApp({super.key});

  @override
  State<ThjApp> createState() => _ThjAppState();
}

class _ThjAppState extends State<ThjApp> with WidgetsBindingObserver {
  final _state = AppState.i;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _state.addListener(_onChange);
    _boot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _state.removeListener(_onChange);
    super.dispose();
  }

  /// 前后台切换：后台时才能弹系统通知，也决定要不要保活
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    _state.setForeground(s == AppLifecycleState.resumed);
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _boot() async {
    await _state.boot();
    AvatarBase.value = '${Api.i.base}/api/avatar/';
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppMeta.appName,
      debugShowCheckedModeBanner: false,
      navigatorKey: NavBus.i.navKey,
      theme: ThjTheme.light(),
      darkTheme: ThjTheme.dark(),
      themeMode: _state.themeMode,
      builder: (context, child) {
        // 记录系统深浅色偏好（供「跟随系统」判断）
        final brightness = MediaQuery.platformBrightnessOf(context);
        Platform9.isDarkPreferred = brightness == Brightness.dark;
        // 让状态栏图标颜色跟随主题
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: _state.booted ? const Shell() : const SplashScreen(),
    );
  }
}

/// 启动页：logo + 品牌绿光晕 + 加载进度
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    return AuroraBg(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final glow = 16.0 + 16.0 * _c.value;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2E9E63), Color(0xFF2FA6A0)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: t.accent.withOpacity(0.45),
                          blurRadius: glow,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Text(
                      '禾',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    AppMeta.appName,
                    style: TextStyle(
                      color: t.text,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '正在连接服务器…',
                    style: TextStyle(color: t.text3, fontSize: 12.5),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
