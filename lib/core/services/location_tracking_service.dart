import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lms/core/services/gps_local_db.dart';
import 'package:permission_handler/permission_handler.dart';

/// ===========================================
/// MODEL SENT TO UI
/// ===========================================

class TrackingData {
  final LatLng current;
  final List<LatLng> path;
  final double totalDistance;

  TrackingData(this.current, this.path, this.totalDistance);
}

/// ===========================================
/// MAIN TRACKING SERVICE (UI SIDE)
/// ===========================================

class LocationTrackingService {
  static final LocationTrackingService _instance =
      LocationTrackingService._internal();

  factory LocationTrackingService() => _instance;

  LocationTrackingService._internal();

  final _controller = StreamController<TrackingData>.broadcast();

  Stream<TrackingData> get locationStream => _controller.stream;

  final List<LatLng> _path = [];

  LatLng? _last;

  double _distance = 0;

  /// ===========================================
  /// INITIALIZE BACKGROUND SERVICE
  /// ===========================================

  Future<void> initialize() async {
    final service = FlutterBackgroundService();

    /// Listen from background isolate
    service.on("locationUpdate").listen((event) {
      if (event == null) return;

      updateFromIsolate(Map<String, dynamic>.from(event));
    });

    /// Notification channel
    const channel = AndroidNotificationChannel(
      'tracking_channel',
      'Location Tracking',
      description: 'Tracks employee location',
      importance: Importance.low,
    );

    final notifications = FlutterLocalNotificationsPlugin();

    await notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onBackgroundStart,
        autoStart: false,
        autoStartOnBoot: false,
        isForegroundMode: true,
        notificationChannelId: 'tracking_channel',
        initialNotificationTitle: 'HRMS Tracking',
        initialNotificationContent: 'Initializing...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(onForeground: onBackgroundStart),
    );
  }

  /// ===========================================
  /// START TRACKING
  /// ===========================================

  Future<void> startTracking() async {
    await _disableBatteryOptimization();

    final ok = await _checkPermissionAndGPS();

    if (!ok) return;

    _path.clear();
    _last = null;
    _distance = 0;

    final service = FlutterBackgroundService();

    if (!(await service.isRunning())) {
      await service.startService();
    }
  }

  /// ===========================================
  /// STOP TRACKING
  /// ===========================================

  Future<void> stopTracking() async {
    FlutterBackgroundService().invoke("stopService");
  }

  /// ===========================================
  /// RECEIVE UPDATES FROM BACKGROUND
  /// ===========================================

  void updateFromIsolate(Map<String, dynamic> data) {
    final lat = data["lat"];
    final lng = data["lng"];

    final pos = LatLng(lat, lng);

    _path.add(pos);

    if (_last != null) {
      final d = Geolocator.distanceBetween(
        _last!.latitude,
        _last!.longitude,
        pos.latitude,
        pos.longitude,
      );

      if (d > 5 && d < 200) {
        _distance += d / 1000;
      }
    }

    _last = pos;

    _controller.add(TrackingData(pos, List.from(_path), _distance));
  }

  /// ===========================================
  /// PERMISSION + GPS CHECK
  /// ===========================================

  Future<bool> _checkPermissionAndGPS() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return false;
    }

    bool enabled = await Geolocator.isLocationServiceEnabled();

    if (!enabled) {
      try {
        /// triggers native popup
        await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
        );
      } catch (_) {
        return false;
      }
    }

    return true;
  }

  /// ===========================================
  /// BATTERY OPTIMIZATION DISABLE
  /// ===========================================

  Future<void> _disableBatteryOptimization() async {
    if (await Permission.ignoreBatteryOptimizations.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }
}

/// ===========================================
/// BACKGROUND ENTRY POINT
/// ===========================================

@pragma('vm:entry-point')
void onBackgroundStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();

  DartPluginRegistrant.ensureInitialized();

  /// CRITICAL: immediately set foreground notification
  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: "HRMS Tracking",
      content: "Tracking started...",
    );
  }

  List<Map<String, dynamic>> batch = [];

  Timer.periodic(const Duration(seconds: 5), (timer) async {
    final enabled = await Geolocator.isLocationServiceEnabled();

    /// GPS OFF
    if (!enabled) {
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "GPS Disabled",
          content: "Waiting for GPS to be enabled",
        );
      }

      return;
    }

    /// GET LOCATION
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.bestForNavigation,
    );

    /// SAVE LOCAL
    await GPSLocalDB.instance.insertPoint(
      latitude: pos.latitude,
      longitude: pos.longitude,
      accuracy: pos.accuracy,
      speed: pos.speed,
      heading: pos.heading,
    );

    /// SEND TO UI
    service.invoke("locationUpdate", {
      "lat": pos.latitude,
      "lng": pos.longitude,
    });

    /// BATCH SYNC
    batch.add({"lat": pos.latitude, "lng": pos.longitude});

    if (batch.length >= 10) {
      await syncToBackend();

      batch.clear();
    }

    /// UPDATE FOREGROUND NOTIFICATION
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "HRMS Tracking Active",
        content:
            "${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}",
      );
    }
  });

  service.on("stopService").listen((event) {
    service.stopSelf();
  });
}

/// ===========================================
/// BACKEND SYNC
/// ===========================================

Future<void> syncToBackend() async {
  final points = await GPSLocalDB.instance.getUnsyncedPoints();

  if (points.isEmpty) return;

  try {
    /// CALL YOUR API HERE

    await GPSLocalDB.instance.markSynced(
      points.map((e) => e["id"] as int).toList(),
    );
  } catch (_) {}
}
