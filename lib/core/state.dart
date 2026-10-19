import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'meta.dart';
import 'nav.dart';
import 'notify.dart';
import 'realtime.dart';

/* ============================================================
 * 远程配置 / 更新
 * ============================================================ */

class TabSpec {
  const TabSpec({
    required this.id,
    required this.label,
    required this.icon,
    this.enabled = true,
    this.badge = false,
    this.url,
  });

  final String id;
  final String label;
  final String icon;
  final bool enabled;
  final bool badge;
  final String? url;

  factory TabSpec.fromJson(Map<String, dynamic> j, TabSpec fallback) {
    return TabSpec(
      id: asStr(j['id'], fallback.id),
      label: asStr(j['label'], fallback.label),
      icon: asStr(j['icon'], fallback.icon),
      enabled: j['enabled'] is bool ? j['enabled'] as bool : fallback.enabled,
      badge: j['badge'] is bool ? j['badge'] as bool : fallback.badge,
      url: asStrOrNull(j['url']) ?? fallback.url,
    );
  }
}

class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    this.link,
  });

  final String id;
  final String title;
  final String body;
  final String? link;
}

class AppConfig {
  AppConfig({
    required this.tabs,
    required this.features,
    this.announcement,
    this.minVersionCode = 0,
    this.forceUpdate = false,
  });

  final List<TabSpec> tabs;
  final Map<String, bool> features;
  final Announcement? announcement;
  final int minVersionCode;
  final bool forceUpdate;

  static const List<TabSpec> defaultTabs = <TabSpec>[
    TabSpec(id: 'home', label: '首页', icon: 'home'),
    TabSpec(id: 'community', label: '社区', icon: 'community'),
    TabSpec(id: 'messages', label: '消息', icon: 'message', badge: true),
    TabSpec(id: 'rank', label: '排行', icon: 'rank'),
    TabSpec(id: 'me', label: '我的', icon: 'person'),
  ];

  static const Map<String, bool> defaultFeatures = <String, bool>{
    'chat': true,
    'community': true,
    'rank': true,
    'events': true,
    'shop': true,
    'smp': true,
    'report': true,
    'guestbook': true,
    'search': true,
  };

  static AppConfig defaults() => AppConfig(
        tabs: List<TabSpec>.from(defaultTabs),
        features: Map<String, bool>.from(defaultFeatures),
      );

  factory AppConfig.fromJson(Map<String, dynamic> j) {
    final rawTabs = asList(j['tabs']);
    final tabs = <TabSpec>[];
    if (rawTabs.isNotEmpty) {
      for (var i = 0; i < rawTabs.length; i++) {
        final fallback = i < defaultTabs.length
            ? defaultTabs[i]
            : const TabSpec(id: 'more', label: '更多', icon: 'more');
        tabs.add(TabSpec.fromJson(rawTabs[i], fallback));
      }
    } else {
      tabs.addAll(defaultTabs);
    }
    final features = Map<String, bool>.from(defaultFeatures);
    final rawFeatures = asMap(j['features']);
    rawFeatures.forEach((k, v) {
      if (v is bool) features[k] = v;
    });

    Announcement? ann;
    final rawAnn = asMap(j['announcement']);
    if (rawAnn.isNotEmpty) {
      final id = asStr(rawAnn['id'], 'ann-${asStr(rawAnn['title']).hashCode}');
      final title = asStr(rawAnn['title']);
      final body = asStr(rawAnn['body'] ?? rawAnn['text'] ?? rawAnn['content']);
      if (title.isNotEmpty || body.isNotEmpty) {
        ann = Announcement(
          id: id,
          title: title.isEmpty ? '公告' : title,
          body: body,
          link: asStrOrNull(rawAnn['link']),
        );
      }
    }

    return AppConfig(
      tabs: tabs.where((t) => t.enabled).toList(),
      features: features,
      announcement: ann,
      minVersionCode: asInt(j['minVersionCode'] ?? j['min_version_code']),
      forceUpdate: asBool(j['forceUpdate'] ?? j['force_update']),
    );
  }

  bool feature(String key) => features[key] ?? true;
}

class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.versionCode,
    required this.url,
    this.notes = const <String>[],
    this.force = false,
    this.size = 0,
    this.minVersionCode = 0,
  });

  final String version;
  final int versionCode;
  final String? url;
  final List<String> notes;
  final bool force;
  final int size;
  final int minVersionCode;

  bool get hasNewer => versionCode > AppMeta.versionCode;
  bool get canDownload => url != null && url!.isNotEmpty;

  String get sizeLabel {
    if (size <= 0) return '';
    return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  static UpdateInfo? fromJson(Map<String, dynamic> j) {
    final src = asMap(j['latest']).isNotEmpty ? asMap(j['latest']) : j;
    final code = asInt(src['versionCode'] ?? src['version_code'] ?? src['build']);
    final version = asStr(src['version'] ?? src['versionName']);
    if (code <= 0 && version.isEmpty) return null;
    final notes = <String>[];
    final rawNotes = src['notes'] ?? src['changelog'];
    if (rawNotes is List) {
      for (final n in rawNotes) {
        final s = asStr(n);
        if (s.isNotEmpty) notes.add(s);
      }
    } else if (rawNotes is String) {
      notes.addAll(rawNotes
          .split(RegExp(r'[\r\n]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty));
    }
    return UpdateInfo(
      version: version.isEmpty ? AppMeta.version : version,
      versionCode: code <= 0 ? AppMeta.versionCode : code,
      url: asStrOrNull(src['url'] ?? src['apk'] ?? src['download']),
      notes: notes,
      force: asBool(src['force']),
      size: asInt(src['size']),
      minVersionCode: asInt(src['minVersionCode'] ?? src['min_version_code']),
    );
  }
}

/* ============================================================
 * 全局状态
 * ============================================================ */

class AppState extends ChangeNotifier {
  AppState._();
  static final AppState i = AppState._();

  // 设置
  ThemeMode themeMode = ThemeMode.system;
  bool notifyEnabled = true;
  int rtMode = 0;
  bool reduceMotion = false;
  bool showFakes = false;

  // 数据
  Map<String, dynamic>? user;
  Map<String, dynamic> serverInfo = <String, dynamic>{};
  Map<String, dynamic>? status;
  Map<String, dynamic>? season;
  String? statusError;
  int unread = 0;
  int dmUnread = 0;
  int friendReq = 0;
  List<Map<String, dynamic>> notifications = <Map<String, dynamic>>[];
  AppConfig config = AppConfig.defaults();
  UpdateInfo? update;

  // 视图
  bool booted = false;
  bool foreground = true;
  bool _loadingStatus = false;
  bool _loadingNotif = false;
  int _lastUnreadTotal = 0;

  SharedPreferences? _sp;
  Timer? _statusTimer;
  Timer? _notifTimer;
  StreamSubscription<RtEvent>? _rtSub;

  bool get isLoggedIn => user != null && asInt(user!['id']) > 0;
  int get userId => asInt(user?['id']);
  String get username => asStr(user?['username']);
  String get mcName => asStr(user?['mcName']);
  String get role => asStr(user?['role'], 'user');
  bool get isStaff =>
      asBool(user?['isAdmin']) ||
      role == 'owner' ||
      role == 'admin' ||
      role == 'moderator';

  String get serverName => asStr(serverInfo['serverName'], AppMeta.appName);
  String get serverAddress =>
      asStr(serverInfo['server_address'], 'thj.mcfuns.cn');
  String get serverIp =>
      asStr(serverInfo['server_ip'], '202.189.13.133:14048');
  String get notice => asStr(serverInfo['notice']);
  String get qqGroup => asStr(serverInfo['qq_group'], AppMeta.qqGroup);

  int get unreadTotal => unread + dmUnread + friendReq;
  Map<String, int> get badges => <String, int>{
        if (unreadTotal > 0) 'messages': unreadTotal,
      };

  bool feature(String key) => config.feature(key);

  Future<void> init() async {
    if (booted) return;
    _sp = await SharedPreferences.getInstance();
    themeMode = _parseTheme(_sp!.getString('theme_mode'));
    notifyEnabled = _sp!.getBool('notify_enabled') ?? true;
    rtMode = (_sp!.getInt('rt_mode') ?? 0).clamp(0, 2);
    reduceMotion = _sp!.getBool('reduce_motion') ?? false;
    showFakes = _sp!.getBool('show_fakes') ?? false;

    await Api.i.init();
    await NotifyService.i.init(onTap: _onNotifyTap);
    _rtSub = Realtime.i.stream.listen(_onRealtime);

    booted = true;
    notifyListeners();

    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await loadConfig();
    await refreshMe();
    await refreshStatus();
    await refreshSeason();
    if (isLoggedIn) await refreshNotifications();
    _startTimers();
    await _applyRealtime();
    await checkUpdate();
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
    _notifTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      refreshStatus(silent: true);
    });
    _notifTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (isLoggedIn) refreshNotifications(silent: true);
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _notifTimer?.cancel();
    _rtSub?.cancel();
    super.dispose();
  }

  // ---------------- 远程配置 / 更新 ----------------

  Future<void> loadConfig() async {
    try {
      final j = await Api.i.appConfig();
      config = AppConfig.fromJson(j);
      notifyListeners();
    } catch (_) {
      // 配置接口不可用时使用本地默认，不影响启动
    }
  }

  Future<void> checkUpdate() async {
    try {
      final j = await Api.i.appVersion();
      update = UpdateInfo.fromJson(j);
      notifyListeners();
    } catch (_) {
      // 静默
    }
  }

  bool get forceUpdate {
    if (update == null) return false;
    if (update!.force && update!.hasNewer) return true;
    return config.forceUpdate && config.minVersionCode > AppMeta.versionCode;
  }

  // ---------------- 设置 ----------------

  Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    notifyListeners();
    await _sp?.setString(
      'theme_mode',
      m == ThemeMode.light
          ? 'light'
          : (m == ThemeMode.dark ? 'dark' : 'system'),
    );
  }

  Future<void> setNotifyEnabled(bool v) async {
    notifyEnabled = v;
    notifyListeners();
    await _sp?.setBool('notify_enabled', v);
    if (v) await NotifyService.i.ensurePermission();
  }

  Future<void> setRtMode(int v) async {
    rtMode = v.clamp(0, 2);
    notifyListeners();
    await _sp?.setInt('rt_mode', rtMode);
    await _applyRealtime();
  }

  Future<void> setReduceMotion(bool v) async {
    reduceMotion = v;
    notifyListeners();
    await _sp?.setBool('reduce_motion', v);
  }

  Future<void> setShowFakes(bool v) async {
    showFakes = v;
    notifyListeners();
    await _sp?.setBool('show_fakes', v);
    await refreshStatus();
  }

  void setForeground(bool v) {
    foreground = v;
    if (v) {
      if (isLoggedIn) refreshNotifications(silent: true);
      if (rtMode > 0 && isLoggedIn) Realtime.i.start();
    } else if (rtMode == 0) {
      Realtime.i.stop();
    }
  }

  // ---------------- 实时通道 ----------------

  Future<void> _applyRealtime() async {
    final live = isLoggedIn && rtMode > 0;
    if (live) {
      Realtime.i.start();
      await AppKeepAlive.set(true);
    } else {
      Realtime.i.stop();
      await AppKeepAlive.set(false);
    }
  }

  void _onRealtime(RtEvent e) {
    switch (e.type) {
      case 'dm':
        refreshNotifications(silent: true);
        if (!foreground && notifyEnabled) {
          final from = asStr(e.data['from_name'] ?? e.data['player']);
          NotifyService.i.show(
            id: 2000 + asInt(e.data['from']),
            title: from.isEmpty ? '新私信' : '$from 发来私信',
            body: asStr(e.data['body'] ?? e.data['message']),
            payload: 'link:/chat?u=${asInt(e.data['from'])}',
          );
        }
        break;
      case 'notify':
        refreshNotifications(silent: true);
        if (!foreground && notifyEnabled) {
          NotifyService.i.show(
            id: 3000 + asInt(e.data['id']),
            title: asStr(e.data['title'], '同禾境'),
            body: asStr(e.data['body']),
            payload: 'link:${asStr(e.data['link'], '/')}',
          );
        }
        break;
      case 'friend':
        refreshNotifications(silent: true);
        break;
    }
  }

  Future<void> _onNotifyTap(String? payload) async {
    if (payload == null || payload.isEmpty) return;
    Nav.payload(payload);
  }

  void _maybeNotify() {
    final total = unreadTotal;
    if (total <= _lastUnreadTotal) {
      _lastUnreadTotal = total;
      return;
    }
    final delta = total - _lastUnreadTotal;
    _lastUnreadTotal = total;
    if (!notifyEnabled || foreground || rtMode > 0) return;
    final parts = <String>[];
    if (unread > 0) parts.add('通知 $unread');
    if (dmUnread > 0) parts.add('私信 $dmUnread');
    if (friendReq > 0) parts.add('好友申请 $friendReq');
    NotifyService.i.show(
      id: 1001,
      title: '同禾境 · 你有 $delta 条新消息',
      body: parts.isEmpty ? '点我查看' : parts.join(' · '),
      payload: 'messages',
    );
  }

  // ---------------- 数据刷新 ----------------

  Future<void> refreshMe() async {
    try {
      final j = await Api.i.authMe();
      serverInfo = j;
      final u = asMap(j['user']);
      user = u.isEmpty ? null : u;
      if (user == null) {
        await Api.i.clearSession();
      }
    } catch (e) {
      // 网络失败不要把已登录用户踢掉；只有明确 401 才清
      if (e is ApiException && e.isAuth) {
        user = null;
        await Api.i.clearSession();
      }
    }
    notifyListeners();
  }

  Future<void> refreshStatus({bool silent = false}) async {
    if (_loadingStatus) return;
    _loadingStatus = true;
    if (!silent) notifyListeners();
    try {
      status = await Api.i.status(showFakes: showFakes);
      statusError = null;
    } catch (e) {
      statusError = e.toString();
    } finally {
      _loadingStatus = false;
      notifyListeners();
    }
  }

  Future<void> refreshSeason() async {
    try {
      season = await Api.i.season();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshNotifications({bool silent = false}) async {
    if (!isLoggedIn || _loadingNotif) return;
    _loadingNotif = true;
    if (!silent) notifyListeners();
    try {
      final j = await Api.i.notifications();
      unread = asInt(j['unread']);
      dmUnread = asInt(j['dmUnread']);
      friendReq = asInt(j['friendReq']);
      notifications = asList(j['notifications']);
      _maybeNotify();
    } catch (_) {
      // 静默
    } finally {
      _loadingNotif = false;
      notifyListeners();
    }
  }

  Future<void> markAllRead() async {
    try {
      await Api.i.readAllNotifications();
    } catch (_) {}
    unread = 0;
    for (final n in notifications) {
      n['read_at'] = DateTime.now().millisecondsSinceEpoch;
    }
    notifyListeners();
    await refreshNotifications(silent: true);
  }

  Future<void> markRead(int id) async {
    try {
      await Api.i.readNotification(id);
    } catch (_) {}
    for (final n in notifications) {
      if (asInt(n['id']) == id) n['read_at'] = DateTime.now().millisecondsSinceEpoch;
    }
    notifyListeners();
    await refreshNotifications(silent: true);
  }

  // ---------------- 会话 ----------------

  Future<void> login(String username, String password) async {
    await Api.i.login(username, password);
    await refreshMe();
    await refreshNotifications();
    await _applyRealtime();
  }

  Future<void> register(String username, String password, {String? qq}) async {
    await Api.i.register(username, password, qq: qq);
    await refreshMe();
    await refreshNotifications();
    await _applyRealtime();
  }

  Future<void> logout() async {
    await Api.i.logout();
    user = null;
    unread = 0;
    dmUnread = 0;
    friendReq = 0;
    notifications = <Map<String, dynamic>>[];
    notifyListeners();
    await _applyRealtime();
  }

  // ---------------- 通知点击 ----------------

  void openNotification(Map<String, dynamic> n) {
    final id = asInt(n['id']);
    if (id > 0) markRead(id);
    final link = asStr(n['link']);
    if (link.isNotEmpty) Nav.to(link);
  }
}
