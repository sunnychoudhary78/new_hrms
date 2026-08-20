class MobileConfig {
  final bool allowMobileCheckin;
  final bool requireMobileGps;
  final bool enforceMobileGeofence;
  final bool requireMobileCheckinSelfie;
  final bool requireMobileCheckoutSelfie;

  const MobileConfig({
    required this.allowMobileCheckin,
    required this.requireMobileGps,
    this.enforceMobileGeofence = false,
    required this.requireMobileCheckinSelfie,
    required this.requireMobileCheckoutSelfie,
  });

  bool get requireLocation => requireMobileGps || enforceMobileGeofence;

  factory MobileConfig.fromJson(Map<String, dynamic> json) {
    return MobileConfig(
      allowMobileCheckin: json["allow_mobile_checkin"] ?? true,
      requireMobileGps: json["require_mobile_gps"] ?? false,
      enforceMobileGeofence: json["enforce_mobile_geofence"] ?? false,
      requireMobileCheckinSelfie:
          json["require_mobile_checkin_selfie"] ?? false,
      requireMobileCheckoutSelfie:
          json["require_mobile_checkout_selfie"] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "allow_mobile_checkin": allowMobileCheckin,
      "require_mobile_gps": requireMobileGps,
      "enforce_mobile_geofence": enforceMobileGeofence,
      "require_mobile_checkin_selfie": requireMobileCheckinSelfie,
      "require_mobile_checkout_selfie": requireMobileCheckoutSelfie,
    };
  }
}
