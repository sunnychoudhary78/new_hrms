import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Keeps mic/camera/audio alive while the user switches to another app.
class MeetingCallKeepAlive {
  static const _channel = MethodChannel('hrms/meeting_keepalive');
  static bool _running = false;

  static Future<void> start({String? title}) async {
    if (kIsWeb) return;
    _running = true;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await Permission.notification.request();
      }
      await _channel.invokeMethod<void>('start', {
        'title': (title == null || title.trim().isEmpty)
            ? 'Meeting in progress'
            : title.trim(),
      });
    } catch (e) {
      debugPrint('Meeting keep-alive start failed: $e');
    }
  }

  static Future<void> stop() async {
    if (kIsWeb || !_running) return;
    _running = false;
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (e) {
      debugPrint('Meeting keep-alive stop failed: $e');
    }
  }
}
