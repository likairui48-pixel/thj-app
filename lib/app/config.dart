/// 全局配置与「后续更新接口」的预留位
///
/// 设计原则：凡是将来可能变的东西，都不要写死在页面里。
///  - 服务器地址：可被用户在设置页覆盖，且内置自动故障转移
///  - 底部导航项：由 [FeatureRegistry] 决定，可被服务端远程配置覆盖
///  - 版本/更新：由 [AppMeta] + UpdateService 提供，接口已留好
library;

/// 应用元信息（与 pubspec.yaml 的 version 保持一致）
class AppMeta {
  AppMeta._();

  static const String appName = '同禾境';
  static const String appNameEn = 'TongHeJing';
  static const String version = '1.1.1';
  static const int versionCode = 3;
  static const String packageId = 'cn.mcfuns.thj';
  static const String qqGroupFallback = '1032612899';

  /// 用户可见的版本串，如 1.0.0 (1)
  static String get versionLabel => '$version ($versionCode)';
}

/// 服务器地址候选（按顺序尝试，第一个成功即记住）
class Endpoints {
  Endpoints._();

  static const List<String> defaults = <String>[
    'https://thjmc.duckdns.org:8443', // 主：HTTPS（Cloudflare 隧道/正式域名就绪后替换这里）
    'http://211.101.233.180:8080',    // 保底：明文入口（未备案时的直连通道）
  ];

  /// 更新清单接口（站点提供；未实现时 App 静默跳过，不会报错）
  static const String versionPath = '/api/app/version';
  /// 远程配置接口（可控制底部栏、功能开关；未实现时用本地默认）
  static const String configPath = '/api/app/config';
}

/// 一个底部导航项 / 功能入口
class FeatureSpec {
  const FeatureSpec({
    required this.id,
    required this.label,
    required this.icon,
    this.enabled = true,
    this.badge = false,
    this.url,
  });

  final String id;
  final String label;
  final String icon; // 用语义名，映射到 IconData（远程配置只传字符串）
  final bool enabled;
  final bool badge; // 是否显示未读小红点
  final String? url; // 若为网页型入口

  factory FeatureSpec.fromJson(Map<String, dynamic> j, FeatureSpec fallback) {
    return FeatureSpec(
      id: (j['id'] ?? fallback.id).toString(),
      label: (j['label'] ?? fallback.label).toString(),
      icon: (j['icon'] ?? fallback.icon).toString(),
      enabled: j['enabled'] is bool ? j['enabled'] as bool : fallback.enabled,
      badge: j['badge'] is bool ? j['badge'] as bool : fallback.badge,
      url: j['url']?.toString() ?? fallback.url,
    );
  }
}

/// 功能注册表：v1 的内置定义 + 远程覆盖能力
class FeatureRegistry {
  FeatureRegistry._();

  /// 本地默认（v1.1 版底部栏）——改这里就能加新 Tab
  static const List<FeatureSpec> defaults = <FeatureSpec>[
    FeatureSpec(id: 'home', label: '首页', icon: 'home'),
    FeatureSpec(id: 'rank', label: '排行', icon: 'rank'),
    FeatureSpec(id: 'community', label: '社区', icon: 'community', url: '/feed'),
    FeatureSpec(id: 'messages', label: '消息', icon: 'message', badge: true),
    FeatureSpec(id: 'me', label: '我的', icon: 'person'),
  ];

  /// 运行期生效的表（可被远程配置替换）
  static List<FeatureSpec> active = List<FeatureSpec>.from(defaults);

  /// 预留：未来功能开关（服务端下发后无需更新 App）
  static final Map<String, bool> flags = <String, bool>{
    'chat': false,      // 游戏内聊天互通
    'shop': false,      // 会员商城（合规原因先关）
    'douyin': false,    // 未来的短视频/直播入口
  };

  static void applyRemote(Map<String, dynamic> json) {
    final tabs = json['tabs'];
    if (tabs is List && tabs.isNotEmpty) {
      final next = <FeatureSpec>[];
      for (var i = 0; i < tabs.length; i++) {
        final raw = tabs[i];
        if (raw is! Map) continue;
        final map = raw.map((k, v) => MapEntry(k.toString(), v));
        final fallback = i < defaults.length
            ? defaults[i]
            : const FeatureSpec(id: 'x', label: '更多', icon: 'more');
        next.add(FeatureSpec.fromJson(map, fallback));
      }
      if (next.isNotEmpty) active = next;
    }
    final f = json['features'];
    if (f is Map) {
      f.forEach((k, v) {
        if (v is bool) flags[k.toString()] = v;
      });
    }
  }

  static bool enabled(String key) => flags[key] ?? false;
}

/// 刷新节奏（务必尊重站点对游戏服的保护：最小间隔见《功能列表》0.5 节）
class RefreshPolicy {
  RefreshPolicy._();

  static const Duration statusMin = Duration(seconds: 15); // 首页在线人数
  static const Duration unread = Duration(seconds: 45);    // 未读消息轮询
  static const Duration httpTimeout = Duration(seconds: 15);
}
