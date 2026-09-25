package com.imt.hrms

import android.content.Intent
import android.media.projection.MediaProjectionManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var screenShareSink: EventChannel.EventSink? = null
    private var pendingScreenResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val title = call.argument<String>("title")
                    MeetingCallService.start(this, title)
                    result.success(true)
                }
                "stop" -> {
                    MeetingCallService.stop(this)
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
                    runOnUiThread { screenShareSink?.success(frame) }
                }
                ScreenShareHub.onStopped = {
                    runOnUiThread { screenShareSink?.success("__stopped__") }
                }
            }

            override fun onCancel(arguments: Any?) {
                screenShareSink = null
                ScreenShareHub.onFrame = null
                ScreenShareHub.onStopped = null
            }
        })
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != SCREEN_REQUEST) return
        val callback = pendingScreenResult
        pendingScreenResult = null
        if (resultCode == RESULT_OK && data != null) {
            ScreenShareService.start(this, resultCode, data)
            callback?.success(true)
        } else {
            callback?.success(false)
            ScreenShareHub.emitStopped()
        }
    }

    companion object {
        private const val CHANNEL = "hrms/meeting_keepalive"
        private const val SCREEN_CHANNEL = "hrms/screen_share"
        private const val SCREEN_EVENTS = "hrms/screen_share_frames"
        private const val SCREEN_REQUEST = 4101
    }
}
