import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lms/features/attendance/view_attendance/data/models/attendance_summary_model.dart';
import 'package:lms/features/attendance/view_attendance/utils/attendance_status_color.dart';

class AttendanceSummaryGrid extends StatelessWidget {
  final AttendanceSummary summary;

  const AttendanceSummaryGrid({super.key, required this.summary});

  Widget _tile(BuildContext context, String title, String value, Color color) {
    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(isIOS ? 12 : 16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return "${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _tile(
          context,
          "Working Days",
          "${summary.workingDays}",
          AttendanceStatusColor.fromStatus(context, "present"),
        ),
        _tile(
          context,
          "Late Days",
          "${summary.lateDays}",
          AttendanceStatusColor.fromStatus(context, "late"),
        ),
        _tile(
          context,
          "Leaves",
          "${summary.totalLeaves}",
          AttendanceStatusColor.fromStatus(context, "leave"),
        ),
        _tile(
          context,
          "Absent",
          "${summary.absentDays}",
          AttendanceStatusColor.fromStatus(context, "absent"),
        ),
        _tile(
          context,
          "Payable Days",
          "${summary.payableDays}",
          AttendanceStatusColor.fromStatus(context, "present"),
        ),
        _tile(
          context,
          "Total Working Hours",
          _formatMinutes(summary.totalMinutes),
          Colors.indigo,
        ),
        _tile(
          context,
          "Expected Hours",
          "${summary.expectedWorkingHours} hrs",
          Colors.teal,
        ),
      ],
    );
  }
}
