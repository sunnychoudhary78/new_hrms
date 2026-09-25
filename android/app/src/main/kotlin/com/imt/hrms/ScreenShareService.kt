package com.imt.hrms

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.Image
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Looper
import android.util.Base64
import androidx.core.app.NotificationCompat
import java.io.ByteArrayOutputStream

object ScreenShareHub {
    var resultCode: Int = Activity.RESULT_CANCELED
    var resultData: Intent? = null
    var onFrame: ((String) -> Unit)? = null
    var onStopped: (() -> Unit)? = null

    fun emitFrame(base64: String) {
        onFrame?.invoke(base64)
    }

    fun emitStopped() {
        onStopped?.invoke()
    }
}

class ScreenShareService : Service() {
    private var projection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null
    private var handlerThread: HandlerThread? = null
    private var lastFrameAt = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val code = ScreenShareHub.resultCode
        val data = ScreenShareHub.resultData
        if (code != Activity.RESULT_OK || data == null) {
            ScreenShareHub.emitStopped()
            stopSelf()
            return START_NOT_STICKY
        }
        startInForeground()
        startCapture(code, data)
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        stopCapture()
        super.onDestroy()
    }

    private fun startInForeground() {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && manager != null) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Screen sharing",
                    NotificationManager.IMPORTANCE_LOW,
                ).apply {
                    description = "Shown while you share your screen in a meeting"
                    setShowBadge(false)
                },
            )
        }
        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Sharing your screen")
            .setContentText("Screen sharing is on for this meeting")
            .setSmallIcon(android.R.drawable.ic_menu_share)
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION,
            )
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun startCapture(code: Int, data: Intent) {
        stopCapture()
        val thread = HandlerThread("hrms-screen-share")
        thread.start()
        handlerThread = thread
        val threadLooper = thread.looper
        val mainLooper = Looper.getMainLooper()
        val looper = threadLooper ?: mainLooper
        if (looper == null) {
            ScreenShareHub.emitStopped()
            stopSelf()
            return
        }
        @Suppress("DEPRECATION")
        val handler = Handler(looper)

        val metrics = resources.displayMetrics
        val width = metrics.widthPixels.coerceAtLeast(2)
        val height = metrics.heightPixels.coerceAtLeast(2)
        val density = metrics.densityDpi

        val reader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2)
        imageReader = reader
        reader.setOnImageAvailableListener({ source ->
            val image = source.acquireLatestImage() ?: return@setOnImageAvailableListener
            try {
                val now = System.currentTimeMillis()
                if (now - lastFrameAt < 90) {
                    return@setOnImageAvailableListener
                }
                lastFrameAt = now
                val jpeg = imageToJpeg(image) ?: return@setOnImageAvailableListener
                val encoded = Base64.encodeToString(jpeg, Base64.NO_WRAP)
                val mainLooper = Looper.getMainLooper()
                if (mainLooper != null) {
                    Handler(mainLooper).post { ScreenShareHub.emitFrame(encoded) }
                }
            } catch (_: Exception) {
            } finally {
                image.close()
            }
        }, handler)

        val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        val mediaProjection = manager.getMediaProjection(code, data) ?: run {
            ScreenShareHub.emitStopped()
            stopSelf()
            return
        }
        projection = mediaProjection
        if (Build.VERSION.SDK_INT >= 34) {
            mediaProjection.registerCallback(object : MediaProjection.Callback() {
                override fun onStop() {
                    stopCapture(stopProjection = false)
                    ScreenShareHub.emitStopped()
                    stopSelf()
                }
            }, handler)
        }

        virtualDisplay = mediaProjection.createVirtualDisplay(
            "hrms-screen-share",
            width,
            height,
            density,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            reader.surface,
            null,
            handler,
        )
    }

    private fun imageToJpeg(image: Image): ByteArray? {
        val plane = image.planes.firstOrNull() ?: return null
        val buffer = plane.buffer
        val pixelStride = plane.pixelStride.coerceAtLeast(1)
        val rowStride = plane.rowStride
        val rowPadding = rowStride - pixelStride * image.width
        buffer.rewind()
        val bitmap = Bitmap.createBitmap(
            image.width + rowPadding / pixelStride,
            image.height,
            Bitmap.Config.ARGB_8888,
        )
        bitmap.copyPixelsFromBuffer(buffer)
        val cropped = Bitmap.createBitmap(bitmap, 0, 0, image.width, image.height)
        val targetW = 960
        val targetH = (targetW.toFloat() / image.width * image.height).toInt().coerceAtLeast(1)
        val scaled = if (cropped.width == targetW) {
            cropped
        } else {
            Bitmap.createScaledBitmap(cropped, targetW, targetH, true)
        }
        val out = ByteArrayOutputStream()
        scaled.compress(Bitmap.CompressFormat.JPEG, 52, out)
        if (scaled !== cropped) scaled.recycle()
        if (cropped !== bitmap) cropped.recycle()
        bitmap.recycle()
        return out.toByteArray()
    }

    private fun stopCapture(stopProjection: Boolean = true) {
        virtualDisplay?.release()
        virtualDisplay = null
        imageReader?.close()
        imageReader = null
        val current = projection
        projection = null
        if (stopProjection) {
            current?.stop()
        }
        handlerThread?.quitSafely()
        handlerThread = null
        ScreenShareHub.resultCode = Activity.RESULT_CANCELED
        ScreenShareHub.resultData = null
    }

    companion object {
        private const val CHANNEL_ID = "meeting_screen_share"
        private const val NOTIFICATION_ID = 890

        fun start(context: Context, code: Int, data: Intent) {
            ScreenShareHub.resultCode = code
            ScreenShareHub.resultData = data
            val intent = Intent(context, ScreenShareService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, ScreenShareService::class.java))
        }
    }
}
