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
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.ByteArrayOutputStream
import java.util.concurrent.atomic.AtomicBoolean

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
    private val stopping = AtomicBoolean(false)
    private val frameBusy = AtomicBoolean(false)

    // Reused across frames to avoid GC / OOM pressure on mid-range devices.
    private var argbBitmap: Bitmap? = null
    private val jpegOut = ByteArrayOutputStream(64 * 1024)

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val code = ScreenShareHub.resultCode
        val data = ScreenShareHub.resultData
        if (code != Activity.RESULT_OK || data == null) {
            ScreenShareHub.emitStopped()
            stopSelf()
            return START_NOT_STICKY
        }
        try {
            startInForeground()
            startCapture(code, data)
        } catch (t: Throwable) {
            Log.e(TAG, "Failed to start screen share", t)
            stopCapture()
            ScreenShareHub.emitStopped()
            stopSelf()
        }
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
        stopping.set(false)

        val thread = HandlerThread("hrms-screen-share")
        thread.start()
        handlerThread = thread
        val looper = thread.looper ?: Looper.getMainLooper()
        if (looper == null) {
            ScreenShareHub.emitStopped()
            stopSelf()
            return
        }
        @Suppress("DEPRECATION")
        val handler = Handler(looper)

        // Capture already scaled — full-res bitmaps OOMed Xiaomi/mid-range devices
        // after a few seconds ("IMT-HRMS keeps stopping").
        val metrics = resources.displayMetrics
        val srcW = metrics.widthPixels.coerceAtLeast(2)
        val srcH = metrics.heightPixels.coerceAtLeast(2)
        val density = metrics.densityDpi
        val (width, height) = scaledCaptureSize(srcW, srcH)

        // Extra buffers so the producer does not block while we encode JPEG.
        val reader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 3)
        imageReader = reader
        reader.setOnImageAvailableListener({ source ->
            if (stopping.get()) return@setOnImageAvailableListener
            if (!frameBusy.compareAndSet(false, true)) {
                // Drop backlog instead of queuing huge frames on the heap.
                try {
                    source.acquireLatestImage()?.close()
                } catch (_: Throwable) {
                }
                return@setOnImageAvailableListener
            }
            var image: Image? = null
            try {
                image = source.acquireLatestImage()
                if (image == null || stopping.get()) return@setOnImageAvailableListener
                val now = System.currentTimeMillis()
                if (now - lastFrameAt < FRAME_INTERVAL_MS) return@setOnImageAvailableListener
                lastFrameAt = now
                val jpeg = imageToJpeg(image) ?: return@setOnImageAvailableListener
                val encoded = Base64.encodeToString(jpeg, Base64.NO_WRAP)
                val mainLooper = Looper.getMainLooper() ?: return@setOnImageAvailableListener
                Handler(mainLooper).post {
                    if (!stopping.get()) ScreenShareHub.emitFrame(encoded)
                }
            } catch (t: Throwable) {
                Log.w(TAG, "Frame encode failed", t)
            } finally {
                try {
                    image?.close()
                } catch (_: Throwable) {
                }
                frameBusy.set(false)
            }
        }, handler)

        val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        val mediaProjection = try {
            manager.getMediaProjection(code, data)
        } catch (t: Throwable) {
            Log.e(TAG, "getMediaProjection failed", t)
            null
        }
        if (mediaProjection == null) {
            ScreenShareHub.emitStopped()
            stopSelf()
            return
        }
        projection = mediaProjection
        mediaProjection.registerCallback(object : MediaProjection.Callback() {
            override fun onStop() {
                // Callback may run off the main thread; tear down safely.
                Handler(Looper.getMainLooper()).post {
                    stopCapture(stopProjection = false)
                    ScreenShareHub.emitStopped()
                    stopSelf()
                }
            }
        }, handler)

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

    private fun scaledCaptureSize(srcW: Int, srcH: Int): Pair<Int, Int> {
        val maxEdge = MAX_CAPTURE_EDGE
        val longest = maxOf(srcW, srcH).toFloat()
        if (longest <= maxEdge) {
            return srcW.coerceAtLeast(2) to srcH.coerceAtLeast(2)
        }
        val scale = maxEdge / longest
        val w = (srcW * scale).toInt().coerceAtLeast(2) and 1.inv()
        val h = (srcH * scale).toInt().coerceAtLeast(2) and 1.inv()
        return w to h
    }

    private fun imageToJpeg(image: Image): ByteArray? {
        val plane = image.planes.firstOrNull() ?: return null
        val buffer = plane.buffer
        val pixelStride = plane.pixelStride.coerceAtLeast(1)
        val rowStride = plane.rowStride
        val width = image.width
        val height = image.height
        if (width <= 0 || height <= 0) return null

        val rowPadding = (rowStride - pixelStride * width).coerceAtLeast(0)
        val bitmapWidth = width + rowPadding / pixelStride

        var bitmap = argbBitmap
        if (bitmap == null ||
            bitmap.width != bitmapWidth ||
            bitmap.height != height ||
            bitmap.isRecycled
        ) {
            bitmap?.recycle()
            bitmap = Bitmap.createBitmap(bitmapWidth, height, Bitmap.Config.ARGB_8888)
            argbBitmap = bitmap
        }
        buffer.rewind()
        bitmap.copyPixelsFromBuffer(buffer)

        val cropped = if (bitmapWidth == width) {
            bitmap
        } else {
            Bitmap.createBitmap(bitmap, 0, 0, width, height)
        }

        val targetW = minOf(width, TARGET_JPEG_WIDTH)
        val targetH = (targetW.toFloat() / width * height).toInt().coerceAtLeast(1)
        val scaled = if (cropped.width == targetW) {
            cropped
        } else {
            Bitmap.createScaledBitmap(cropped, targetW, targetH, true)
        }

        jpegOut.reset()
        val ok = scaled.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, jpegOut)
        if (scaled !== cropped) scaled.recycle()
        if (cropped !== bitmap) cropped.recycle()
        if (!ok) return null
        return jpegOut.toByteArray()
    }

    private fun stopCapture(stopProjection: Boolean = true) {
        stopping.set(true)
        try {
            virtualDisplay?.release()
        } catch (_: Throwable) {
        }
        virtualDisplay = null
        try {
            imageReader?.setOnImageAvailableListener(null, null)
            imageReader?.close()
        } catch (_: Throwable) {
        }
        imageReader = null
        val current = projection
        projection = null
        if (stopProjection) {
            try {
                current?.stop()
            } catch (_: Throwable) {
            }
        }
        try {
            handlerThread?.quitSafely()
        } catch (_: Throwable) {
        }
        handlerThread = null
        try {
            argbBitmap?.recycle()
        } catch (_: Throwable) {
        }
        argbBitmap = null
        ScreenShareHub.resultCode = Activity.RESULT_CANCELED
        ScreenShareHub.resultData = null
    }

    companion object {
        private const val TAG = "ScreenShareService"
        private const val CHANNEL_ID = "meeting_screen_share"
        private const val NOTIFICATION_ID = 890
        // Tuned for low latency over the Flutter↔WebView bridge: slightly
        // smaller JPEGs at a higher frame rate feel snappier than large 10fps tiles.
        private const val MAX_CAPTURE_EDGE = 720
        private const val TARGET_JPEG_WIDTH = 640
        private const val JPEG_QUALITY = 55
        private const val FRAME_INTERVAL_MS = 50L

        fun start(context: Context, code: Int, data: Intent) {
            ScreenShareHub.resultCode = code
            // Copy — some OEMs invalidate the result Intent after onActivityResult returns.
            ScreenShareHub.resultData = Intent(data)
            val intent = Intent(context, ScreenShareService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            // Notify Flutter/JS immediately so remotes drop the desktop track
            // without waiting for Service.onDestroy.
            ScreenShareHub.emitStopped()
            context.stopService(Intent(context, ScreenShareService::class.java))
        }
    }
}
