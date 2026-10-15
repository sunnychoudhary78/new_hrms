package com.imt.hrms

import android.app.PictureInPictureParams
import android.content.Intent
import android.content.res.Configuration
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var screenShareSink: EventChannel.EventSink? = null
    private var pipSink: EventChannel.EventSink? = null
    private var pendingScreenResult: MethodChannel.Result? = null
    private var meetingActive = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val title = call.argument<String>("title")
                    meetingActive = true
                    updatePipParams()
                    MeetingCallService.start(this, title)
                    result.success(true)
                }
                "stop" -> {
                    meetingActive = false
                    updatePipParams()
                    MeetingCallService.stop(this)
                    result.success(true)
                }
                "enterPip" -> {
                    result.success(enterMeetingPip())
                }
                "setPipEnabled" -> {
                    meetingActive = call.argument<Boolean>("enabled") == true
                    updatePipParams()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SCREEN_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    if (pendingScreenResult != null) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    pendingScreenResult = result
                    val manager = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                    @Suppress("DEPRECATION")
                    startActivityForResult(manager.createScreenCaptureIntent(), SCREEN_REQUEST)
                }
                "stop" -> {
                    ScreenShareService.stop(this)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SCREEN_EVENTS,
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                screenShareSink = events
                ScreenShareHub.onFrame = { frame ->
                    runOnUiThread {
                        try {
                            screenShareSink?.success(frame)
                        } catch (_: Throwable) {
                        }
                    }
                }
                ScreenShareHub.onStopped = {
                    runOnUiThread {
                        try {
                            screenShareSink?.success("__stopped__")
                        } catch (_: Throwable) {
                        }
                    }
                }
            }

            override fun onCancel(arguments: Any?) {
                screenShareSink = null
                ScreenShareHub.onFrame = null
                ScreenShareHub.onStopped = null
            }
        })

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PIP_EVENTS,
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                pipSink = events
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    events?.success(isInPictureInPictureMode)
                } else {
                    events?.success(false)
                }
            }

            override fun onCancel(arguments: Any?) {
                pipSink = null
            }
        })
    }

    /** Home / Recents — show a floating meeting window while the call stays live. */
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (meetingActive) {
            enterMeetingPip()
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        }
        pipSink?.success(isInPictureInPictureMode)
    }

    @Deprecated("Deprecated in Java")
    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean) {
        @Suppress("DEPRECATION")
        super.onPictureInPictureModeChanged(isInPictureInPictureMode)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        pipSink?.success(isInPictureInPictureMode)
    }

    private fun enterMeetingPip(): Boolean {
        if (!meetingActive) return false
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        if (isInPictureInPictureMode) return true
        return try {
            enterPictureInPictureMode(buildPipParams())
            true
        } catch (t: Throwable) {
            false
        }
    }

    private fun updatePipParams() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        try {
            setPictureInPictureParams(buildPipParams())
        } catch (_: Throwable) {
        }
    }

    private fun buildPipParams(): PictureInPictureParams {
        val builder = PictureInPictureParams.Builder()
            .setAspectRatio(Rational(9, 16))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Auto-enter on gesture Home so the floating window appears reliably.
            builder.setAutoEnterEnabled(meetingActive)
            builder.setSeamlessResizeEnabled(true)
        }
        return builder.build()
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != SCREEN_REQUEST) return
        val callback = pendingScreenResult
        pendingScreenResult = null
        if (resultCode == RESULT_OK && data != null) {
            try {
                ScreenShareService.start(this, resultCode, data)
                callback?.success(true)
            } catch (_: Throwable) {
                ScreenShareHub.emitStopped()
                callback?.success(false)
            }
        } else {
            callback?.success(false)
            ScreenShareHub.emitStopped()
        }
    }

    companion object {
        private const val CHANNEL = "hrms/meeting_keepalive"
        private const val SCREEN_CHANNEL = "hrms/screen_share"
        private const val SCREEN_EVENTS = "hrms/screen_share_frames"
        private const val PIP_EVENTS = "hrms/meeting_pip"
        private const val SCREEN_REQUEST = 4101
    }
}
