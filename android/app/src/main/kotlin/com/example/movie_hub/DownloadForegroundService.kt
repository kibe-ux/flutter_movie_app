package com.example.movie_hub

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import io.flutter.plugin.common.MethodChannel

/** Keeps the existing Flutter engine's transfers alive while the UI is away. */
class DownloadForegroundService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null
    private var movieId = 0
    private var title = "Movie download"
    private var percent = 0

    override fun onCreate() {
        super.onCreate()
        instance = this
        if (Build.VERSION.SDK_INT >= 26) {
            getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(CHANNEL, "Movie downloads", NotificationManager.IMPORTANCE_LOW)
            )
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "pause" || intent?.action == "cancel") {
            bridge?.invokeMethod("control", mapOf("action" to intent.action, "movieId" to movieId))
            return START_NOT_STICKY
        }
        movieId = intent?.getIntExtra("movieId", 0) ?: 0
        title = intent?.getStringExtra("title") ?: "Movie download"
        try {
            if (Build.VERSION.SDK_INT >= 29) {
                startForeground(NOTIFICATION, notification(), ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
            } else {
                startForeground(NOTIFICATION, notification())
            }
            wakeLock = (getSystemService(Context.POWER_SERVICE) as PowerManager)
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "moviehub:download").apply {
                    setReferenceCounted(false)
                    acquire(10 * 60 * 1000L)
                }
            pendingStart?.success(null)
            pendingStart = null
        } catch (_: Exception) {
            pendingStart?.error("BACKGROUND_UNAVAILABLE", "Open the app to resume this download.", null)
            pendingStart = null
            stopSelf()
        }
        // After process death the disk queue is recovered by the next app launch.
        return START_NOT_STICKY
    }

    fun update(id: Int, name: String, value: Int) {
        movieId = id
        title = name
        percent = value
        wakeLock?.acquire(10 * 60 * 1000L)
        getSystemService(NotificationManager::class.java).notify(NOTIFICATION, notification())
    }

    private fun notification(): Notification {
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val open = PendingIntent.getActivity(this, 0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP), flags)
        fun control(action: String, code: Int) = PendingIntent.getService(this, code,
            Intent(this, DownloadForegroundService::class.java).setAction(action), flags)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL)
                      else @Suppress("DEPRECATION") Notification.Builder(this)
        return builder.setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle(title).setContentText("Downloading · $percent%")
            .setContentIntent(open).setOngoing(true).setOnlyAlertOnce(true)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setProgress(100, percent, percent == 0)
            .addAction(Notification.Action.Builder(null, "Pause", control("pause", 1)).build())
            .addAction(Notification.Action.Builder(null, "Cancel", control("cancel", 2)).build())
            .build()
    }

    override fun onTimeout(startId: Int, fgsType: Int) {
        bridge?.invokeMethod("control", mapOf("action" to "pauseAll"))
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        if (wakeLock?.isHeld == true) wakeLock?.release()
        wakeLock = null
        instance = null
        pendingStops.forEach { it.success(null) }
        pendingStops.clear()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        private const val CHANNEL = "movie_downloads"
        private const val NOTIFICATION = 7401
        var instance: DownloadForegroundService? = null
        var bridge: MethodChannel? = null
        private var pendingStart: MethodChannel.Result? = null
        private val pendingStops = mutableListOf<MethodChannel.Result>()

        fun attach(context: Context, channel: MethodChannel) {
            val app = context.applicationContext
            bridge = channel
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val id = call.argument<Int>("movieId") ?: 0
                        val name = call.argument<String>("title") ?: "Movie download"
                        val current = instance
                        if (current != null) {
                            current.update(id, name, 0)
                            result.success(null)
                        } else {
                            pendingStart = result
                            val intent = Intent(app, DownloadForegroundService::class.java)
                                .putExtra("movieId", id).putExtra("title", name)
                            try {
                                if (Build.VERSION.SDK_INT >= 26) app.startForegroundService(intent)
                                else app.startService(intent)
                            } catch (_: Exception) {
                                pendingStart = null
                                result.error("BACKGROUND_UNAVAILABLE", "Open the app to resume this download.", null)
                            }
                        }
                    }
                    "update" -> {
                        instance?.update(call.argument<Int>("movieId") ?: 0,
                            call.argument<String>("title") ?: "Movie download",
                            call.argument<Int>("percent") ?: 0)
                        result.success(null)
                    }
                    "stop" -> {
                        if (instance == null) result.success(null)
                        else {
                            pendingStops.add(result)
                            app.stopService(Intent(app, DownloadForegroundService::class.java))
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }
}
