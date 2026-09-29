package cn.mcfuns.thj

import io.flutter.embedding.android.FlutterActivity

/**
 * 同禾境客户端宿主 Activity。
 * 保持极简：所有能力（通知、WebView、外部跳转）都由 Flutter 插件完成，
 * 这样安卓侧没有自维护代码，后续升级 Flutter 不会踩坑。
 */
class MainActivity : FlutterActivity()
