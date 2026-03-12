import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../storage/token_storage.dart';
import '../../utils/firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class PushNotificationService {
  final TokenStorage _tokenStorage;

  FirebaseMessaging? _messaging;
  FlutterLocalNotificationsPlugin? _localNotifications;

  bool _initialized = false;

  /// 🔔 Optional callback when FCM token becomes available
  void Function(String token)? _onTokenAvailable;

  PushNotificationService(this._tokenStorage);

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'Channel for high priority LMS alerts',
        importance: Importance.max,
      );

  Future<void> init({
    required void Function(Map<String, dynamic> data) onNotificationTap,
    required VoidCallback onForegroundNotification,
    void Function(String token)? onTokenAvailable,
  }) async {
    if (_initialized) return;

    _onTokenAvailable = onTokenAvailable;

    if (kIsWeb) {
      _initialized = true;
      return;
    }

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    _messaging = FirebaseMessaging.instance;
    _localNotifications = FlutterLocalNotificationsPlugin();

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _requestPermissions();
    await _initLocalNotifications(onNotificationTap);
    await _createAndroidChannel();

    // 🔔 FOREGROUND
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      final android = notification?.android;

      if (notification != null && android != null) {
        _localNotifications!.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'High Importance Notifications',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
          payload: jsonEncode(message.data),
        );
      }
      // 🔥 IMPORTANT: Trigger refresh
      onForegroundNotification();
    });

    // 🔔 BACKGROUND → TAP
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      onNotificationTap(message.data);
    });

    // 🔔 KILLED → TAP
    final initialMessage = await _messaging!.getInitialMessage();
    if (initialMessage != null) {
      onNotificationTap(initialMessage.data);
    }

    // 🔑 TOKEN (initial)
    await _storeAndEmitToken();

    // 🔁 TOKEN REFRESH
    _messaging!.onTokenRefresh.listen((token) async {
      if (token.isNotEmpty) {
        await _tokenStorage.saveFcm(token);
        _onTokenAvailable?.call(token);
      }
    });

    _initialized = true;
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────

  Future<void> _storeAndEmitToken() async {
    final token = await _messaging!.getToken();

    if (token != null && token.isNotEmpty) {
      await _tokenStorage.saveFcm(token);
      _onTokenAvailable?.call(token);
    }
  }

  Future<void> _initLocalNotifications(
    void Function(Map<String, dynamic>) onNotificationTap,
  ) async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications!.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          onNotificationTap(
            jsonDecode(response.payload!) as Map<String, dynamic>,
          );
        }
      },
    );
  }

  Future<void> _createAndroidChannel() async {
    final androidPlugin = _localNotifications!
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(_androidChannel);
  }

  Future<void> _requestPermissions() async {
    if (Platform.isIOS || Platform.isMacOS) {
      await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } else if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
    }
  }
}
