import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'meta.dart';

/* ============================================================
 * 容错取值：站点接口字段经常缺省 / null，页面不应该因此崩。
 * ============================================================ */

int asInt(dynamic v, [int def = 0]) {
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? def;
  return def;
}

double asDouble(dynamic v, [double def = 0]) {
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is num) return v.toDouble();
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
  if (v is String) {
    final s = v.toLowerCase();
    return s == 'true' || s == '1' || s == 'yes' || s == 'on';
  }
  return def;
}

Map<String, dynamic> asMap(dynamic v) {
  if (v is Map) {
    return v.map((k, val) => MapEntry(k.toString(), val));
  }
  return <String, dynamic>{};
}

List<Map<String, dynamic>> asList(dynamic v) {
  if (v is! List) return const <Map<String, dynamic>>[];
  return v
      .whereType<Map>()
      .map((e) => e.map((k, val) => MapEntry(k.toString(), val)))
      .toList(growable: false);
}

List<String> asStrList(dynamic v) {
  if (v is! List) return const <String>[];
  return v.map((e) => asStr(e)).where((e) => e.isNotEmpty).toList();
}

class ApiException implements Exception {
  ApiException(this.message, {this.status});
  final String message;
  final int? status;

  bool get isAuth => status == 401;
  bool get isNetwork => status == null;

  @override
  String toString() => message;
}

/// 站点接口层。所有请求都走同一个域名，Cookie 会话保存在本地。
class Api {
  Api._();
  static final Api i = Api._();

  static const String _kCookie = 'thj_session_cookie';

  String? _cookie;
  bool _loaded = false;
  bool online = true;
  String? lastError;
  int? lastMs;

  String get base => AppMeta.baseUrl;
  String? get cookie => _cookie;
  bool get hasSession => _cookie != null && _cookie!.isNotEmpty;

  Future<void> init() async {
    if (_loaded) return;
    final sp = await SharedPreferences.getInstance();
    _cookie = sp.getString(_kCookie);
    _loaded = true;
  }

  Future<void> _saveCookie(String? raw) async {
    _cookie = raw;
    final sp = await SharedPreferences.getInstance();
    if (raw == null || raw.isEmpty) {
      await sp.remove(_kCookie);
    } else {
      await sp.setString(_kCookie, raw);
    }
  }

  Future<void> clearSession() => _saveCookie(null);

  String abs(String pathOrUrl) {
    final s = pathOrUrl.trim();
    if (s.isEmpty) return s;
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    return '${AppMeta.baseUrl}${s.startsWith('/') ? '' : '/'}$s';
  }

  String avatarUrl(String name, {int size = 96}) =>
      '${AppMeta.baseUrl}/api/avatar/${Uri.encodeComponent(name)}?size=$size';

  String cardUrl(String name) =>
      '${AppMeta.baseUrl}/api/card/${Uri.encodeComponent(name)}.png';

  Map<String, String> _headers({bool json = true}) {
    final h = <String, String>{
      'Accept': 'application/json, text/plain, */*',
      'User-Agent': '${AppMeta.appNameEn}/${AppMeta.version} (Android)',
    };
    if (json) h['Content-Type'] = 'application/json; charset=utf-8';
    if (_cookie != null && _cookie!.isNotEmpty) h['Cookie'] = _cookie!;
    return h;
  }

  /// 解析 Set-Cookie。Expires 里也有逗号，所以只在下一位像 `name=` 时切分。
  void _absorbCookies(http.BaseResponse res) {
    final raw = res.headers['set-cookie'];
    if (raw == null || raw.isEmpty) return;
    final parts = raw.split(RegExp(r',(?=\s*[A-Za-z0-9_\-]+=)'));
    final map = <String, String>{};
    for (final c in (_cookie ?? '').split(';')) {
      final kv = c.split('=');
      if (kv.length >= 2 && kv[0].trim().isNotEmpty) {
        map[kv[0].trim()] = kv.sublist(1).join('=').trim();
      }
    }
    for (final p in parts) {
      final first = p.split(';').first.trim();
      final kv = first.split('=');
      if (kv.length >= 2 && kv[0].trim().isNotEmpty) {
        map[kv[0].trim()] = kv.sublist(1).join('=').trim();
      }
    }
    if (map.isNotEmpty) {
      _saveCookie(map.entries.map((e) => '${e.key}=${e.value}').join('; '));
    }
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final u = Uri.parse('${AppMeta.baseUrl}$path');
    if (query == null || query.isEmpty) return u;
    final q = <String, String>{};
    query.forEach((k, v) {
      if (v == null) return;
      if (v is bool) {
        q[k] = v ? '1' : '0';
      } else {
        q[k] = v.toString();
      }
    });
    return u.replace(queryParameters: {...u.queryParameters, ...q});
  }

  Future<http.Response> _send(
    Future<http.Response> Function() run,
  ) async {
    await init();
    Object? last;
    final sw = Stopwatch()..start();
    const delays = <int>[0, 350, 900];
    for (final delay in delays) {
      if (delay > 0) {
        await Future<void>.delayed(Duration(milliseconds: delay));
      }
      try {
        final res = await run().timeout(const Duration(seconds: 18));
        online = true;
        lastError = null;
        lastMs = sw.elapsedMilliseconds;
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
    lastError = last?.toString();
    throw ApiException(
      '连接不上服务器，请检查网络\n${last?.toString() ?? '网络不可用'}',
    );
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> body = <String, dynamic>{};
    if (res.bodyBytes.isNotEmpty) {
      try {
        body = asMap(jsonDecode(utf8.decode(res.bodyBytes)));
      } catch (_) {
        if (res.statusCode >= 400) {
          throw ApiException('服务器返回异常（HTTP ${res.statusCode}）',
              status: res.statusCode);
        }
        throw ApiException('返回内容无法解析（HTTP ${res.statusCode}）',
            status: res.statusCode);
      }
    }
    if (res.statusCode == 401) {
      throw ApiException(asStr(body['error'], '请先登录'), status: 401);
    }
    if (res.statusCode >= 400) {
      throw ApiException(
        asStr(body['error'], '请求失败（HTTP ${res.statusCode}）'),
        status: res.statusCode,
      );
    }
    if (body['ok'] == false) {
      throw ApiException(asStr(body['error'] ?? body['msg'], '操作失败'));
    }
    return body;
  }

  Future<Map<String, dynamic>> get(String path,
      [Map<String, dynamic>? query]) async {
    final res = await _send(() => http.get(_uri(path, query), headers: _headers(json: false)));
    return _decode(res);
  }

  Future<Map<String, dynamic>> post(String path,
      [Map<String, dynamic>? body]) async {
    final res = await _send(() => http.post(
          _uri(path),
          headers: _headers(),
          body: jsonEncode(body ?? <String, dynamic>{}),
        ));
    return _decode(res);
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final res = await _send(() => http.delete(_uri(path), headers: _headers()));
    return _decode(res);
  }

  // ---------------- 站点 / 首页 ----------------

  Future<Map<String, dynamic>> health() => get('/api/health');

  Future<Map<String, dynamic>> brand() => get('/api/brand');

  Future<Map<String, dynamic>> status({bool showFakes = false}) =>
      get('/api/status', showFakes ? {'fakes': 1} : null);

  Future<Map<String, dynamic>> season() => get('/api/season');

  // ---------------- 账号 ----------------

  Future<Map<String, dynamic>> authMe() => get('/api/auth/me');

  Future<Map<String, dynamic>> login(String username, String password) =>
      post('/api/auth/login', {'username': username, 'password': password});

  Future<Map<String, dynamic>> register(String username, String password,
          {String? qq}) =>
      post('/api/auth/register', {
        'username': username,
        'password': password,
        if (qq != null && qq.isNotEmpty) 'qq': qq,
      });

  Future<void> logout() async {
    try {
      await post('/api/auth/logout');
    } catch (_) {
      // 本地必须能退出
    }
    await clearSession();
  }

  Future<Map<String, dynamic>> changePassword(
          String oldPassword, String newPassword) =>
      post('/api/auth/password', {
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      });

  // ---------------- 绑定游戏账号 ----------------

  Future<Map<String, dynamic>> bindStatus() => get('/api/bind/status');

  Future<Map<String, dynamic>> bindStart() => post('/api/bind/start');

  Future<void> unbind() => delete('/api/bind');

  // ---------------- 通知 ----------------

  Future<Map<String, dynamic>> notifications() => get('/api/notifications');

  Future<Map<String, dynamic>> notificationsGrouped() =>
      get('/api/notifications/grouped');

  Future<void> readNotification([int? id]) => post('/api/notifications/read',
      id == null ? const <String, dynamic>{} : {'id': id});

  Future<void> readAllNotifications() => post('/api/notifications/read');

  // ---------------- 私信 / 聊天 ----------------

  Future<Map<String, dynamic>> chatRecent({int limit = 80}) =>
      get('/api/chat/recent', {'limit': limit});

  Future<Map<String, dynamic>> chatSend(String text) =>
      post('/api/chat', {'text': text});

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

  Future<Map<String, dynamic>> dmMeta(int userId) => get('/api/dm/$userId/meta');

  Future<Map<String, dynamic>> dmPin(int userId, {bool? value}) =>
      post('/api/dm/$userId/pin', value == null ? {} : {'value': value});

  Future<Map<String, dynamic>> dmMute(int userId, {bool? value}) =>
      post('/api/dm/$userId/mute', value == null ? {} : {'value': value});

  Future<Map<String, dynamic>> dmRevoke(int userId, int messageId) =>
      post('/api/dm/$userId/revoke', {'messageId': messageId});

  Future<void> dmRead(int userId) => post('/api/dm/$userId/read');

  Future<void> dmDelete(int userId) => delete('/api/dm/$userId');

  // ---------------- 好友 / 社交 ----------------

  Future<Map<String, dynamic>> friends() => get('/api/friends');

  Future<Map<String, dynamic>> friendsEnriched() => get('/api/friends/enriched');

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

  Future<Map<String, dynamic>> following() => get('/api/me/following');

  Future<Map<String, dynamic>> followers() => get('/api/me/followers');

  Future<Map<String, dynamic>> collections() => get('/api/me/collections');

  Future<Map<String, dynamic>> follow(String username) =>
      post('/api/follow/${Uri.encodeComponent(username)}');

  Future<Map<String, dynamic>> space(String username) =>
      get('/api/space/${Uri.encodeComponent(username)}');

  Future<Map<String, dynamic>> profile(String username) =>
      get('/api/profile/${Uri.encodeComponent(username)}');

  Future<Map<String, dynamic>> guestbook(String username, {int limit = 30}) =>
      get('/api/guestbook/${Uri.encodeComponent(username)}', {'limit': limit});

  Future<Map<String, dynamic>> postGuestbook(String username, String body,
          {int? replyTo}) =>
      post('/api/guestbook/${Uri.encodeComponent(username)}', {
        'body': body,
        if (replyTo != null) 'replyTo': replyTo,
      });

  Future<Map<String, dynamic>> deleteGuestbook(int id) =>
      delete('/api/guestbook/$id');

  // ---------------- 搜索 ----------------

  Future<Map<String, dynamic>> search(String q) => get('/api/search', {'q': q});

  Future<Map<String, dynamic>> userSearch(String q) =>
      get('/api/users/search', {'q': q});

  // ---------------- 排行 / 玩家 ----------------

  Future<Map<String, dynamic>> rankBoard({
    int limit = 30,
    int offset = 0,
    String? tier,
    bool showFakes = false,
  }) =>
      get('/api/rank/board', {
        'limit': limit,
        'offset': offset,
        if (tier != null && tier.isNotEmpty) 'tier': tier,
        if (showFakes) 'fakes': 1,
      });

  Future<Map<String, dynamic>> rankCurve() => get('/api/rank/curve');

  Future<Map<String, dynamic>> rankDetail(String name) =>
      get('/api/rank/${Uri.encodeComponent(name)}');

  Future<Map<String, dynamic>> player(String name) =>
      get('/api/player/${Uri.encodeComponent(name)}');

  Future<Map<String, dynamic>> leaderboard(String by) =>
      get('/api/leaderboard', {'by': by});

  Future<Map<String, dynamic>> myRank() => get('/api/me/rank');

  // ---------------- 论坛 ----------------

  Future<Map<String, dynamic>> forumBoards() => get('/api/forum/boards');

  Future<Map<String, dynamic>> forumThreads({
    String? board,
    int page = 1,
    int size = 20,
    String sort = 'new',
  }) =>
      get('/api/forum/threads', {
        if (board != null && board.isNotEmpty) 'board': board,
        'page': page,
        'size': size,
        'sort': sort,
      });

  Future<Map<String, dynamic>> forumThread(int id) =>
      get('/api/forum/thread/$id');

  Future<Map<String, dynamic>> forumNewThread({
    required String board,
    required String title,
    required String body,
    List<String>? images,
  }) =>
      post('/api/forum/threads', {
        'board': board,
        'title': title,
        'body': body,
        if (images != null && images.isNotEmpty) 'images': images,
      });

  Future<Map<String, dynamic>> forumReply(int id, String body,
          {List<String>? images}) =>
      post('/api/forum/thread/$id/reply', {
        'body': body,
        if (images != null && images.isNotEmpty) 'images': images,
      });

  Future<Map<String, dynamic>> forumLike(String kind, int id) =>
      post('/api/forum/like', {'kind': kind, 'id': id});

  Future<Map<String, dynamic>> forumEditThread(int id,
          {String? title, String? body, List<String>? images}) =>
      post('/api/forum/thread/$id/edit', {
        if (title != null) 'title': title,
        if (body != null) 'body': body,
        if (images != null) 'images': images,
      });

  Future<void> forumDeleteThread(int id) => delete('/api/forum/thread/$id');

  Future<Map<String, dynamic>> forumEditPost(int id,
          {String? body, List<String>? images}) =>
      post('/api/forum/post/$id/edit', {
        if (body != null) 'body': body,
        if (images != null) 'images': images,
      });

  Future<void> forumDeletePost(int id) => delete('/api/forum/post/$id');

  Future<Map<String, dynamic>> collectThread(int id) =>
      post('/api/collect/thread/$id');

  Future<Map<String, dynamic>> uploadImage(String dataUrl,
          {String kind = 'forum'}) =>
      post('/api/upload/image', {'data': dataUrl, 'kind': kind});

  // ---------------- 个人资料 ----------------

  Future<Map<String, dynamic>> saveProfile(
          {String? bio, String? bg, List<String>? tags}) =>
      post('/api/profile', {
        if (bio != null) 'bio': bio,
        if (bg != null) 'bg': bg,
        if (tags != null) 'tags': tags,
      });

  Future<Map<String, dynamic>> myAvatar() => get('/api/me/avatar');

  Future<Map<String, dynamic>> setAvatar(String dataUrl) =>
      post('/api/me/avatar', {'data': dataUrl});

  Future<void> deleteAvatar() => delete('/api/me/avatar');

  Future<Map<String, dynamic>> myBg() => get('/api/me/bg');

  Future<Map<String, dynamic>> setBg(String dataUrl) =>
      post('/api/me/bg', {'data': dataUrl});

  Future<void> deleteBg() => delete('/api/me/bg');

  Future<Map<String, dynamic>> privacy() => get('/api/settings/privacy');

  Future<Map<String, dynamic>> setPrivacy(Map<String, dynamic> patch) =>
      post('/api/settings/privacy', patch);

  Future<Map<String, dynamic>> notifySettings() => get('/api/settings/notify');

  Future<Map<String, dynamic>> setNotifySettings(Map<String, dynamic> patch) =>
      post('/api/settings/notify', patch);

  // ---------------- 活动 / 签到 / 相册 ----------------

  Future<Map<String, dynamic>> festival() => get('/api/festival');

  Future<Map<String, dynamic>> festivalCheckin() =>
      post('/api/festival/checkin');

  Future<Map<String, dynamic>> festivalBoard() => get('/api/festival/board');

  Future<Map<String, dynamic>> album() => get('/api/album');

  // ---------------- 商城 / 会员 / 支付 ----------------

  Future<Map<String, dynamic>> shopConfig() => get('/api/shop/config');

  Future<Map<String, dynamic>> shopProducts() => get('/api/shop/products');

  Future<Map<String, dynamic>> shopOrder(Map<String, dynamic> body) =>
      post('/api/shop/order', body);

  Future<Map<String, dynamic>> shopOrders() => get('/api/shop/orders');

  Future<Map<String, dynamic>> shopSubmit(int id, Map<String, dynamic> body) =>
      post('/api/shop/order/$id/submit', body);

  Future<Map<String, dynamic>> shopCloseOrder(int id) =>
      post('/api/shop/order/$id/close');

  Future<Map<String, dynamic>> shopRedeem(String code) =>
      post('/api/shop/redeem', {'code': code});

  Future<Map<String, dynamic>> tiers() => get('/api/tiers');

  Future<Map<String, dynamic>> payInfo() => get('/api/pay/info');

  Future<Map<String, dynamic>> paySubmit(Map<String, dynamic> body) =>
      post('/api/pay/submit', body);

  Future<Map<String, dynamic>> membership() => get('/api/me/membership');

  Future<Map<String, dynamic>> myPayments() => get('/api/me/payments');

  // ---------------- SMP ----------------

  Future<Map<String, dynamic>> smp() => get('/api/smp');

  Future<Map<String, dynamic>> smpMap() => get('/api/smp/map');

  Future<Map<String, dynamic>> smpSignup({bool publicPos = true}) =>
      post('/api/smp/signup', {'publicPos': publicPos});

  Future<Map<String, dynamic>> smpWithdraw() => post('/api/smp/withdraw');

  Future<Map<String, dynamic>> smpPos({required bool publicPos}) =>
      post('/api/smp/pos', {'publicPos': publicPos});

  // ---------------- 庄园杯 ----------------

  Future<Map<String, dynamic>> manorPublic() => get('/manor/api/public');

  Future<Map<String, dynamic>> manorIdentity() => get('/api/manor/identity');

  Future<Map<String, dynamic>> manorRegister(
          {String qq = '', String motto = ''}) =>
      post('/api/manor/register', {'qq': qq, 'motto': motto});

  Future<Map<String, dynamic>> manorVisit(String mode) =>
      post('/api/manor/visit', {'mode': mode});

  // ---------------- 举报 ----------------

  Future<Map<String, dynamic>> reportReasons() => get('/api/report/reasons');

  Future<Map<String, dynamic>> reportCreate(Map<String, dynamic> body) =>
      post('/api/reports', body);

  Future<Map<String, dynamic>> myReports() => get('/api/reports/mine');

  // ---------------- App 更新 / 远程配置 ----------------

  Future<Map<String, dynamic>> appVersion() => get('/api/app/version');

  Future<Map<String, dynamic>> appConfig() => get('/api/app/config');
}
