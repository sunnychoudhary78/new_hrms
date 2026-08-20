class AttendanceAggregate {
  final DateTime date;
  final String status;
  final int totalMinutes;

  AttendanceAggregate({
    required this.date,
    required this.status,
    this.totalMinutes = 0,
  });

  String get dateKey =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  factory AttendanceAggregate.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date']?.toString() ?? '';
    final parsed = DateTime.tryParse(rawDate) ?? DateTime.now();

    final status = (json['status'] ?? '').toString().trim();

    return AttendanceAggregate(
      date: parsed,
      status: status.isEmpty ? '-' : status,
      totalMinutes: int.tryParse(json['totalMinutes']?.toString() ?? '') ?? 0,
    );
  }
}
