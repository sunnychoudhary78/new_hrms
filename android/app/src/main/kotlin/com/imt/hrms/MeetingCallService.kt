package com.imt.hrms

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Foreground service that keeps mic/camera/WebRTC eligible while HRMS is
 * minimized during an internal meeting. Without this, OEMs (esp. Xiaomi)
 * suspend the WebView and the leave hook disconnects the participant.
 */
class MeetingCallService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val title = intent?.getStringExtra(EXTRA_TITLE)?.ifBlank { null } ?: "Meeting in progress"
        try {
            startInForeground(title)
            acquireWakeLock()
        } catch (t: Throwable) {
            Log.e(TAG, "Failed to promote meeting keep-alive", t)
            try {
                startForeground(NOTIFICATION_ID, buildNotification(title))
                acquireWakeLock()
            } catch (t2: Throwable) {
                Log.e(TAG, "Fallback startForeground failed", t2)
                stopSelf()
                return START_NOT_STICKY
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        releaseWakeLock()
        super.onDestroy()
    }

    private fun startInForeground(title: String) {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && manager != null) {
            // DEFAULT (not LOW) so aggressive OEMs keep the FGS privileged.
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Active meeting",
                    NotificationManager.IMPORTANCE_DEFAULT,
                ).apply {
                    description = "Keeps an internal meeting connected in the background"
                    setShowBadge(false)
                    setSound(null, null)
                },
            )
        }

        val notification = buildNotification(title)
        val types = foregroundTypes()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && types != 0) {
            startForeground(NOTIFICATION_ID, notification, types)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun buildNotification(title: String): Notification {
        val launch = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        launch.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        val pending = PendingIntent.getActivity(
            this,
            0,
            launch,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText("Meeting in progress — tap to return")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(pending)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    private fun foregroundTypes(): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return 0
        var types = ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            types = types or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
        }
        if (Build.VERSION.SDK_INT >= 34) {
            types = types or ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
        }
        return types
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "hrms:meeting").apply {
            setReferenceCounted(false)
            acquire(4 * 60 * 60 * 1000L)
        }
    }

    private fun releaseWakeLock() {
        if (wakeLock?.isHeld == true) {
            wakeLock?.release()
        }
        wakeLock = null
    }

    companion object {
        private const val TAG = "MeetingCallService"
        // New id so devices that already created the old LOW channel pick up DEFAULT.
        const val CHANNEL_ID = "meeting_call_channel_v2"
        const val NOTIFICATION_ID = 889
        const val EXTRA_TITLE = "title"

        fun start(context: Context, title: String?) {
            val intent = Intent(context, MeetingCallService::class.java)
            intent.putExtra(EXTRA_TITLE, title)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, MeetingCallService::class.java))
        }
    }
}
