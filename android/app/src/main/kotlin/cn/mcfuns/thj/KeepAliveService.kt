package cn.mcfuns.thj

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.provider.Settings

/**
 * 同禾境客户端「后台接收私信」用的前台服务。
 *
 * 为什么需要它：安卓会随时回收后台进程，进程没了，长连接也就断了，
 * 消息自然收不到。系统唯一允许「合理长期存活」的方式就是前台服务。
 *
 * 注意：安卓 8.0+ 规定前台服务**必须**有通知。这里把它做成静默级别
 * （IMPORTANCE_MIN + 无声音/无震动/不显示状态栏图标），把打扰降到最低。
 * 用户不想看到这条通知时，可以在 App 设置里选「仅在打开时接收」，
 * 那时这个服务根本不会启动。
 */
class KeepAliveService : Service() {

    companion object {
        const val CHANNEL_ID = "thj_keepalive"
        const val NOTIF_ID = 0x7A01  // 固定 id，避免重复占位
        const val ACTION_START = "cn.mcfuns.thj.START_KEEPALIVE"
        const val ACTION_STOP = "cn.mcfuns.thj.STOP_KEEPALIVE"
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        ensureChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopForegroundCompat()
            stopSelf()
            return START_NOT_STICKY
        }
        startForegroundCompat()
        return START_STICKY
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        val ch = NotificationChannel(
            CHANNEL_ID,
            "后台接收消息",
            NotificationManager.IMPORTANCE_MIN   // 静默：不响、不震、不弹
        )
        ch.description = "保持与同禾境服务器的连接，以便在后台也能收到私信"
        ch.setShowBadge(false)
        ch.enableLights(false)
        ch.enableVibration(false)
        ch.setSound(null, null)
        nm.createNotificationChannel(ch)
    }

    private fun startForegroundCompat() {
        val open = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pi = PendingIntent.getActivity(
            this, 0, open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val n = builder
            .setContentTitle("同禾境")
            .setContentText("正在后台接收私信（静默运行）")
            .setSmallIcon(applicationInfo.icon)
            .setContentIntent(pi)
            .setOngoing(true)
            .setShowWhen(false)
            .setPriority(Notification.PRIORITY_MIN)
            .build()

        if (Build.VERSION.SDK_INT >= 34) {
            // Android 14+ 必须声明前台服务类型
            startForeground(NOTIF_ID, n, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIF_ID, n,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )
        } else {
            startForeground(NOTIF_ID, n)
        }
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    override fun onDestroy() {
        stopForegroundCompat()
        super.onDestroy()
    }
}

/** 省电白名单 / 自启动设置的跳转助手 */
object PowerHelper {
    fun isIgnoringBatteryOptimizations(ctx: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val pm = ctx.getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
        return pm.isIgnoringBatteryOptimizations(ctx.packageName)
    }

    fun openBatterySettings(ctx: Context) {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = android.net.Uri.parse("package:" + ctx.packageName)
            }
        } else {
            Intent(Settings.ACTION_SETTINGS)
        }
        try {
            ctx.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (e: Exception) {
            // 部分 ROM 禁用了这个 action，退回到应用详情页
            try {
                ctx.startActivity(
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        .setData(android.net.Uri.parse("package:" + ctx.packageName))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
            } catch (_: Exception) {
            }
        }
    }

    /** 国产 ROM 的自启动管理页：挨个试，哪个能开就开 */
    fun openAutoStartSettings(ctx: Context) {
        val candidates = listOf(
            "com.miui.securitycenter/com.miui.permcenter.autostart.AutoStartManagementActivity",
            "com.huawei.systemmanager/.startupmgr.ui.StartupNormalAppListActivity",
            "com.coloros.safecenter/.permission.startup.StartupAppListActivity",
            "com.oppo.safe/.permission.startup.StartupAppListActivity",
            "com.vivo.permissionmanager/.activity.BgStartUpManagerActivity",
            "com.iqoo.secure/.safeguard.PurviewTabActivity",
            "com.meizu.safe/.permission.SmartBGActivity",
            "com.samsung.android.lool/com.samsung.android.sm.ui.battery.BatteryActivity"
        )
        for (c in candidates) {
            try {
                val parts = c.split("/")
                val intent = Intent().setClassName(parts[0], parts[1])
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                ctx.startActivity(intent)
                return
            } catch (_: Exception) {
            }
        }
        // 都不行就打开应用详情
        try {
            ctx.startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    .setData(android.net.Uri.parse("package:" + ctx.packageName))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        } catch (_: Exception) {
        }
    }
}
