import 'package:geolocator/geolocator.dart';

class LocationService {
  static const Duration _permissionTimeout = Duration(seconds: 5);
  static const Duration _locationTimeout = Duration(seconds: 10);

  // 🔐 Ensure permission + GPS enabled safely
  Future<bool> ensureServiceAndPermission() async {
    try {
      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        return false;
      }

      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        return false;
      }

      // Check GPS service enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        try {
          // triggers native popup
          await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
          );
        } catch (_) {
          return false;
        }
      }

      // Try quick location fetch to trigger system resolution if needed
      try {
        await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
        ).timeout(_permissionTimeout);
      } catch (_) {
        // Ignore here, actual fetch will happen later
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  // 📍 Get current location safely with timeout
  Future<Position?> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        return null;
      }

      final permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(_locationTimeout);
    } catch (_) {
      return null;
    }
  }

  // 📏 Distance in meters
  double distanceBetween(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }
}
