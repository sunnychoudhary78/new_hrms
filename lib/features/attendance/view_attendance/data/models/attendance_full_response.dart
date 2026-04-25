import 'attendance_summary_model.dart';
import 'attendance_aggregate_model.dart';

class AttendanceFullResponse {
  final AttendanceSummary summary;
  final List<AttendanceAggregate> days;

  AttendanceFullResponse({required this.summary, required this.days});

  factory AttendanceFullResponse.fromJson(Map<String, dynamic> json) {
    return AttendanceFullResponse(
      summary: AttendanceSummary.fromJson(json),
      days: (json['days'] as List)
          .map((e) => AttendanceAggregate.fromJson(e))
          .toList(),
    );
  }
}
