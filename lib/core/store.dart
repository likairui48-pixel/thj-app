import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/config.dart';
import '../app/theme.dart';
import 'api.dart';
import 'native.dart';
import 'notify.dart';
import 'realtime.dart';

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

  /// 消息接收方式（在设置里可选，附带代价说明）
  ///  0 = 仅在打开 App 时接收（不占后台、无通知栏痕迹，可能延迟）
  ///  1 = 后台实时接收（通知栏会有一条静默通知，换消息秒到）
  ///  2 = 后台实时 + 省电白名单引导（最稳，需用户去系统设置允许自启动）
  int rtMode = 0;

  /// App 是否在前台（后台时才弹系统通知，前台靠界面自己提示）
  bool foreground = true;

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
  StreamSubscription<RtEvent>? _rtSub;
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
    rtMode = s.getInt('rt_mode') ?? 0;
    Motion.reduce = reduceMotion;

    await Api.i.load();
    await NotifyService.i.init(onTap: _onNotifyTap);
    _rtSub = Realtime.i.stream.listen(_onRealtime);

    booted = true;
    notifyListeners();

    await refreshBrandAndMe();
    refreshStatus();
    refreshUnread();
    _startTimers();
    _applyRealtime();
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
    _rtSub?.cancel();
    super.dispose();
  }

  // ---------------- 实时通道 ----------------

  /// 根据登录状态 + 用户选的接收方式，决定要不要保持长连接与前台服务
  Future<void> _applyRealtime() async {
    final loggedIn = me?.loggedIn == true;
    final wantLive = loggedIn && rtMode > 0;
    if (wantLive) {
      Realtime.i.start();
      await NativeKeepAlive.set(true);
    } else {
      Realtime.i.stop();
      await NativeKeepAlive.set(false);
    }
  }

  Future<void> setRtMode(int v) async {
    rtMode = v.clamp(0, 2);
    notifyListeners();
    await _sp?.setInt('rt_mode', rtMode);
    await _applyRealtime();
  }

  void setForeground(bool v) {
    final wasBackground = !foreground;
    foreground = v;
    if (v && wasBackground) {
      // 回到前台：立即补一次未读（后台期间可能错过了推送）
      refreshUnread(silent: true);
      if (rtMode > 0) Realtime.i.start();
    } else if (!v && rtMode == 0) {
      // 「仅在打开时」：退到后台就断开，别浪费电
      Realtime.i.stop();
    }
  }

  void _onRealtime(RtEvent e) {
    switch (e.type) {
      case 'dm':
        // 新私信：立刻刷新角标（消息页面自己会监听同一个流来刷新列表）
        refreshUnread(silent: true);
        final from = asInt(e.data['from']);
        if (from != 0 && from != (me?.id ?? -1)) {
          RtBus.i.add(RtPing('dm:$from'));
        }
        break;
      case 'dmRevoke':
        RtBus.i.add(RtPing('dmRevoke:${asInt(e.data['id'])}'));
        break;
      case 'dmRead':
        RtBus.i.add(RtPing('dmRead:${asInt(e.data['by'])}'));
        break;
      case 'dmTyping':
        RtBus.i.add(RtPing('dmTyping:${asInt(e.data['from'])}'));
        break;
      case 'friend':
        refreshUnread(silent: true);
        RtBus.i.add(RtPing('friend'));
        break;
      case 'notify':
        refreshUnread(silent: true);
        _notifyFromEvent(e.data);
        break;
      default:
        break;
    }
  }

  /// 服务端推来的通知（好友申请 / 帖子回复 / 私信…）→ 弹系统通知
  void _notifyFromEvent(Map<String, dynamic> d) {
    if (!notifyEnabled || foreground) return;
    final kind = asStr(d['kind']);
    final title = asStr(d['title'], '同禾境');
    final body = asStr(d['body']);
    final link = asStr(d['link']);
    final uid = _uidFromLink(link);
    NotifyService.i.show(
      id: (kind == 'dm' && uid != null) ? 2000 + uid : 1001,
      title: title,
      body: body.isEmpty ? '点我查看' : body,
      payload: link.isEmpty ? 'messages' : 'link:$link',
    );
  }

  static int? _uidFromLink(String link) {
    final i = link.indexOf('u=');
    if (i < 0) return null;
    return int.tryParse(link.substring(i + 2).split('&').first);
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
  /// 开着实时通道时，通知由服务端推来的 notify 事件负责（那里信息更全），
  /// 这里只管「仅在打开时接收」这种轮询模式，避免同一条消息弹两次。
  void _maybeNotify() {
    final total = unread.total;
    if (_firstUnreadPass) {
      _firstUnreadPass = false;
      _lastUnreadTotal = total;
      return;
    }
    if (!notifyEnabled || total <= _lastUnreadTotal || rtMode > 0) {
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
    if (payload == null || payload.isEmpty) return;
    if (payload == 'messages') {
      NavBus.i.gotoTab('messages');
      return;
    }
    if (payload.startsWith('link:')) {
      NavBus.i.openLink(payload.substring(5));
    }
  }

  // ---------------- 会话 ----------------
  Future<void> login(String username, String password) async {
    await Api.i.login(username, password);
    _firstUnreadPass = true;
    await refreshBrandAndMe();
    await refreshUnread();
    await _applyRealtime();
    RtBus.i.add(RtPing('login'));
  }

  Future<void> register(String username, String password) async {
    await Api.i.register(username, password);
    _firstUnreadPass = true;
    await refreshBrandAndMe();
    await refreshUnread();
    await _applyRealtime();
    RtBus.i.add(RtPing('login'));
  }

  Future<void> logout() async {
    await Api.i.logout();
    me = null;
    unread = const UnreadInfo();
    notifs = const <NotifItem>[];
    _firstUnreadPass = true;
    _lastUnreadTotal = 0;
    notifyListeners();
    await _applyRealtime();
    RtBus.i.add(RtPing('logout'));
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

/// 跨页导航总线（通知点击 → 切 Tab / 开页）
class NavBus {
  NavBus._();
  static final NavBus i = NavBus._();

  /// 全局导航（供通知点击从任意位置开页）
  final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

  /// 由 Shell 注入：打开与某人的聊天 / 某人的主页
  void Function(int userId)? openChat;
  void Function(String username)? openProfile;
  void Function(String path)? openWebPage;

  final _controller = StreamController<String>.broadcast();
  Stream<String> get stream => _controller.stream;

  void gotoTab(String id) => _controller.add(id);

  /// 服务端 link（/chat?u=3、/u/alice、/forum/thread/5 …）→ 原生页或网页容器
  void openLink(String link) {
    final path = link.startsWith('/') ? link : '/$link';
    final uri = Uri.tryParse(path);
    if (uri == null) return;
    if (uri.path.startsWith('/chat')) {
      final uid = int.tryParse(uri.queryParameters['u'] ?? '');
      if (uid != null && openChat != null) {
        openChat!(uid);
        return;
      }
      gotoTab('messages');
      return;
    }
    if (uri.path.startsWith('/u/')) {
      final name = Uri.decodeComponent(uri.path.substring(3));
      if (name.isNotEmpty && openProfile != null) {
        openProfile!(name);
        return;
      }
    }
    openWebPage?.call(path);
  }
}

/// 实时事件的小广播（页面自己监听，避免各自去翻全局状态）
class RtPing {
  RtPing(this.tag);
  final String tag;
}

class RtBus {
  RtBus._();
  static final RtBus i = RtBus._();
  final _controller = StreamController<RtPing>.broadcast();
  Stream<RtPing> get stream => _controller.stream;
  void add(RtPing p) => _controller.add(p);
}
