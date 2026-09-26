import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lms/features/attendance/view_attendance/data/models/attendance_summary_model.dart';
import 'package:lms/features/attendance/view_attendance/utils/attendance_status_color.dart';

class AttendanceSummaryGrid extends StatelessWidget {
  final AttendanceSummary summary;
  final List<String> holidayLabels;

  const AttendanceSummaryGrid({
    super.key,
    required this.summary,
    this.holidayLabels = const [],
  });

  String _formatNumber(num value) =>
      value == value.truncateToDouble() ? value.toInt().toString() : '$value';

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

  Widget _leaveChip(BuildContext context, LeaveBreakdown lb) {
    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final color = AttendanceStatusColor.fromStatus(context, "leave");

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(isIOS ? 10 : 12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            lb.type,
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "${lb.days}",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _tile(
              context,
              "Working Days",
              _formatNumber(summary.workingDays),
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
              _formatNumber(summary.totalLeaves),

              AttendanceStatusColor.fromStatus(context, "leave"),
            ),
            _tile(
              context,
              "Absent",
              _formatNumber(summary.absentDays),
              AttendanceStatusColor.fromStatus(context, "absent"),
            ),
            _tile(
              context,
              "Payable Days",
              _formatNumber(summary.payableDays),
              AttendanceStatusColor.fromStatus(context, "present"),
            ),
            _tile(
              context,
              "Total Working Hours",
              summary.workingHours,
              Colors.indigo,
            ),
            _tile(
              context,
              "Expected Hours",
              "${summary.expectedWorkingHours} hrs",
              Colors.teal,
            ),
            _tile(
              context,
              "Week Offs",
              "${summary.totalWeekoffs}",
              Colors.blueGrey,
            ),
            _tile(
              context,
              "Holidays",
              "${summary.totalHolidays}",
              Colors.deepOrange,
            ),
          ],
        ),
        if (summary.leaveBreakdown.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            "Leave Breakdown",
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: summary.leaveBreakdown
                .map((lb) => _leaveChip(context, lb))
                .toList(),
          ),
        ],
        if (holidayLabels.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            "Holiday Calendar",
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: holidayLabels.map((label) {
              const color = Color(0xFF0891B2);
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
