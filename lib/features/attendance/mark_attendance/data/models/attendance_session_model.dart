class AttendanceSession {
  final String id;
  final DateTime checkInTime;
  final DateTime? checkOutTime;

  final String date;
  final int durationMinutes;

  final String source;
  final bool remoteRequested;
  final String? remoteReason;
  final String? checkInSelfie;
  final String? checkOutSelfie;

  final double? lat;
  final double? lng;

  AttendanceSession({
    required this.id,
    required this.checkInTime,
    this.checkOutTime,
    required this.date,
    required this.durationMinutes,
    required this.source,
    required this.remoteRequested,
    this.remoteReason,
    this.checkInSelfie,
    this.checkOutSelfie,
    this.lat,
    this.lng,
  });

  static int _asInt(dynamic v) {
    if (v == null) return 0;

    if (v is int) return v;

    if (v is double) return v.toInt();

    if (v is String) return int.tryParse(v) ?? 0;

    if (v is Map<String, dynamic>) {
      if (v.containsKey('minutes')) return _asInt(v['minutes']);
      if (v.containsKey('value')) return _asInt(v['value']);
      if (v.containsKey('total')) return _asInt(v['total']);
    }

    return 0;
  }

  static String _asString(dynamic v) {
    if (v == null) return '';

    if (v is String) return v;

    if (v is Map<String, dynamic>) {
      if (v.containsKey('date')) return v['date'].toString();
      if (v.containsKey('value')) return v['value'].toString();
    }

    return v.toString();
  }

  factory AttendanceSession.fromJson(Map<String, dynamic> json) {
    print("📦 RAW ATTENDANCE SESSION:");
    print(json);

    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();

      if (value is String) {
        return DateTime.parse(value).toLocal();
      }

      if (value is Map<String, dynamic>) {
        if (value.containsKey('value')) {
          return DateTime.parse(value['value'].toString()).toLocal();
        }
      }

      return DateTime.parse(value.toString()).toLocal();
    }

    DateTime? parseNullableDate(dynamic value) {
      if (value == null) return null;

      if (value is String) {
        return DateTime.parse(value).toLocal();
      }

      if (value is Map<String, dynamic>) {
        if (value.containsKey('value')) {
          return DateTime.parse(value['value'].toString()).toLocal();
        }
      }

      return DateTime.parse(value.toString()).toLocal();
    }

    return AttendanceSession(
      id: json['id']?.toString() ?? '',
      checkInTime: parseDate(json['checkInTime']),
      checkOutTime: parseNullableDate(json['checkOutTime']),
      date: _asString(json['date']),
      durationMinutes: _asInt(json['durationMinutes']),
      source: json['source']?.toString() ?? '',
      remoteRequested: json['remoteRequested'] == true,
      remoteReason: json['remoteReason']?.toString(),
      checkInSelfie: json['checkInSelfie']?.toString(),
      checkOutSelfie: json['checkOutSelfie']?.toString(),
      lat: json['location']?['lat']?.toDouble(),
      lng: json['location']?['lng']?.toDouble(),
    );
  }
}
