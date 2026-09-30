import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../app/config.dart';

/// ============================================================
///  接口层：Cookie 会话 + 容错解析 + 地址故障转移
///
///  站点契约（实测）：
///   - 所有响应是 { ok: bool, ... }，失败带 { error: string }
///   - 未登录的受保护接口返回 401
///   - 字段可能缺失或为 null（例如 /api/status.version、rows[].level）
///   - 写请求**不要**带 Origin 头（站点同源校验只在有 Origin 时才检查）
/// ============================================================

/// 类型容错取值工具
int asInt(dynamic v, [int def = 0]) {
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v) ?? def;
  return def;
}

double asDouble(dynamic v, [double def = 0]) {
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? def;
  return def;
}

String asStr(dynamic v, [String def = '']) {
  if (v == null) return def;
  if (v is String) return v;
  return v.toString();
}

String? asStrOrNull(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

bool asBool(dynamic v, [bool def = false]) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v == 'true' || v == '1';
  return def;
}

List<Map<String, dynamic>> asList(dynamic v) {
  if (v is! List) return const <Map<String, dynamic>>[];
  return v
      .whereType<Map>()
      .map((e) => e.map((k, val) => MapEntry(k.toString(), val)))
      .toList();
}

Map<String, dynamic> asMap(dynamic v) {
  if (v is! Map) return <String, dynamic>{};
  return v.map((k, val) => MapEntry(k.toString(), val));
}

class ApiError implements Exception {
  ApiError(this.message, {this.status});
  final String message;
  final int? status;

  @override
  String toString() => message;
}

class Api {
  Api._();
  static final Api i = Api._();

  static const String _kCookie = 'thj_cookie';
  static const String _kBase = 'thj_base_url';

  List<String> _candidates = List<String>.from(Endpoints.defaults);
  String _base = Endpoints.defaults.first;
  String? _cookie;
  bool _loaded = false;
  bool online = true; // 上一次请求是否成功（用于离线提示）

  String get base => _base;
  String? get cookieRaw => _cookie;
  String get host => Uri.tryParse(_base)?.host ?? _base;
  bool get hasSession => _cookie != null && _cookie!.isNotEmpty;

  Future<void> load() async {
    if (_loaded) return;
    final sp = await SharedPreferences.getInstance();
    final saved = sp.getString(_kBase);
    if (saved != null && saved.isNotEmpty) {
      _base = saved;
      _candidates = [saved, ...Endpoints.defaults.where((e) => e != saved)];
    }
    _cookie = sp.getString(_kCookie);
    _loaded = true;
  }

  Future<void> setBase(String url) async {
    final clean = url.trim().replaceAll(RegExp(r'/+$'), '');
    _base = clean;
    _candidates = [clean, ...Endpoints.defaults.where((e) => e != clean)];
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kBase, clean);
  }

  Future<void> resetBase() async {
    _base = Endpoints.defaults.first;
    _candidates = List<String>.from(Endpoints.defaults);
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kBase);
  }

  Future<void> _saveCookie(String? raw) async {
    _cookie = raw;
    final sp = await SharedPreferences.getInstance();
    if (raw == null) {
      await sp.remove(_kCookie);
    } else {
      await sp.setString(_kCookie, raw);
    }
  }

  Future<void> clearSession() => _saveCookie(null);

  Map<String, String> _headers({bool json = true}) {
    final h = <String, String>{
      'Accept': 'application/json, text/plain, */*',
      'User-Agent': '${AppMeta.appNameEn}/1.0 (Android)',
      // 故意不传 Origin：保持「非浏览器客户端」身份，避开同源校验
    };
    if (json) h['Content-Type'] = 'application/json; charset=utf-8';
    if (_cookie != null && _cookie!.isNotEmpty) h['Cookie'] = _cookie!;
    return h;
  }

  /// 解析 Set-Cookie（只留 name=value，忽略属性）
  void _absorbCookies(http.BaseResponse res) {
    final raw = res.headers['set-cookie'];
    if (raw == null || raw.isEmpty) return;
    final parts = raw
        .split(',')
        .map((s) => s.split(';').first.trim())
        .where((s) => s.contains('=') && !s.toLowerCase().startsWith('expires='))
        .toList();
    if (parts.isEmpty) return;
    final map = <String, String>{};
    for (final c in (_cookie ?? '').split(';')) {
      final kv = c.split('=');
      if (kv.length >= 2 && kv[0].trim().isNotEmpty) {
        map[kv[0].trim()] = kv.sublist(1).join('=').trim();
      }
    }
    for (final p in parts) {
      final kv = p.split('=');
      if (kv.length >= 2) map[kv[0].trim()] = kv.sublist(1).join('=').trim();
    }
    final merged = map.entries.map((e) => '${e.key}=${e.value}').join('; ');
    _saveCookie(merged);
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final u = Uri.parse('$_base$path');
    if (query == null || query.isEmpty) return u;
    final q = <String, String>{};
    query.forEach((k, v) {
      if (v != null) q[k] = v.toString();
    });
    return u.replace(queryParameters: {...u.queryParameters, ...q});
  }

  /// 带故障转移的请求：主域名失败 → 保底 IP
  Future<http.Response> _send(
    Future<http.Response> Function(String base) run,
  ) async {
    await load();
    Object? last;
    for (var i = 0; i < _candidates.length; i++) {
      final b = _candidates[i];
      try {
        final res = await run(b).timeout(RefreshPolicy.httpTimeout);
        if (i > 0) {
          // 切换成功后记住这个地址
          _base = b;
          _candidates = [b, ..._candidates.where((x) => x != b)];
          final sp = await SharedPreferences.getInstance();
          await sp.setString(_kBase, b);
        }
        online = true;
        _absorbCookies(res);
        return res;
      } on SocketException catch (e) {
        last = e;
      } on TimeoutException catch (e) {
        last = e;
      } on http.ClientException catch (e) {
        last = e;
      } on HandshakeException catch (e) {
        last = e;
      }
    }
    online = false;
    throw ApiError(
      '连接不上服务器\n${last?.toString() ?? '网络不可用'}\n已尝试：${_candidates.join(' / ')}',
    );
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> body = <String, dynamic>{};
    if (res.body.isNotEmpty) {
      try {
        body = asMap(jsonDecode(utf8.decode(res.bodyBytes)));
      } catch (_) {
        if (res.statusCode >= 400) {
          throw ApiError('服务器返回异常（HTTP ${res.statusCode}）',
              status: res.statusCode);
        }
        throw ApiError('返回内容无法解析（HTTP ${res.statusCode}）',
            status: res.statusCode);
      }
    }
    if (res.statusCode == 401) {
      throw ApiError(asStr(body['error'], '请先登录'), status: 401);
    }
    if (res.statusCode >= 400) {
      throw ApiError(
        asStr(body['error'], '请求失败（HTTP ${res.statusCode}）'),
        status: res.statusCode,
      );
    }
    if (body['ok'] == false) {
      throw ApiError(asStr(body['error'], '操作失败'));
    }
    return body;
  }

  Future<Map<String, dynamic>> get(String path,
      [Map<String, dynamic>? query]) async {
    final res = await _send((b) {
      final uri = _uri(path, query);
      final real = uri.replace(host: Uri.parse(b).host, port: Uri.parse(b).port, scheme: Uri.parse(b).scheme);
      return http.get(real, headers: _headers(json: false));
    });
    return _decode(res);
  }

  Future<Map<String, dynamic>> post(String path,
      [Map<String, dynamic>? body]) async {
    final res = await _send((b) {
      final uri = _uri(path);
      final real = uri.replace(host: Uri.parse(b).host, port: Uri.parse(b).port, scheme: Uri.parse(b).scheme);
      return http.post(real,
          headers: _headers(), body: jsonEncode(body ?? <String, dynamic>{}));
    });
    return _decode(res);
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final res = await _send((b) {
      final uri = _uri(path);
      final real = uri.replace(host: Uri.parse(b).host, port: Uri.parse(b).port, scheme: Uri.parse(b).scheme);
      return http.delete(real, headers: _headers());
    });
    return _decode(res);
  }

  // ---------------- 业务封装 ----------------

  Future<Map<String, dynamic>> status({bool showFakes = false}) =>
      get('/api/status', showFakes ? {'fakes': 1} : null);

  Future<Map<String, dynamic>> brand() => get('/api/brand');

  Future<Map<String, dynamic>> season() => get('/api/season');

  Future<Map<String, dynamic>> board({
    int limit = 30,
    int offset = 0,
    String? tier,
    bool showFakes = false,
  }) =>
      get('/api/rank/board', {
        'limit': limit,
        'offset': offset,
        if (tier != null) 'tier': tier,
        if (showFakes) 'fakes': 1,
      });

  Future<Map<String, dynamic>> player(String name) =>
      get('/api/player/${Uri.encodeComponent(name)}');

  Future<Map<String, dynamic>> search(String q) =>
      get('/api/search', {'q': q});

  Future<Map<String, dynamic>> me() => get('/api/auth/me');

  Future<Map<String, dynamic>> myRank() => get('/api/me/rank');

  Future<Map<String, dynamic>> notifications() => get('/api/notifications');

  Future<Map<String, dynamic>> notificationsGrouped() =>
      get('/api/notifications/grouped');

  Future<Map<String, dynamic>> conversations() => get('/api/dm/conversations');

  Future<Map<String, dynamic>> checkinInfo() => get('/api/festival');

  Future<void> readAllNotifications() =>
      post('/api/notifications/read-all');

  Future<void> login(String username, String password) async {
    await post('/api/auth/login', {'username': username, 'password': password});
  }

  Future<void> register(String username, String password) async {
    await post('/api/auth/register',
        {'username': username, 'password': password});
  }

  Future<void> logout() async {
    try {
      await post('/api/auth/logout');
    } catch (_) {
      // 站点即使失败也允许本地登出
    }
    await clearSession();
  }

  Future<void> changePassword(String oldPassword, String newPassword) =>
      post('/api/auth/password',
          {'oldPassword': oldPassword, 'newPassword': newPassword});

  // ---------------- 私信 ----------------

  Future<Map<String, dynamic>> dmConversations() =>
      get('/api/dm/conversations');

  Future<Map<String, dynamic>> dmHistory(int userId,
          {int? before, int limit = 50}) =>
      get('/api/dm/$userId', {
        if (before != null && before > 0) 'before': before,
        'limit': limit,
      });

  Future<Map<String, dynamic>> dmSend(int userId,
          {String text = '', String? image}) =>
      post('/api/dm/$userId', {
        if (text.isNotEmpty) 'text': text,
        if (image != null && image.isNotEmpty) 'image': image,
      });

  Future<Map<String, dynamic>> dmMeta(int userId) =>
      get('/api/dm/$userId/meta');

  Future<Map<String, dynamic>> dmPin(int userId, {bool? value}) =>
      post('/api/dm/$userId/pin', value == null ? {} : {'value': value});

  Future<Map<String, dynamic>> dmMute(int userId, {bool? value}) =>
      post('/api/dm/$userId/mute', value == null ? {} : {'value': value});

  Future<Map<String, dynamic>> dmRevoke(int userId, int messageId) =>
      post('/api/dm/$userId/revoke', {'messageId': messageId});

  Future<void> dmRead(int userId) => post('/api/dm/$userId/read');

  Future<void> dmDelete(int userId) =>
      delete('/api/dm/$userId');

  // ---------------- 好友 ----------------

  Future<Map<String, dynamic>> friends() => get('/api/friends');

  Future<Map<String, dynamic>> friendRequest(int userId) =>
      post('/api/friends/request', {'userId': userId});

  Future<Map<String, dynamic>> friendAccept(int userId) =>
      post('/api/friends/accept', {'userId': userId});

  Future<Map<String, dynamic>> friendReject(int userId) =>
      post('/api/friends/reject', {'userId': userId});

  Future<Map<String, dynamic>> friendBlock(int userId) =>
      post('/api/friends/block', {'userId': userId});

  Future<Map<String, dynamic>> friendUnblock(int userId) =>
      post('/api/friends/unblock', {'userId': userId});

  Future<void> friendDelete(int userId) => delete('/api/friends/$userId');

  Future<Map<String, dynamic>> friendMeta(int userId,
          {String? remark, String? group}) =>
      post('/api/friends/$userId/meta', {
        if (remark != null) 'remark': remark,
        if (group != null) 'group': group,
      });

  Future<Map<String, dynamic>> userSearch(String q) =>
      get('/api/users/search', {'q': q});

  // ---------------- 个人主页 ----------------

  Future<Map<String, dynamic>> profile(String username) =>
      get('/api/profile/${Uri.encodeComponent(username)}');

  Future<Map<String, dynamic>> space(String username) =>
      get('/api/space/${Uri.encodeComponent(username)}');

  Future<Map<String, dynamic>> saveProfile(
          {String? bio, String? bg, List<String>? tags}) =>
      post('/api/profile', {
        if (bio != null) 'bio': bio,
        if (bg != null) 'bg': bg,
        if (tags != null) 'tags': tags,
      });

  Future<Map<String, dynamic>> uploadImage(String dataUrl,
          {String kind = 'photo'}) =>
      post('/api/upload/image', {'data': dataUrl, 'kind': kind});

  Future<Map<String, dynamic>> setAvatar(String dataUrl) =>
      post('/api/me/avatar', {'data': dataUrl});

  Future<void> deleteAvatar() => delete('/api/me/avatar');

  Future<Map<String, dynamic>> setProfileBg(String dataUrl) =>
      post('/api/me/bg', {'data': dataUrl});

  Future<void> deleteProfileBg() => delete('/api/me/bg');

  Future<Map<String, dynamic>> privacy() => get('/api/settings/privacy');

  Future<Map<String, dynamic>> setPrivacy(Map<String, dynamic> patch) =>
      post('/api/settings/privacy', patch);

  Future<Map<String, dynamic>> notifySettings() => get('/api/settings/notify');

  Future<Map<String, dynamic>> setNotifySettings(Map<String, dynamic> patch) =>
      post('/api/settings/notify', patch);

  // ---------------- 榜单 ----------------

  Future<Map<String, dynamic>> leaderboard(String by) =>
      get('/api/leaderboard', {'by': by});

  Future<Map<String, dynamic>> rankDetail(String name) =>
      get('/api/rank/${Uri.encodeComponent(name)}');

  Future<Map<String, dynamic>> bindStatus() => get('/api/bind/status');

  Future<Map<String, dynamic>> bindStart() => post('/api/bind/start');

  Future<Map<String, dynamic>> bindVerify(String code) =>
      post('/api/bind/verify', {'code': code});

  /// 相对路径 → 绝对地址（头像/图片都是 /static/... 形式）
  String abs(String pathOrUrl) {
    final s = pathOrUrl.trim();
    if (s.isEmpty) return s;
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    return '$_base${s.startsWith('/') ? '' : '/'}$s';
  }

  /// 名片图 / 头像图（直接给 Image.network 用的 URL）
  String cardUrl(String name) => '$_base/api/card/${Uri.encodeComponent(name)}.png';
  String avatarUrl(String name, {int size = 96, bool skin = false}) =>
      '$_base/api/avatar/${Uri.encodeComponent(name)}?size=$size${skin ? '&skin=1' : ''}';
}

// ============================================================
//  数据模型（全部容错，缺字段不崩）
// ============================================================

class PlayerLite {
  PlayerLite({
    required this.name,
    this.level,
    this.hours = 0,
    this.fake = false,
  });

  final String name;
  final int? level;
  final double hours;
  final bool fake;

  factory PlayerLite.fromJson(Map<String, dynamic> j) => PlayerLite(
        name: asStr(j['name'], '未知'),
        level: j['level'] == null ? null : asInt(j['level']),
        hours: asDouble(j['playtimeHours']),
        fake: asBool(j['fake']),
      );
}

class ServerStatus {
  ServerStatus({
    required this.online,
    required this.max,
    required this.players,
    required this.fakeFolded,
    required this.fakesShown,
    this.version,
    this.serverName = '同禾境',
    this.lastScan,
    this.updatedAt,
    this.error,
  });

  final int online;
  final int max;
  final List<PlayerLite> players;
  final int fakeFolded;
  final bool fakesShown;
  final String? version;
  final String serverName;
  final int? lastScan;
  final int? updatedAt;
  final String? error;

  double get fill => max <= 0 ? 0 : (online / max).clamp(0.0, 1.0);

  static ServerStatus fromJson(Map<String, dynamic> j) => ServerStatus(
        online: asInt(j['online']),
        max: asInt(j['max'], 48),
        players: asList(j['players']).map(PlayerLite.fromJson).toList(),
        fakeFolded: asInt(j['fakeFolded']),
        fakesShown: asBool(j['fakesShown']),
        version: asStrOrNull(j['version']),
        serverName: asStr(j['serverName'], '同禾境'),
        lastScan: j['lastScan'] == null ? null : asInt(j['lastScan']),
        updatedAt: j['updatedAt'] == null ? null : asInt(j['updatedAt']),
        error: asStrOrNull(j['error']),
      );
}

class TierInfo {
  TierInfo({required this.key, required this.label, required this.color});
  final String key;
  final String label;
  final int color;

  factory TierInfo.fromJson(Map<String, dynamic> j) => TierInfo(
        key: asStr(j['key'], 'C'),
        label: asStr(j['label'], '禾苗'),
        color: _hex(asStrOrNull(j['color'])),
      );

  static int _hex(String? s) {
    if (s == null) return 0xFF8D9182;
    var h = s.replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    return int.tryParse(h, radix: 16) ?? 0xFF8D9182;
  }
}

class RankRow {
  RankRow({
    required this.pos,
    required this.name,
    required this.score,
    required this.tier,
    required this.hours,
    this.placed = 0,
    this.level,
    this.webUser,
    this.fake = false,
  });

  final int pos;
  final String name;
  final int score;
  final TierInfo tier;
  final double hours;
  final int placed;
  final int? level;
  final String? webUser;
  final bool fake;

  factory RankRow.fromJson(Map<String, dynamic> j) => RankRow(
        pos: asInt(j['pos']),
        name: asStr(j['name'], '未知'),
        score: asInt(j['score']),
        tier: TierInfo.fromJson(asMap(j['tier'])),
        hours: asDouble(j['hours']),
        placed: asInt(j['placed']),
        level: j['level'] == null ? null : asInt(j['level']),
        webUser: asStrOrNull(j['webUser']),
        fake: false,
      );
}

class SeasonInfo {
  SeasonInfo({
    required this.name,
    required this.daysLeft,
    this.plannedEndAt,
    this.durationDays = 0,
  });

  final String name;
  final int daysLeft;
  final int? plannedEndAt;
  final int durationDays;

  static SeasonInfo? fromJson(Map<String, dynamic> j) {
    final s = j['season'];
    if (s is! Map) return null;
    final m = asMap(s);
    return SeasonInfo(
      name: asStr(m['name'], '当前赛季'),
      daysLeft: asInt(m['daysLeft']),
      plannedEndAt:
          m['plannedEndAt'] == null ? null : asInt(m['plannedEndAt']),
      durationDays: asInt(m['durationDays']),
    );
  }
}

class PlayerCard {
  PlayerCard({
    required this.name,
    required this.found,
    this.online = false,
    this.banned = false,
    this.level = 0,
    this.hours = 0,
    this.deaths = 0,
    this.mobKills = 0,
    this.playerKills = 0,
    this.blocksMined = 0,
    this.distanceKm = 0,
    this.rank = 0,
    this.total = 0,
    this.webUser,
    this.tier,
  });

  final String name;
  final bool found;
  final bool online;
  final bool banned;
  final int level;
  final double hours;
  final int deaths;
  final int mobKills;
  final int playerKills;
  final int blocksMined;
  final double distanceKm;
  final int rank;
  final int total;
  final String? webUser;
  final TierInfo? tier;

  static PlayerCard? fromJson(Map<String, dynamic> j) {
    final p = j['player'];
    if (p is! Map) return null;
    final m = asMap(p);
    final tier = j['tier'] is Map ? TierInfo.fromJson(asMap(j['tier'])) : null;
    return PlayerCard(
      name: asStr(m['name'], '未知'),
      found: asBool(m['found'], true),
      online: asBool(m['online']),
      banned: asBool(m['banned']),
      level: asInt(m['level']),
      hours: asDouble(m['playtimeHours']),
      deaths: asInt(m['deaths']),
      mobKills: asInt(m['mobKills']),
      playerKills: asInt(m['playerKills']),
      blocksMined: asInt(m['blocksMined']),
      distanceKm: asDouble(m['distanceKm']),
      rank: asInt(j['rank']),
      total: asInt(j['total']),
      webUser: asStrOrNull(j['webUser']),
      tier: tier,
    );
  }
}

class NotifItem {
  NotifItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
    this.kind = 'system',
    this.link,
  });

  final String id;
  final String title;
  final String body;
  final int createdAt;
  final bool read;
  final String kind;
  final String? link;

  factory NotifItem.fromJson(Map<String, dynamic> j) => NotifItem(
        id: asStr(j['id'], '0'),
        title: asStr(j['title'], '通知'),
        body: asStr(j['body'] ?? j['text'] ?? j['message'], ''),
        createdAt: asInt(j['createdAt'] ?? j['ts'] ?? j['at']),
        read: asBool(j['read']),
        kind: asStr(j['kind'] ?? j['type'], 'system'),
        link: asStrOrNull(j['link'] ?? j['url']),
      );
}

class UnreadInfo {
  const UnreadInfo({
    this.notifications = 0,
    this.dm = 0,
    this.friendReq = 0,
  });

  final int notifications;
  final int dm;
  final int friendReq;

  int get total => notifications + dm + friendReq;

  static UnreadInfo fromJson(Map<String, dynamic> j) => UnreadInfo(
        notifications: asInt(j['unread']),
        dm: asInt(j['dmUnread']),
        friendReq: asInt(j['friendReq']),
      );
}

class MeInfo {
  MeInfo({
    required this.loggedIn,
    this.id = 0,
    this.username,
    this.role = 'member',
    this.isAdmin = false,
    this.isStaff = false,
    this.mcName,
    this.avatar,
    this.profileBg,
    this.bio,
    this.tags = const <String>[],
    this.balance = 0,
    this.membership,
    this.qq,
    this.bound = false,
    this.createdAt,
    this.serverName = '同禾境',
    this.notice = '',
    this.qqGroup = AppMeta.qqGroupFallback,
    this.siteUrl = '',
    this.serverAddress = '',
  });

  final bool loggedIn;
  final int id;
  final String? username;
  final String role;
  final bool isAdmin;
  final bool isStaff;
  final String? mcName;
  final String? avatar;
  final String? profileBg;
  final String? bio;
  final List<String> tags;
  final int balance;
  final Membership? membership;
  final String? qq;
  final bool bound;
  final int? createdAt;
  final String serverName;
  final String notice;
  final String qqGroup;
  final String siteUrl;
  final String serverAddress;

  String? get avatarUrl {
    final a = avatar;
    if (a == null || a.isEmpty) return null;
    return Api.i.abs(a);
  }

  String? get bgUrl {
    final a = profileBg;
    if (a == null || a.isEmpty) return null;
    return Api.i.abs(a);
  }

  /// 给 UserLite 用（自己）
  UserLite get asUser => UserLite(
        id: id,
        username: username ?? '',
        role: role,
        isAdmin: isAdmin,
        mcName: mcName,
        avatar: avatar,
        bio: bio,
        tags: tags,
        membership: membership,
        createdAt: createdAt,
      );

  static MeInfo fromJson(Map<String, dynamic> j) {
    final u = j['user'] is Map ? asMap(j['user']) : <String, dynamic>{};
    final m = u['membership'];
    return MeInfo(
      loggedIn: u.isNotEmpty,
      id: asInt(u['id']),
      username: asStrOrNull(u['username']),
      role: asStr(u['role'], 'member'),
      isAdmin: asBool(u['isAdmin'] ?? u['is_admin']),
      isStaff: asBool(u['isStaff']),
      mcName: asStrOrNull(u['mcName']),
      avatar: asStrOrNull(u['avatar']),
      profileBg: asStrOrNull(u['profileBg']),
      bio: asStrOrNull(u['bio']),
      tags: (u['tags'] is List)
          ? (u['tags'] as List).map((e) => e.toString()).toList()
          : const <String>[],
      balance: asInt(u['balance']),
      membership: (m is Map) ? Membership.fromJson(asMap(m)) : null,
      qq: asStrOrNull(u['qq']),
      bound: u['binding'] != null,
      createdAt: u['createdAt'] == null ? null : asInt(u['createdAt']),
      serverName: asStr(j['serverName'], '同禾境'),
      notice: asStr(j['notice']),
      qqGroup: asStr(j['qq_group'], AppMeta.qqGroupFallback),
      siteUrl: asStr(j['siteUrl']),
      serverAddress: asStr(j['server_address']),
    );
  }
}

// ============================================================
//  社交模型（v1.1：私信 / 好友 / 主页 / 榜单）
//  一切字段容错，缺字段不崩（站点随时可能加字段）
// ============================================================

/// 站内用户（私信、好友、搜索结果、帖子作者都用它）
class UserLite {
  UserLite({
    required this.id,
    required this.username,
    this.role = 'user',
    this.isAdmin = false,
    this.mcName,
    this.avatar,
    this.bio,
    this.tags = const <String>[],
    this.membership,
    this.online = false,
    this.remark,
    this.group,
    this.createdAt,
  });

  final int id;
  final String username;
  final String role;
  final bool isAdmin;
  final String? mcName;
  final String? avatar;
  final String? bio;
  final List<String> tags;
  final Membership? membership;
  final bool online;

  /// 好友备注 / 分组（只有 /api/friends 会给）
  final String? remark;
  final String? group;
  final int? createdAt;

  bool get isStaff => isAdmin || role == 'mod' || role == 'owner';

  /// 显示名：有备注用备注
  String get display => (remark != null && remark!.isNotEmpty) ? remark! : username;

  /// 头像图 URL（服务端给的是 /api/avatar/<name> 或上传后的 /static/...）
  String? get avatarUrl {
    final a = avatar;
    if (a == null || a.isEmpty) return null;
    return Api.i.abs(a);
  }

  static UserLite fromJson(Map<String, dynamic> j) {
    final m = j['membership'];
    return UserLite(
      id: asInt(j['id']),
      username: asStr(j['username'], '未知'),
      role: asStr(j['role'], 'user'),
      isAdmin: asBool(j['isAdmin'] ?? j['is_admin']),
      mcName: asStrOrNull(j['mcName'] ?? j['mc_name']),
      avatar: asStrOrNull(j['avatar']),
      bio: asStrOrNull(j['bio']),
      tags: (j['tags'] is List)
          ? (j['tags'] as List).map((e) => e.toString()).toList()
          : const <String>[],
      membership: (m is Map) ? Membership.fromJson(asMap(m)) : null,
      online: asBool(j['online']),
      remark: asStrOrNull(j['remark']),
      group: asStrOrNull(j['group'] ?? j['grp']),
      createdAt: j['createdAt'] == null ? null : asInt(j['createdAt']),
    );
  }
}

class Membership {
  Membership({
    required this.label,
    this.color = 0xFF2E9E63,
    this.until,
    this.badge,
  });
  final String label;
  final int color;
  final int? until;
  final String? badge;

  bool get active => until == null || until! > DateTime.now().millisecondsSinceEpoch;

  static Membership fromJson(Map<String, dynamic> j) => Membership(
        label: asStr(j['label'], '会员'),
        color: _hex(asStrOrNull(j['color'])),
        until: j['until'] == null ? null : asInt(j['until']),
        badge: asStrOrNull(j['badge']),
      );

  static int _hex(String? s) {
    if (s == null) return 0xFF2E9E63;
    var h = s.replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    return int.tryParse(h, radix: 16) ?? 0xFF2E9E63;
  }
}

/// 一条私信
class DmMessage {
  DmMessage({
    required this.id,
    required this.ts,
    required this.from,
    required this.body,
    required this.mine,
    this.revoked = false,
    this.kind = 'text',
    this.image,
    this.read = false,
    this.pending = false,
    this.failed = false,
  });

  final int id;
  final int ts;
  final int from;
  final String body;
  final bool mine;
  bool revoked;
  final String kind; // text | image
  final String? image;
  bool read;

  /// 本地乐观插入（还没拿到服务端 id）
  bool pending;
  bool failed;

  bool get isImage => kind == 'image' && image != null && !revoked;

  String? get imageUrl => image == null ? null : Api.i.abs(image!);

  static DmMessage fromJson(Map<String, dynamic> j) => DmMessage(
        id: asInt(j['id']),
        ts: asInt(j['ts']),
        from: asInt(j['from']),
        body: asStr(j['body']),
        mine: asBool(j['mine']),
        revoked: asBool(j['revoked']),
        kind: asStr(j['kind'], 'text'),
        image: asStrOrNull(j['image']),
        read: asBool(j['read']),
      );
}

class DmConv {
  DmConv({
    required this.peer,
    required this.unread,
    this.online = false,
    this.lastBody,
    this.lastTs = 0,
    this.lastMine = false,
    this.lastKind = 'text',
    this.pinned = false,
    this.muted = false,
  });

  final UserLite peer;
  final int unread;
  final bool online;
  final String? lastBody;
  final int lastTs;
  final bool lastMine;
  final String lastKind;
  final bool pinned;
  final bool muted;

  static DmConv fromJson(Map<String, dynamic> j) {
    final last = asMap(j['last']);
    return DmConv(
      peer: UserLite.fromJson(asMap(j['user'])),
      unread: asInt(j['unread']),
      online: asBool(j['online']),
      lastBody: asStrOrNull(last['body']),
      lastTs: asInt(last['ts']),
      lastMine: asBool(last['mine']),
      lastKind: asStr(last['kind'], 'text'),
      pinned: asBool(j['pinned']),
      muted: asBool(j['muted']),
    );
  }
}

class DmMeta {
  DmMeta({this.pinned = false, this.muted = false, this.online = false, this.mcName});
  final bool pinned;
  final bool muted;
  final bool online;
  final String? mcName;

  static DmMeta fromJson(Map<String, dynamic> j) {
    final m = asMap(j['meta']);
    return DmMeta(
      pinned: asBool(m['pinned']),
      muted: asBool(m['muted']),
      online: asBool(j['online']),
      mcName: asStrOrNull(j['mcName']),
    );
  }
}

class FriendsData {
  FriendsData({
    this.friends = const <UserLite>[],
    this.incoming = const <UserLite>[],
    this.outgoing = const <UserLite>[],
    this.blocked = const <UserLite>[],
  });

  final List<UserLite> friends;
  final List<UserLite> incoming;
  final List<UserLite> outgoing;
  final List<UserLite> blocked;

  int get pendingCount => incoming.length;

  static FriendsData fromJson(Map<String, dynamic> j) => FriendsData(
        friends: asList(j['friends']).map(UserLite.fromJson).toList(),
        incoming: asList(j['incoming']).map(UserLite.fromJson).toList(),
        outgoing: asList(j['outgoing']).map(UserLite.fromJson).toList(),
        blocked: asList(j['blocked']).map(UserLite.fromJson).toList(),
      );
}

/// /api/profile/:username（看别人主页）
class ProfileData {
  ProfileData({
    required this.user,
    required this.bio,
    required this.bg,
    required this.tags,
    this.isSelf = false,
    this.relation = 'none',
    this.hiddenStats = false,
    this.hiddenOnline = false,
    this.hiddenPosts = false,
    this.hiddenCard = false,
    this.friendCount = 0,
    this.restricted = false,
    this.reason,
    this.canFriendRequest = false,
    this.player,
    this.memberships = const <String>[],
  });

  final UserLite user;
  final String bio;
  final String? bg;
  final List<String> tags;
  final bool isSelf;
  final String relation; // none | pending | accepted | blocked
  final bool hiddenStats;
  final bool hiddenOnline;
  final bool hiddenPosts;
  final bool hiddenCard;
  final int friendCount;
  final bool restricted;
  final String? reason;
  final bool canFriendRequest;
  final PlayerCard? player;
  final List<String> memberships;

  bool get isFriend => relation == 'accepted';
  bool get hasPending => relation == 'pending';

  static ProfileData fromJson(Map<String, dynamic> j) {
    final p = asMap(j['profile']);
    final h = asMap(j['hidden']);
    return ProfileData(
      user: UserLite.fromJson(asMap(j['user'])),
      bio: asStr(p['bio']),
      bg: asStrOrNull(p['bg']),
      tags: (p['tags'] is List)
          ? (p['tags'] as List).map((e) => e.toString()).toList()
          : const <String>[],
      isSelf: asBool(j['isSelf']),
      relation: asStr(j['relation'], 'none'),
      hiddenStats: asBool(h['stats']),
      hiddenOnline: asBool(h['online']),
      hiddenPosts: asBool(h['posts']),
      hiddenCard: asBool(h['card']),
      friendCount: asInt(j['friendCount']),
      restricted: asBool(j['restricted']),
      reason: asStrOrNull(j['reason']),
      canFriendRequest: asBool(j['canFriendRequest']),
      player: j['player'] == null ? null : PlayerCard.fromJson(<String, dynamic>{'player': j['player']}),
      memberships: (j['memberships'] is List)
          ? (j['memberships'] as List).map((e) => asStr(asMap(e)['label'], '会员')).toList()
          : const <String>[],
    );
  }
}

/// /api/space/:username（个人空间聚合）
class SpaceData {
  SpaceData({
    required this.username,
    this.avatar,
    this.bio = '',
    this.bg,
    this.views = 0,
    this.followers = 0,
    this.following = 0,
    this.isFollowing = false,
    this.isFriend = false,
    this.guestbookCount = 0,
    this.likesReceived = 0,
    this.threads = const <Map<String, dynamic>>[],
    this.mcName,
    this.lastLogin,
  });

  final String username;
  final String? avatar;
  final String bio;
  final String? bg;
  final int views;
  final int followers;
  final int following;
  final bool isFollowing;
  final bool isFriend;
  final int guestbookCount;
  final int likesReceived;
  final List<Map<String, dynamic>> threads;
  final String? mcName;
  final int? lastLogin;

  static SpaceData fromJson(Map<String, dynamic> j) => SpaceData(
        username: asStr(j['username']),
        avatar: asStrOrNull(j['avatar']),
        bio: asStr(j['bio']),
        bg: asStrOrNull(j['bg']),
        views: asInt(j['views']),
        followers: asInt(j['followers']),
        following: asInt(j['following']),
        isFollowing: asBool(j['isFollowing']),
        isFriend: asBool(j['isFriend']),
        guestbookCount: asInt(j['guestbookCount']),
        likesReceived: asInt(j['likesReceived']),
        threads: asList(j['threads']),
        mcName: asStrOrNull(j['mcName']),
        lastLogin: j['lastLogin'] == null ? null : asInt(j['lastLogin']),
      );
}

/// 时长榜 / 等级榜的一行
class LeaderRow {
  LeaderRow({
    required this.rank,
    required this.name,
    this.level,
    this.hours = 0,
    this.webUser,
    this.fake = false,
    this.firstJoin,
  });

  final int rank;
  final String name;
  final int? level;
  final double hours;
  final String? webUser;
  final bool fake;
  final int? firstJoin;

  static LeaderRow fromJson(Map<String, dynamic> j) => LeaderRow(
        rank: asInt(j['rank']),
        name: asStr(j['name'], '未知'),
        level: j['level'] == null ? null : asInt(j['level']),
        hours: asDouble(j['playtimeHours']),
        webUser: asStrOrNull(j['webUser']),
        fake: asBool(j['fake']),
        firstJoin: j['firstJoin'] == null ? null : asInt(j['firstJoin']),
      );
}

/// 隐私设置：服务端给了项目名与可选值，App 直接照着渲染（加项不用改 App）
class PrivacyData {
  PrivacyData({required this.privacy, required this.items});
  final Map<String, String> privacy;

  /// key → [标题, [可选值...]]
  final Map<String, List<dynamic>> items;

  static const Map<String, String> valueLabels = <String, String>{
    'all': '所有人',
    'friends': '仅好友',
    'self': '仅自己',
    'none': '不接受',
  };

  static PrivacyData fromJson(Map<String, dynamic> j) {
    final p = <String, String>{};
    asMap(j['privacy']).forEach((k, v) => p[k] = asStr(v, 'all'));
    final items = <String, List<dynamic>>{};
    asMap(j['items']).forEach((k, v) {
      if (v is List && v.length >= 2) {
        items[k] = <dynamic>[asStr(v[0]), v[1]];
      }
    });
    return PrivacyData(privacy: p, items: items);
  }
}
