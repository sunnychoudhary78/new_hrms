class AttendanceDayData {
  final String date;
  final String status;
  final int totalMinutes;
  final List<AttendanceSessionData> sessions;

  AttendanceDayData({
    required this.date,
    required this.status,
    required this.totalMinutes,
    required this.sessions,
  });

  ////////////////////////////////////////////////////////////
  // SAFE HELPERS
  ////////////////////////////////////////////////////////////

  static String _asString(dynamic value) {
    try {
      if (value == null) return '';

      if (value is String) return value;

      if (value is Map<String, dynamic>) {
        if (value.containsKey('date')) {
          return value['date']?.toString() ?? '';
        }

        if (value.containsKey('value')) {
          return value['value']?.toString() ?? '';
        }
      }

      return value.toString();
    } catch (_) {
      return '';
    }
  }

  static int _asInt(dynamic value) {
    try {
      if (value == null) return 0;

      if (value is int) return value;

      if (value is double) return value.toInt();

      if (value is String) return int.tryParse(value) ?? 0;

      if (value is Map<String, dynamic>) {
        if (value.containsKey('minutes')) {
          return _asInt(value['minutes']);
        }

        if (value.containsKey('value')) {
          return _asInt(value['value']);
        }

        if (value.containsKey('total')) {
          return _asInt(value['total']);
        }
      }

      return 0;
    } catch (_) {
      return 0;
    }
  }

  ////////////////////////////////////////////////////////////
  // SAFE FACTORY
  ////////////////////////////////////////////////////////////

  factory AttendanceDayData.fromJson({
    required Map<String, dynamic> aggregate,
    required List sessionsJson,
  }) {
    try {
      final safeDate = _asString(aggregate['date']);

      final safeStatus = aggregate['status']?.toString() ?? 'Unknown';

      final safeMinutes = _asInt(aggregate['totalMinutes']);

      final List<AttendanceSessionData> safeSessions = [];

      for (final session in sessionsJson) {
        try {
          safeSessions.add(AttendanceSessionData.fromJson(session));
        } catch (_) {
          // skip broken session
        }
      }

      return AttendanceDayData(
        date: safeDate,
        status: safeStatus,
        totalMinutes: safeMinutes,
        sessions: safeSessions,
      );
    } catch (_) {
      return AttendanceDayData(
        date: '',
        status: 'Unknown',
        totalMinutes: 0,
        sessions: [],
      );
    }
  }

  double get totalHours => totalMinutes / 60;
}

//////////////////////////////////////////////////////////////

class AttendanceSessionData {
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int durationMinutes;
  final String source;
  final String? checkInSelfie;
  final String? checkOutSelfie;
  final double? lat;
  final double? lng;

  AttendanceSessionData({
    required this.checkIn,
    required this.checkOut,
    required this.durationMinutes,
    required this.source,
    this.checkInSelfie,
    this.checkOutSelfie,
    this.lat,
    this.lng,
  });

  ////////////////////////////////////////////////////////////
  // SAFE HELPERS
  ////////////////////////////////////////////////////////////

  static DateTime? _asDate(dynamic value) {
    try {
      if (value == null) return null;

      if (value is String && value.isNotEmpty) {
        return DateTime.parse(value).toLocal();
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  static int _asInt(dynamic value) {
    try {
      if (value == null) return 0;

      if (value is int) return value;

      if (value is double) return value.toInt();

      if (value is String) return int.tryParse(value) ?? 0;

      return 0;
    } catch (_) {
      return 0;
    }
  }

  ////////////////////////////////////////////////////////////
  // SAFE FACTORY
  ////////////////////////////////////////////////////////////

  factory AttendanceSessionData.fromJson(Map<String, dynamic> json) {
    try {
      final location = json['location'] as Map<String, dynamic>?;

      return AttendanceSessionData(
        checkIn: _asDate(json['checkInTime']),
        checkOut: _asDate(json['checkOutTime']),
        durationMinutes: _asInt(json['durationMinutes']),
        source: json['source']?.toString() ?? '',

        checkInSelfie: json['checkInSelfie']?.toString(),
        checkOutSelfie: json['checkOutSelfie']?.toString(),

        lat: (location?['lat'] as num?)?.toDouble(),
        lng: (location?['lng'] as num?)?.toDouble(),
      );
    } catch (_) {
      return AttendanceSessionData(
        checkIn: null,
        checkOut: null,
        durationMinutes: 0,
        source: '',
        checkInSelfie: null,
        checkOutSelfie: null,
      );
    }
  }

  double get hours => durationMinutes / 60;
}
