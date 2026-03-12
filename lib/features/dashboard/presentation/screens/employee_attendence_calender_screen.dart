import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lms/shared/widgets/app_bar.dart';
import 'package:lms/shared/widgets/attendance_calender_widget.dart';
import 'package:lms/shared/widgets/attendance_day_detail_bottom_sheet.dart';
import '../../data/models/team_dashboard_model.dart';
import '../providers/team_attendance_provider.dart';

class EmployeeAttendanceCalendarScreen extends ConsumerStatefulWidget {
  final TeamEmployee employee;

  const EmployeeAttendanceCalendarScreen({super.key, required this.employee});

  @override
  ConsumerState<EmployeeAttendanceCalendarScreen> createState() =>
      _EmployeeAttendanceCalendarScreenState();
}

class _EmployeeAttendanceCalendarScreenState
    extends ConsumerState<EmployeeAttendanceCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  ////////////////////////////////////////////////////////////////
  /// LEGEND ITEM
  ////////////////////////////////////////////////////////////////

  Widget _legendItem(String label, Color color, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  ////////////////////////////////////////////////////////////////

  Color _statusColor(String status) {
    switch (status) {
      case "On-Time":
        return const Color(0xFF22C55E);
      case "Late":
        return const Color(0xFFF59E0B);
      case "Absent":
        return const Color(0xFFEF4444);
      case "Holiday":
        return const Color(0xFF3B82F6);
      case "On-Leave":
        return const Color(0xFFA855F7);
      default:
        return Colors.grey;
    }
  }

  ////////////////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final attendanceAsync = ref.watch(
      employeeAttendanceProvider(
        AttendanceParams(userId: widget.employee.userId, month: _focusedDay),
      ),
    );

    return Scaffold(
      appBar: AppAppBar(title: "View Attendance"),
      backgroundColor: scheme.surfaceContainerLowest,

      body: attendanceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),

        error: (error, stack) => Center(child: Text(error.toString())),

        data: (attendanceMap) {
          ////////////////////////////////////////////////////////////

          String? resolveStatus(DateTime day) {
            final key = DateFormat('yyyy-MM-dd').format(day);
            return attendanceMap[key]?.status;
          }

          ////////////////////////////////////////////////////////////

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _EmployeeHeader(employee: widget.employee),

                const SizedBox(height: 24),

                ////////////////////////////////////////////////////
                /// CALENDAR
                ////////////////////////////////////////////////////
                AttendanceCalendarWidget(
                  focusedDay: _focusedDay,
                  selectedDay: _selectedDay,

                  statusResolver: resolveStatus,

                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });

                    final key = DateFormat('yyyy-MM-dd').format(selectedDay);

                    final dayData = attendanceMap[key];

                    AttendanceDayDetailBottomSheet.show(
                      context,
                      date: selectedDay,
                      data: dayData,
                    );
                  },

                  onPageChanged: (focusedDay) {
                    setState(() {
                      _focusedDay = focusedDay;
                    });
                  },
                ),

                const SizedBox(height: 28),

                ////////////////////////////////////////////////////
                /// LEGEND
                ////////////////////////////////////////////////////
                Text(
                  "Attendance Legend",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),

                const SizedBox(height: 14),

                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _legendItem("On-Time", _statusColor("On-Time"), scheme),

                    _legendItem("Late", _statusColor("Late"), scheme),

                    _legendItem("Absent", _statusColor("Absent"), scheme),

                    _legendItem("Holiday", _statusColor("Holiday"), scheme),

                    _legendItem("On-Leave", _statusColor("On-Leave"), scheme),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

//////////////////////////////////////////////////////////////

class _EmployeeHeader extends StatelessWidget {
  final TeamEmployee employee;

  const _EmployeeHeader({required this.employee});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: scheme.primaryContainer,
            child: Text(
              employee.name.isNotEmpty ? employee.name[0].toUpperCase() : "?",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),

          const SizedBox(width: 14),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                employee.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
