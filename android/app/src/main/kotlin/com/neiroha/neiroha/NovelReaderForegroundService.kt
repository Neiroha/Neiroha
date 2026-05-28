package com.neiroha.neiroha

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.IBinder

object NovelReaderMediaBridge {
    var controlSink: ((String) -> Unit)? = null

    fun sendControl(control: String) {
        controlSink?.invoke(control)
    }
}

class NovelReaderForegroundService : Service() {
    private lateinit var mediaSession: MediaSession
    private var title: String = "Novel Reader"
    private var subtitle: String = ""
    private var isPlaying: Boolean = false

    override fun onCreate() {
        super.onCreate()
        ensureNotificationChannel()
        mediaSession = MediaSession(this, "Neiroha Novel Reader").apply {
            setCallback(object : MediaSession.Callback() {
                override fun onPlay() = NovelReaderMediaBridge.sendControl("play")
                override fun onPause() = NovelReaderMediaBridge.sendControl("pause")
                override fun onSkipToNext() = NovelReaderMediaBridge.sendControl("next")
                override fun onSkipToPrevious() = NovelReaderMediaBridge.sendControl("previous")
                override fun onStop() = NovelReaderMediaBridge.sendControl("stop")
            })
            isActive = true
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_UPDATE -> {
                title = intent.getStringExtra(EXTRA_TITLE)?.ifBlank { null } ?: "Novel Reader"
                subtitle = intent.getStringExtra(EXTRA_SUBTITLE).orEmpty()
                isPlaying = intent.getBooleanExtra(EXTRA_IS_PLAYING, false)
                updateMediaSession()
                startForegroundCompat(buildNotification())
            }
            ACTION_TOGGLE -> NovelReaderMediaBridge.sendControl("toggle")
            ACTION_PREVIOUS -> NovelReaderMediaBridge.sendControl("previous")
            ACTION_NEXT -> NovelReaderMediaBridge.sendControl("next")
            ACTION_STOP -> {
                NovelReaderMediaBridge.sendControl("stop")
                hideForeground()
                stopSelf()
                return START_NOT_STICKY
            }
            else -> {
                stopSelf(startId)
                return START_NOT_STICKY
            }
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        mediaSession.isActive = false
        mediaSession.release()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun updateMediaSession() {
        val state = if (isPlaying) {
            PlaybackState.STATE_PLAYING
        } else {
            PlaybackState.STATE_PAUSED
        }
        val actions = PlaybackState.ACTION_PLAY_PAUSE or
            PlaybackState.ACTION_PLAY or
            PlaybackState.ACTION_PAUSE or
            PlaybackState.ACTION_SKIP_TO_NEXT or
            PlaybackState.ACTION_SKIP_TO_PREVIOUS or
            PlaybackState.ACTION_STOP

        mediaSession.setMetadata(
            MediaMetadata.Builder()
                .putString(MediaMetadata.METADATA_KEY_TITLE, title)
                .putString(MediaMetadata.METADATA_KEY_ARTIST, subtitle)
                .putString(MediaMetadata.METADATA_KEY_ALBUM, "Neiroha Novel Reader")
                .build()
        )
        mediaSession.setPlaybackState(
            PlaybackState.Builder()
                .setActions(actions)
                .setState(state, PlaybackState.PLAYBACK_POSITION_UNKNOWN, 1.0f)
                .build()
        )
    }

    private fun buildNotification(): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val playPauseIcon = if (isPlaying) {
            android.R.drawable.ic_media_pause
        } else {
            android.R.drawable.ic_media_play
        }
        val playPauseTitle = if (isPlaying) "Pause" else "Play"

        return builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(subtitle)
            .setSubText("Novel Reader")
            .setContentIntent(activityIntent())
            .setOngoing(isPlaying)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setCategory(Notification.CATEGORY_TRANSPORT)
            .addAction(
                android.R.drawable.ic_media_previous,
                "Previous",
                serviceIntent(ACTION_PREVIOUS, 1)
            )
            .addAction(playPauseIcon, playPauseTitle, serviceIntent(ACTION_TOGGLE, 2))
            .addAction(android.R.drawable.ic_media_next, "Next", serviceIntent(ACTION_NEXT, 3))
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Stop",
                serviceIntent(ACTION_STOP, 4)
            )
            .setStyle(
                Notification.MediaStyle()
                    .setMediaSession(mediaSession.sessionToken)
                    .setShowActionsInCompactView(0, 1, 2)
            )
            .build()
    }

    private fun activityIntent(): PendingIntent {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        return PendingIntent.getActivity(this, 0, intent, pendingIntentFlags())
    }

    private fun serviceIntent(action: String, requestCode: Int): PendingIntent {
        val intent = Intent(this, NovelReaderForegroundService::class.java).apply {
            this.action = action
        }
        return PendingIntent.getService(this, requestCode, intent, pendingIntentFlags())
    }

    private fun pendingIntentFlags(): Int {
        val immutable = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE
        } else {
            0
        }
        return PendingIntent.FLAG_UPDATE_CURRENT or immutable
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "Novel Reader playback",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Background playback for Novel Reader"
                setShowBadge(false)
            }
        )
    }

    private fun startForegroundCompat(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    @Suppress("DEPRECATION")
    private fun hideForeground() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            stopForeground(true)
        }
    }

    companion object {
        const val ACTION_UPDATE = "com.neiroha.neiroha.novel.UPDATE"
        const val ACTION_TOGGLE = "com.neiroha.neiroha.novel.TOGGLE"
        const val ACTION_PREVIOUS = "com.neiroha.neiroha.novel.PREVIOUS"
        const val ACTION_NEXT = "com.neiroha.neiroha.novel.NEXT"
        const val ACTION_STOP = "com.neiroha.neiroha.novel.STOP"

        const val EXTRA_TITLE = "title"
        const val EXTRA_SUBTITLE = "subtitle"
        const val EXTRA_IS_PLAYING = "isPlaying"

        private const val CHANNEL_ID = "neiroha_novel_reader"
        private const val NOTIFICATION_ID = 2101
    }
}
