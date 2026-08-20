import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:lms/features/attendance/mark_attendance/presentation/providers/attendance_selectors.dart';
import 'package:lms/features/attendance/mark_attendance/presentation/providers/effective_shift_provider.dart';
import 'package:lms/features/attendance/mark_attendance/presentation/providers/mark_attendance_provider.dart';
import 'package:lms/features/attendance/mark_attendance/presentation/widgets/attendance_actions_screen.dart';

import 'package:lms/features/attendance/mark_attendance/presentation/widgets/attendance_status_tile.dart';
import 'package:lms/features/attendance/mark_attendance/presentation/widgets/mark_attendance_header.dart';
import 'package:lms/features/attendance/shared/utils/attendance_date_utils.dart';
import 'package:lms/features/attendance/view_attendance/utils/attendance_status_color.dart';

import 'package:lms/features/home/presentation/widgets/app_drawer.dart';
import 'package:lms/shared/widgets/app_bar.dart';

import '../widgets/live_clock_card.dart';
import '../widgets/session_logs.dart';
import '../widgets/stale_open_session_banner.dart';

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
  Timer? _shiftPollTimer;

  @override
  void initState() {
    super.initState();
    _shiftPollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _pollEffectiveShift();
    });
  }

  @override
  void dispose() {
    _shiftPollTimer?.cancel();
    super.dispose();
  }

  void _pollEffectiveShift() {
    final shift = ref.read(effectiveShiftProvider).asData?.value;
    final sessions =
        ref.read(markAttendanceProvider).asData?.value.sessions ?? [];
    if (shift == null) return;
    if (shift.isFixedMode) return;
    if (hasOpenSession(sessions)) return;
    ref.read(effectiveShiftProvider.notifier).refresh();
  }

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
    final shift = ref.watch(effectiveShiftProvider).asData?.value;

    final dayName = DateFormat('EEEE').format(now);

    return Scaffold(
      appBar: AppAppBar(title: "Mark Attendance", showBack: false),
      drawer: AppDrawer(),
      backgroundColor: scheme.surfaceContainerLowest,
      body: attendanceAsync.when(
        loading: () => const SizedBox(),
        error: (_, __) => const SizedBox(),
        data: (attendance) {
          final sessions = attendance.sessions;
          final openSession = ref.watch(openSessionProvider(sessions));
          final hasOpen = ref.watch(hasOpenSessionProvider(sessions));
          final isStale = ref.watch(isStaleOpenSessionProvider(sessions));
          final todayCount = todaySessions(sessions).length;

          final punchInTime = openSession?.checkInTime;
          final punchOutTime = openSession?.checkOutTime;

          final workingTime = punchInTime == null
              ? "00:00"
              : _duration(punchInTime);

          final progress = _workProgressFromPunchIn(
            punchInTime: punchInTime,
            officeEnd: shift?.officeEndTod,
            isOvernight: shift?.isOvernight ?? false,
          );

          final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                  shift: shift,
                  isCheckedIn: hasOpen,
                ),

                const SizedBox(height: 32),

                AttendanceStatusTiles(
                  punchInTime: punchInTime,
                  punchOutTime: punchOutTime,
                ),

                const SizedBox(height: 32),

                if (isStale && openSession != null)
                  StaleOpenSessionBanner(openSession: openSession),

                AttendanceActionsSection(
                  hasOpenSession: hasOpen,
                  isRemoteMode: isRemoteMode,
                  remoteReason: remoteReason,
                  onEnableRemoteMode: enableRemoteMode,
                  onResetRemoteMode: resetRemoteMode,
                ),

                const SizedBox(height: 16),

                _TodayStatusRow(
                  status: attendance.todayStatus,
                  sessionCount: todayCount,
                ),

                const SizedBox(height: 24),

                SessionLogs(sessions: sessions),
              ],
            ),
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

  double _workProgressFromPunchIn({
    required DateTime? punchInTime,
    required TimeOfDay? officeEnd,
    required bool isOvernight,
  }) {
    if (punchInTime == null || officeEnd == null) return 0;

    var end = DateTime(
      punchInTime.year,
      punchInTime.month,
      punchInTime.day,
      officeEnd.hour,
      officeEnd.minute,
    );

    if (isOvernight || !end.isAfter(punchInTime)) {
      if (!end.isAfter(punchInTime)) {
        end = end.add(const Duration(days: 1));
      }
    }

    final total = end.difference(punchInTime).inSeconds;
    if (total <= 0) return 1;

    final worked = DateTime.now().difference(punchInTime).inSeconds;
    return (worked / total).clamp(0.0, 1.0);
  }
}

class _TodayStatusRow extends StatelessWidget {
  final String status;
  final int sessionCount;

  const _TodayStatusRow({
    required this.status,
    required this.sessionCount,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = AttendanceStatusColor.fromStatus(context, status);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          status,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: statusColor,
          ),
        ),
        Text(
          "$sessionCount/2 sessions",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
