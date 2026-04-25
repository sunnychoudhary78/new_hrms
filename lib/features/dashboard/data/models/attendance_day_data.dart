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

      if (value is String) {
        final v = value.trim();
        if (v.isEmpty) return 0;

        final asInt = int.tryParse(v);
        if (asInt != null) return asInt;

        final asDouble = double.tryParse(v);
        if (asDouble != null) return asDouble.round();

        // Supports "HH:mm" style work credit, converts to minutes.
        final hhmm = RegExp(r'^(\d{1,2}):(\d{1,2})$').firstMatch(v);
        if (hhmm != null) {
          final hours = int.tryParse(hhmm.group(1)!) ?? 0;
          final mins = int.tryParse(hhmm.group(2)!) ?? 0;
          return (hours * 60) + mins;
        }

        return 0;
      }

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
  /// Backend may mark [status] as absent until checkout; if we already have a
  /// check-in session, treat the day as present for UI and summaries.
  ////////////////////////////////////////////////////////////

  static String resolveStatusWithSessions(
    String aggregateStatus,
    List<AttendanceSessionData> sessions,
  ) {
    final normalized = aggregateStatus.trim().toLowerCase();
    final hasCheckIn = sessions.any((s) => s.checkIn != null);
    if (!hasCheckIn) return aggregateStatus;

    final isLeave =
        normalized.contains('leave') || normalized.contains('on-leave');
    final isWeekOff =
        normalized.contains('week') ||
        normalized.contains('holiday') ||
        normalized.contains('weekoff');

    if (isLeave || isWeekOff) return aggregateStatus;

    if (normalized.contains('absent')) return 'present';

    return aggregateStatus;
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

      final rawStatus = aggregate['status']?.toString() ?? 'Unknown';

      final safeMinutes = _asInt(
        aggregate['fullWorked'] ??
            aggregate['totalMinutes'] ??
            aggregate['workCredit'] ??
            0,
      );

      final List<AttendanceSessionData> safeSessions = [];

      for (final session in sessionsJson) {
        try {
          safeSessions.add(AttendanceSessionData.fromJson(session));
        } catch (_) {
          // skip broken session
        }
      }

      final safeStatus = resolveStatusWithSessions(rawStatus, safeSessions);

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

  double get totalHours {
    if (totalMinutes > 0) return totalMinutes / 60;

    final sessionsTotal = sessions.fold<int>(
      0,
      (sum, s) => sum + s.resolvedDurationMinutes,
    );

    return sessionsTotal / 60;
  }
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

      if (value is String) {
        final v = value.trim();
        if (v.isEmpty) return 0;

        final asInt = int.tryParse(v);
        if (asInt != null) return asInt;

        final asDouble = double.tryParse(v);
        if (asDouble != null) return asDouble.round();

        // Supports "HH:mm" strings when backend returns formatted duration.
        final hhmm = RegExp(r'^(\d{1,2}):(\d{1,2})$').firstMatch(v);
        if (hhmm != null) {
          final hours = int.tryParse(hhmm.group(1)!) ?? 0;
          final mins = int.tryParse(hhmm.group(2)!) ?? 0;
          return (hours * 60) + mins;
        }

        return 0;
      }

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
      final checkIn = _asDate(json['checkInTime']);
      final checkOut = _asDate(json['checkOutTime']);

      int duration = _asInt(
        json['durationMinutes'] ?? json['duration'] ?? json['workCredit'],
      );

      if (duration <= 0 && checkIn != null && checkOut != null) {
        duration = checkOut.difference(checkIn).inMinutes;
      }

      return AttendanceSessionData(
        checkIn: checkIn,
        checkOut: checkOut,
        durationMinutes: duration > 0 ? duration : 0,
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

  int get resolvedDurationMinutes {
    if (durationMinutes > 0) return durationMinutes;
    if (checkIn == null || checkOut == null) return 0;

    return checkOut!.difference(checkIn!).inMinutes;
  }
}
