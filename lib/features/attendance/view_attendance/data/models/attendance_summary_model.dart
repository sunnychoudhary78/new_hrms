class AttendanceSummary {
  final int workingDays;
  final int lateDays;
  final int totalLeaves;
  final int absentDays;
  final int payableDays;
  final int totalMinutes;
  final int expectedWorkingHours;

  AttendanceSummary({
    required this.workingDays,
    required this.lateDays,
    required this.totalLeaves,
    required this.absentDays,
    required this.payableDays,
    required this.totalMinutes,
    required this.expectedWorkingHours,
  });

  static int _asInt(dynamic v) {
    if (v == null) return 0;

    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v) ?? 0;

    return 0;
  }

  factory AttendanceSummary.fromJson(Map<String, dynamic> json) {
    final data = json['summary'];

    if (data == null) {
      throw Exception("Summary missing in response");
    }

    return AttendanceSummary(
      workingDays: _asInt(data['workingDays']),
      lateDays: _asInt(data['lateDays']),
      totalLeaves: _asInt(data['totalLeaves']),
      absentDays: _asInt(data['absentDays']),
      payableDays: _asInt(data['payableDays']),
      totalMinutes: _asInt(data['totalMinutes']),
      expectedWorkingHours: _asInt(data['expectedWorkingHours']),
    );
  }

  String get totalWorkingHoursFormatted {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    return "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}";
  }
}
