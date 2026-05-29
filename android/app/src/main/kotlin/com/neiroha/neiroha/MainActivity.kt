package com.neiroha.neiroha

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var mediaChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "neiroha/android_media_session"
        )
        mediaChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startOrUpdateNovelSession" -> {
                    requestNotificationPermissionIfNeeded()
                    val title = call.argument<String>("title") ?: "Novel Reader"
                    val subtitle = call.argument<String>("subtitle") ?: ""
                    val isPlaying = call.argument<Boolean>("isPlaying") ?: false
                    val positionMs = call.argument<Number>("positionMs")?.toLong() ?: 0L
                    val durationMs = call.argument<Number>("durationMs")?.toLong() ?: 0L
                    val intent = Intent(this, NovelReaderForegroundService::class.java).apply {
                        action = NovelReaderForegroundService.ACTION_UPDATE
                        putExtra(NovelReaderForegroundService.EXTRA_TITLE, title)
                        putExtra(NovelReaderForegroundService.EXTRA_SUBTITLE, subtitle)
                        putExtra(NovelReaderForegroundService.EXTRA_IS_PLAYING, isPlaying)
                        putExtra(NovelReaderForegroundService.EXTRA_POSITION_MS, positionMs)
                        putExtra(NovelReaderForegroundService.EXTRA_DURATION_MS, durationMs)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                }
                "stopNovelSession" -> {
                    stopService(Intent(this, NovelReaderForegroundService::class.java))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        NovelReaderMediaBridge.controlSink = { control ->
            runOnUiThread {
                mediaChannel?.invokeMethod("control", control)
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        if (mediaChannel != null) {
            NovelReaderMediaBridge.controlSink = null
            mediaChannel?.setMethodCallHandler(null)
            mediaChannel = null
        }
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST_CODE
        )
    }

    companion object {
        private const val NOTIFICATION_PERMISSION_REQUEST_CODE = 4101
    }
}
