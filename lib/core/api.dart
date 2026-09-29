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
    this.username,
    this.role = 'member',
    this.isAdmin = false,
    this.mcName,
    this.avatar,
    this.createdAt,
    this.serverName = '同禾境',
    this.notice = '',
    this.qqGroup = AppMeta.qqGroupFallback,
    this.siteUrl = '',
    this.serverAddress = '',
  });

  final bool loggedIn;
  final String? username;
  final String role;
  final bool isAdmin;
  final String? mcName;
  final String? avatar;
  final int? createdAt;
  final String serverName;
  final String notice;
  final String qqGroup;
  final String siteUrl;
  final String serverAddress;

  static MeInfo fromJson(Map<String, dynamic> j) {
    final u = j['user'] is Map ? asMap(j['user']) : <String, dynamic>{};
    return MeInfo(
      loggedIn: u.isNotEmpty,
      username: asStrOrNull(u['username']),
      role: asStr(u['role'], 'member'),
      isAdmin: asBool(u['isAdmin'] ?? u['is_admin']),
      mcName: asStrOrNull(u['mcName']),
      avatar: asStrOrNull(u['avatar']),
      createdAt: u['createdAt'] == null ? null : asInt(u['createdAt']),
      serverName: asStr(j['serverName'], '同禾境'),
      notice: asStr(j['notice']),
      qqGroup: asStr(j['qq_group'], AppMeta.qqGroupFallback),
      siteUrl: asStr(j['siteUrl']),
      serverAddress: asStr(j['server_address']),
    );
  }
}
