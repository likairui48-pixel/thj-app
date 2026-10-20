package cn.mcfuns.thj.next

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var linkChannel: MethodChannel? = null
    private var pendingLink: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "thj/keepalive",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "set" -> {
                    val on = call.argument<Boolean>("on") ?: false
                    val intent = Intent(this, KeepAliveService::class.java)
                    if (on) {
                        startForegroundService(intent)
                    } else {
                        stopService(intent)
                    }
                    result.success(true)
                }
                "openSettings" -> {
                    try {
                        val intent = Intent(
                            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.parse("package:$packageName"),
                        )
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        linkChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "thj/deeplink",
        )
        linkChannel?.setMethodCallHandler { call, result ->
            if (call.method == "initial") {
                result.success(pendingLink)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val data = intent?.data?.toString() ?: return
        pendingLink = data
        linkChannel?.invokeMethod("link", data)
    }
}
