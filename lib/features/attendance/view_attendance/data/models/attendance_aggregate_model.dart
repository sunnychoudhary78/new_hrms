class AttendanceAggregate {
  final DateTime date;
  final String status;

  AttendanceAggregate({required this.date, required this.status});

  factory AttendanceAggregate.fromJson(Map<String, dynamic> json) {
    final date = DateTime.parse(json['date']);

    final raw = (json['status'] ?? '').toString().toLowerCase();

    /// ✅ normalize backend → app format
    String status;

    if (raw.contains('week')) {
      status = 'weekoff';
    } else if (raw.contains('absent')) {
      status = 'absent';
    } else if (raw.contains('leave')) {
      status = 'leave';
    } else {
      status = 'present'; // fallback
    }

    return AttendanceAggregate(date: date, status: status);
  }
}
