package com.imt.hrms

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
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
    }

    companion object {
        private const val CHANNEL = "hrms/meeting_keepalive"
    }
}
