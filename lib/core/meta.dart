/// 应用与站点常量。版本号只在这里改，更新接口和设置页都读这里。
class AppMeta {
  AppMeta._();

  static const String appName = '同禾境';
  static const String appNameEn = 'TongHeJing';
  static const String version = '1.0.0';
  static const int versionCode = 1;

  /// 站点唯一入口：只走域名，避免 IP 直连在部分网络下被拦截。
  static const String baseUrl = 'https://thjmc.duckdns.org:8443';

  static const String packageId = 'cn.mcfuns.thj';
  static const String qqGroup = '1032612899';
  static const String siteUrl = 'https://thjmc.duckdns.org:8443';
}
