import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/config.dart';
import '../app/theme.dart';
import 'api.dart';
import 'notify.dart';

/// ============================================================
///  全局状态：设置 / 会话 / 首页状态 / 未读消息
///  刻意只用 ChangeNotifier（不引第三方状态库，减少构建风险）
/// ============================================================
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState i = AppState._();

  // ---------- 设置 ----------
  ThemeMode themeMode = ThemeMode.dark;
  bool showFakes = false;
  bool notifyEnabled = true;
  bool reduceMotion = false;

  // ---------- 数据 ----------
  ServerStatus? status;
  SeasonInfo? season;
  MeInfo? me;
  UnreadInfo unread = const UnreadInfo();
  List<NotifItem> notifs = const <NotifItem>[];

  // ---------- 视图状态 ----------
  bool booted = false;
  bool loadingStatus = false;
  String? statusError;
  String? unreadError;

  Timer? _statusTimer;
  Timer? _unreadTimer;
  int _lastUnreadTotal = 0;
  bool _firstUnreadPass = true;

  SharedPreferences? _sp;

  // ---------------- 启动 ----------------
  Future<void> boot() async {
    _sp = await SharedPreferences.getInstance();
    final s = _sp!;
    themeMode = _parseTheme(s.getString('theme_mode'));
    showFakes = s.getBool('show_fakes') ?? false;
    notifyEnabled = s.getBool('notify_enabled') ?? true;
    reduceMotion = s.getBool('reduce_motion') ?? false;
    Motion.reduce = reduceMotion;

    await Api.i.load();
    await NotifyService.i.init(onTap: _onNotifyTap);

    booted = true;
    notifyListeners();

    await refreshBrandAndMe();
    refreshStatus();
    refreshUnread();
    _startTimers();
  }

  static ThemeMode _parseTheme(String? v) {
    switch (v) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  void _startTimers() {
    _statusTimer?.cancel();
    _unreadTimer?.cancel();
    _statusTimer = Timer.periodic(RefreshPolicy.statusMin, (_) {
      refreshStatus(silent: true);
    });
    _unreadTimer = Timer.periodic(RefreshPolicy.unread, (_) {
      refreshUnread(silent: true);
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _unreadTimer?.cancel();
    super.dispose();
  }

  // ---------------- 设置写入 ----------------
  Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    notifyListeners();
    await _sp?.setString(
        'theme_mode', m == ThemeMode.light ? 'light' : (m == ThemeMode.dark ? 'dark' : 'system'));
  }

  Future<void> toggleTheme() async {
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system && Platform9.isDarkPreferred);
    await setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> setShowFakes(bool v) async {
    showFakes = v;
    notifyListeners();
    await _sp?.setBool('show_fakes', v);
    await refreshStatus();
  }

  Future<void> setNotifyEnabled(bool v) async {
    notifyEnabled = v;
    notifyListeners();
    await _sp?.setBool('notify_enabled', v);
    if (v) await NotifyService.i.ensurePermission();
  }

  Future<void> setReduceMotion(bool v) async {
    reduceMotion = v;
    Motion.reduce = v;
    notifyListeners();
    await _sp?.setBool('reduce_motion', v);
  }

  // ---------------- 数据刷新 ----------------
  Future<void> refreshStatus({bool silent = false}) async {
    if (loadingStatus) return;
    loadingStatus = true;
    if (!silent) notifyListeners();
    try {
      final j = await Api.i.status(showFakes: showFakes);
      status = ServerStatus.fromJson(j);
      statusError = null;
    } catch (e) {
      statusError = e.toString();
    } finally {
      loadingStatus = false;
      notifyListeners();
    }
  }

  Future<void> refreshBrandAndMe() async {
    try {
      final j = await Api.i.me();
      me = MeInfo.fromJson(j);
    } catch (_) {
      me = null;
    }
    notifyListeners();
    await refreshSeason();
  }

  Future<void> refreshSeason() async {
    try {
      final j = await Api.i.season();
      season = SeasonInfo.fromJson(j);
      notifyListeners();
    } catch (_) {
      // 赛季接口失败不影响主流程
    }
  }

  Future<void> refreshUnread({bool silent = false}) async {
    if (!Api.i.hasSession) {
      unread = const UnreadInfo();
      if (!silent) notifyListeners();
      return;
    }
    try {
      final j = await Api.i.notifications();
      unread = UnreadInfo.fromJson(j);
      notifs = asList(j['notifications']).map(NotifItem.fromJson).toList();
      unreadError = null;
      _maybeNotify();
    } catch (e) {
      if (!silent) unreadError = e.toString();
    }
    notifyListeners();
  }

  /// 有新消息时弹系统通知（只有比上次多才提示，避免重复轰炸）
  void _maybeNotify() {
    final total = unread.total;
    if (_firstUnreadPass) {
      _firstUnreadPass = false;
      _lastUnreadTotal = total;
      return;
    }
    if (!notifyEnabled || total <= _lastUnreadTotal) {
      _lastUnreadTotal = total;
      return;
    }
    final delta = total - _lastUnreadTotal;
    _lastUnreadTotal = total;
    final parts = <String>[];
    if (unread.notifications > 0) parts.add('通知 ${unread.notifications}');
    if (unread.dm > 0) parts.add('私信 ${unread.dm}');
    if (unread.friendReq > 0) parts.add('好友申请 ${unread.friendReq}');
    NotifyService.i.show(
      id: 1001,
      title: '同禾境 · 你有 $delta 条新消息',
      body: parts.isEmpty ? '点我查看' : parts.join(' · '),
      payload: 'messages',
    );
  }

  void _onNotifyTap(String? payload) {
    if (payload == 'messages') {
      NavBus.i.gotoTab('messages');
    }
  }

  // ---------------- 会话 ----------------
  Future<void> login(String username, String password) async {
    await Api.i.login(username, password);
    _firstUnreadPass = true;
    await refreshBrandAndMe();
    await refreshUnread();
  }

  Future<void> register(String username, String password) async {
    await Api.i.register(username, password);
    await login(username, password);
  }

  Future<void> logout() async {
    await Api.i.logout();
    me = null;
    unread = const UnreadInfo();
    notifs = const <NotifItem>[];
    _firstUnreadPass = true;
    _lastUnreadTotal = 0;
    notifyListeners();
  }

  Future<void> markAllRead() async {
    try {
      await Api.i.readAllNotifications();
    } catch (_) {}
    unread = const UnreadInfo();
    notifyListeners();
    await refreshUnread(silent: true);
  }

  /// 未读角标（给底部栏用）
  Map<String, int> get badges => <String, int>{
        if (unread.total > 0) 'messages': unread.total,
      };
}

/// 极小的平台偏好探测（避免引入额外依赖）
class Platform9 {
  Platform9._();
  static bool isDarkPreferred = true;
}

/// 跨页导航总线（通知点击 → 切 Tab）
class NavBus {
  NavBus._();
  static final NavBus i = NavBus._();

  final _controller = StreamController<String>.broadcast();
  Stream<String> get stream => _controller.stream;

  void gotoTab(String id) => _controller.add(id);
}
