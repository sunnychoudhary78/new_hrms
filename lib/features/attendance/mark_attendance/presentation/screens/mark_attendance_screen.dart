import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:lms/features/attendance/mark_attendance/presentation/providers/attendance_selectors.dart';
import 'package:lms/features/attendance/mark_attendance/presentation/providers/mark_attendance_provider.dart';
import 'package:lms/features/attendance/mark_attendance/presentation/providers/company_settings_provider.dart';
import 'package:lms/features/attendance/mark_attendance/presentation/widgets/attendance_actions_screen.dart';

import 'package:lms/features/attendance/mark_attendance/presentation/widgets/attendance_status_tile.dart';
import 'package:lms/features/attendance/mark_attendance/presentation/widgets/mark_attendance_header.dart';

import 'package:lms/features/home/presentation/widgets/app_drawer.dart';
import 'package:lms/shared/widgets/app_bar.dart';

import '../widgets/live_clock_card.dart';
import '../widgets/session_logs.dart';

class MarkAttendanceScreen extends ConsumerStatefulWidget {
  const MarkAttendanceScreen({super.key});

  @override
  ConsumerState<MarkAttendanceScreen> createState() =>
      _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends ConsumerState<MarkAttendanceScreen> {
  DateTime now = DateTime.now();

  bool isRemoteMode = false;
  String? remoteReason;

  void enableRemoteMode(String reason) {
    setState(() {
      isRemoteMode = true;
      remoteReason = reason;
    });
  }

  void resetRemoteMode() {
    setState(() {
      isRemoteMode = false;
      remoteReason = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final attendanceAsync = ref.watch(markAttendanceProvider);
    final settingsAsync = ref.watch(companySettingsProvider);

    final dayName = DateFormat('EEEE').format(now);

    return Scaffold(
      appBar: AppAppBar(title: "Mark Attendance", showBack: false),
      drawer: AppDrawer(),
      backgroundColor: scheme.surfaceContainerLowest,
      body: attendanceAsync.when(
        loading: () => const SizedBox(),
        error: (_, __) => const SizedBox(),
        data: (attendanceState) {
          return settingsAsync.when(
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
            data: (settings) {
              final activeSession = ref.watch(
                activeSessionProvider(attendanceState),
              );

              final punchInTime = activeSession?.checkInTime;
              final punchOutTime = activeSession?.checkOutTime;

              final workingTime = punchInTime == null
                  ? "00:00"
                  : _duration(punchInTime);

              final officeStart = _parseTime(settings.officeStart);
              final officeEnd = _parseTime(settings.officeEnd);

              final progress = _workProgressFromPunchIn(punchInTime, officeEnd);

              final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: isIOS
                    ? const BouncingScrollPhysics()
                    : const ClampingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    MarkAttendanceHeader(dayName: dayName),

                    const SizedBox(height: 24),

                    LiveClockCard(
                      workingTime: workingTime,
                      progress: progress,
                      shiftStart: officeStart,
                      shiftEnd: officeEnd,
                      isCheckedIn: punchInTime != null, // ADD THIS
                    ),

                    const SizedBox(height: 32),

                    AttendanceStatusTiles(
                      punchInTime: punchInTime,
                      punchOutTime: punchOutTime,
                    ),

                    const SizedBox(height: 32),

                    /// ACTION SECTION (NEW CLEAN WIDGET)
                    AttendanceActionsSection(
                      punchInTime: punchInTime,
                      punchOutTime: punchOutTime,
                      isRemoteMode: isRemoteMode,
                      remoteReason: remoteReason,
                      onEnableRemoteMode: enableRemoteMode,
                      onResetRemoteMode: resetRemoteMode,
                    ),

                    const SizedBox(height: 24),

                    SessionLogs(sessions: attendanceState),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _duration(DateTime start) {
    final diff = DateTime.now().difference(start);
    final h = diff.inHours.toString().padLeft(2, '0');
    final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
    return "$h:$m";
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null || value.isEmpty) return null;

    final parts = value.split(':');
    if (parts.length < 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return null;

    return TimeOfDay(hour: hour, minute: minute);
  }

  double _workProgressFromPunchIn(DateTime? punchInTime, TimeOfDay? officeEnd) {
    if (punchInTime == null || officeEnd == null) return 0;

    final now = DateTime.now();

    final end = DateTime(
      now.year,
      now.month,
      now.day,
      officeEnd.hour,
      officeEnd.minute,
    );

    final total = end.difference(punchInTime).inSeconds;

    if (total <= 0) return 1;

    final worked = now.difference(punchInTime).inSeconds;

    return (worked / total).clamp(0.0, 1.0);
  }
}
