import 'package:lms/features/dashboard/data/models/attendance_day_data.dart';

class AttendanceAggregate {
  final DateTime date;
  final String status;
  final int totalMinutes;
  final String? leaveType;
  final String? holidayName;
  final List<AttendanceLeaveDetail> leaveDetails;

  AttendanceAggregate({
    required this.date,
    required this.status,
    this.totalMinutes = 0,
    this.leaveType,
    this.holidayName,
    this.leaveDetails = const [],
  });

  String get dateKey =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  factory AttendanceAggregate.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date']?.toString() ?? '';
    final parsed = DateTime.tryParse(rawDate) ?? DateTime.now();

    final status = (json['status'] ?? '').toString().trim();
    final leaveType = (json['leaveType'] ?? json['leave_type'])?.toString().trim();
    final holidayName =
        (json['holidayName'] ?? json['holiday_name'])?.toString().trim();

    return AttendanceAggregate(
      date: parsed,
      status: status.isEmpty ? '-' : status,
      totalMinutes: int.tryParse(json['totalMinutes']?.toString() ?? '') ?? 0,
      leaveType: (leaveType == null || leaveType.isEmpty) ? null : leaveType,
      holidayName: (holidayName == null || holidayName.isEmpty)
          ? null
          : holidayName,
      leaveDetails: AttendanceLeaveDetail.listFrom(
        json['leaveDetails'] ?? json['leave_details'],
      ),
    );
  }
}
