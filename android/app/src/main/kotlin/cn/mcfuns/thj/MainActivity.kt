package cn.mcfuns.thj

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 同禾境客户端宿主 Activity。
 *
 * 除了承载 Flutter，只多做一件事：暴露一条方法通道给 Flutter，
 * 用来开关「后台接收私信」的前台服务，以及跳系统的省电/自启动设置。
 * 保持极简：不引任何原生第三方库，后续升级 Flutter 不会踩坑。
 */
class MainActivity : FlutterActivity() {

    private val channelName = "cn.mcfuns.thj/keepalive"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        try {
                            val i = Intent(this, KeepAliveService::class.java)
                                .setAction(KeepAliveService.ACTION_START)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(i)
                            } else {
                                startService(i)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "stop" -> {
                        try {
                            stopService(Intent(this, KeepAliveService::class.java))
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "isRunning" -> {
                        // 简化判断：服务是否已被我们标记启动（Flutter 侧只用于显示状态）
                        result.success(false)
                    }
                    "ignoringBatteryOptimizations" ->
                        result.success(PowerHelper.isIgnoringBatteryOptimizations(this))
                    "openBatterySettings" -> {
                        PowerHelper.openBatterySettings(this)
                        result.success(true)
                    }
                    "openAutoStartSettings" -> {
                        PowerHelper.openAutoStartSettings(this)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
