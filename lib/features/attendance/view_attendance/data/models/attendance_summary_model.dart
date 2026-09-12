class LeaveBreakdown {
  final String type;
  final num days;

  LeaveBreakdown({required this.type, required this.days});

  factory LeaveBreakdown.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'];
    final days = rawDays is num
        ? rawDays
        : num.tryParse(rawDays?.toString() ?? '') ?? 0;

    return LeaveBreakdown(type: json['type']?.toString() ?? '', days: days);
  }
}

class AttendanceSummary {
  final num workingDays;
  final int lateDays;
  final num totalLeaves;
  final num absentDays;
  final num payableDays;
  final int totalMinutes;
  final int expectedWorkingHours;

  /// Backend-formatted "H:MM" string. Show as-is — do not reformat.
  final String workingHours;
  final int totalWeekoffs;
  final int totalHolidays;
  final List<LeaveBreakdown> leaveBreakdown;

  AttendanceSummary({
    required this.workingDays,
    required this.lateDays,
    required this.totalLeaves,
    required this.absentDays,
    required this.payableDays,
    required this.totalMinutes,
    required this.expectedWorkingHours,
    this.workingHours = '0:00',
    this.totalWeekoffs = 0,
    this.totalHolidays = 0,
    this.leaveBreakdown = const [],
  });

  static int _asInt(dynamic v) {
    if (v == null) return 0;

    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v) ?? 0;

    return 0;
  }

  static num _asNum(dynamic v) {
    if (v == null) return 0;

    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? 0;

    return 0;
  }

  static String _formatMinutesFallback(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return "${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}";
  }

  factory AttendanceSummary.fromJson(Map<String, dynamic> json) {
    final data = json['summary'];

    if (data == null) {
      throw Exception("Summary missing in response");
    }

    final totalMinutes = _asInt(data['totalMinutes']);

    return AttendanceSummary(
      workingDays: _asNum(data['workingDays']),
      lateDays: _asInt(data['lateDays']),
      totalLeaves: _asNum(data['totalLeaves']),
      absentDays: _asNum(data['absentDays']),
      payableDays: _asNum(data['payableDays']),
      totalMinutes: totalMinutes,
      expectedWorkingHours: _asInt(data['expectedWorkingHours']),
      workingHours:
          data['workingHours']?.toString() ??
          _formatMinutesFallback(totalMinutes),
      totalWeekoffs: _asInt(data['totalWeekoffs']),
      totalHolidays: _asInt(data['totalHolidays']),
      leaveBreakdown: (data['leaveBreakdown'] as List? ?? [])
          .map((e) => LeaveBreakdown.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Kept for any existing call sites; prefer [workingHours] going forward
  /// since the backend already applies business rules to it.
  String get totalWorkingHoursFormatted => _formatMinutesFallback(totalMinutes);
}
