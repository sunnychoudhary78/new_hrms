import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Keeps mic/camera alive in the background and drives Android PiP for meetings.
class MeetingCallKeepAlive {
  static const _channel = MethodChannel('hrms/meeting_keepalive');
  static const _pipEvents = EventChannel('hrms/meeting_pip');
  static bool _running = false;
  static StreamSubscription<dynamic>? _pipSub;
  static final _pipController = StreamController<bool>.broadcast();

  /// Whether the activity is currently in Android Picture-in-Picture.
  static Stream<bool> get pipModeChanges => _pipController.stream;

  static Future<void> start({String? title}) async {
    if (kIsWeb) return;
    _running = true;
    _ensurePipListener();
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
    if (kIsWeb) return;
    _running = false;
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (e) {
      debugPrint('Meeting keep-alive stop failed: $e');
    }
  }

  /// Ask Android to enter Picture-in-Picture (no-op on iOS / unsupported).
  static Future<bool> enterPip() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final ok = await _channel.invokeMethod<bool>('enterPip');
      return ok == true;
    } catch (e) {
      debugPrint('Meeting PiP enter failed: $e');
      return false;
    }
  }

  /// Temporarily disable auto/home PiP (e.g. while the screen-share consent runs).
  static Future<void> setPipEnabled(bool enabled) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('setPipEnabled', {'enabled': enabled});
    } catch (e) {
      debugPrint('Meeting PiP enable failed: $e');
    }
  }

  static void _ensurePipListener() {
    if (_pipSub != null || kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android) return;
    _pipSub = _pipEvents.receiveBroadcastStream().listen(
      (event) {
        final inPip = event == true || event?.toString() == 'true';
        if (!_pipController.isClosed) _pipController.add(inPip);
      },
      onError: (_) {},
    );
  }
}
