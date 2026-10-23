import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:lms/features/attendance/mark_attendance/presentation/providers/attendance_selectors.dart';
import 'package:lms/features/attendance/mark_attendance/presentation/providers/effective_shift_provider.dart';
import 'package:lms/features/attendance/mark_attendance/presentation/providers/mark_attendance_provider.dart';
import 'package:lms/features/attendance/mark_attendance/presentation/providers/mobile_config_provider.dart';
import 'package:lms/features/attendance/mark_attendance/presentation/widgets/attendance_actions_screen.dart';
import 'package:lms/features/attendance/mark_attendance/presentation/widgets/mark_attendance_header.dart';
import 'package:lms/features/attendance/mark_attendance/presentation/widgets/mark_attendance_punch_hero.dart';
import 'package:lms/features/attendance/shared/utils/attendance_date_utils.dart';
import 'package:lms/features/attendance/view_attendance/utils/attendance_status_color.dart';
import 'package:lms/features/home/presentation/widgets/app_drawer.dart';
import 'package:lms/features/home/presentation/widgets/home_dashboard_style.dart';
import 'package:lms/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:lms/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:lms/features/onboarding/data/day_one_route.dart';
import 'package:lms/features/onboarding/presentation/widgets/feature_tour_overlay.dart';

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
  Timer? _clockTimer;
  final GlobalKey _punchInKey = GlobalKey();
  final GlobalKey _punchOutKey = GlobalKey();
  bool _tourStarted = false;

  @override
  void initState() {
    super.initState();
    _shiftPollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _pollEffectiveShift();
    });
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => now = DateTime.now());
    });
  }

  void _maybeStartTour() {
    if (_tourStarted || !mounted) return;
    final tour = tourIdFromArgs(ModalRoute.of(context)?.settings.arguments);
    if (tour != 'attendance') return;
    _tourStarted = true;
    FeatureTourOverlay.maybeStart(
      context: context,
      tourId: tour,
      targets: {
        'attendance-clock-in': _punchInKey,
        'attendance-clock-out': _punchOutKey,
      },
    );
  }

  @override
  void dispose() {
    FeatureTourOverlay.hide();
    _shiftPollTimer?.cancel();
    _clockTimer?.cancel();
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
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final attendanceAsync = ref.watch(markAttendanceProvider);
    final shift = ref.watch(effectiveShiftProvider).asData?.value;
    final dayName = DateFormat('EEEE').format(now);
    final dash = HomeDashColors.of(context);

    return Scaffold(
      backgroundColor: dash.bg,
      drawer: const AppDrawer(),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: dash.bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: dash.title,
        centerTitle: false,
        titleSpacing: 0,
        title: Text(
          'Mark Attendance',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: dash.title,
          ),
        ),
        actions: [
          const _NotificationIcon(),
          SizedBox(width: isIOS ? 4 : 8),
        ],
      ),
      body: attendanceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (attendance) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartTour());
          final sessions = attendance.sessions;
          final openSession = ref.watch(openSessionProvider(sessions));
          final hasOpen = ref.watch(hasOpenSessionProvider(sessions));
          final isStale = ref.watch(isStaleOpenSessionProvider(sessions));
          final todayCount = todaySessions(sessions).length;
          final canStartNew = ref.watch(canStartNewSessionProvider(sessions));
          final canMobileCheckIn = ref.watch(canMobileCheckInProvider);
          final canMobileCheckOut = ref.watch(canMobileCheckOutProvider);

          final punchInTime = openSession?.checkInTime;
          final progress = _workProgressFromPunchIn(
            punchInTime: punchInTime,
            officeEnd: shift?.officeEndTod,
            isOvernight: shift?.isOvernight ?? false,
          );
          final workingTime =
              punchInTime == null ? '00:00' : _duration(punchInTime);

          final canHeroPunch = hasOpen
              ? (hasOpen && canMobileCheckOut)
              : (canStartNew && canMobileCheckIn);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(markAttendanceProvider);
              ref.invalidate(effectiveShiftProvider);
              await Future.delayed(const Duration(milliseconds: 250));
            },
            child: SingleChildScrollView(
              physics: isIOS
                  ? const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    )
                  : const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              child: Column(
                children: [
                  MarkAttendanceHeader(dayName: dayName),
                  const SizedBox(height: 14),
                  LiveClockCard(
                    workingTime: workingTime,
                    progress: progress,
                    shift: shift,
                    isCheckedIn: hasOpen,
                  ),
                  const SizedBox(height: 14),
                  if (isStale && openSession != null)
                    StaleOpenSessionBanner(openSession: openSession),
                  MarkAttendancePunchHero(
                    isCheckedIn: hasOpen,
                    canPunch: canHeroPunch,
                    progress: progress,
                    onPunch: () async {
                      final notifier =
                          ref.read(markAttendanceProvider.notifier);
                      if (hasOpen) {
                        if (isRemoteMode && remoteReason != null) {
                          await notifier.punchOutRemote(
                            context,
                            remoteReason!,
                          );
                          resetRemoteMode();
                        } else {
                          await notifier.punchOut(context);
                        }
                      } else {
                        if (isRemoteMode && remoteReason != null) {
                          await notifier.punchInRemote(
                            context,
                            remoteReason!,
                          );
                          resetRemoteMode();
                        } else {
                          await notifier.punchIn(context);
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  AttendanceActionsSection(
                    hasOpenSession: hasOpen,
                    isRemoteMode: isRemoteMode,
                    remoteReason: remoteReason,
                    onEnableRemoteMode: enableRemoteMode,
                    onResetRemoteMode: resetRemoteMode,
                    punchInKey: _punchInKey,
                    punchOutKey: _punchOutKey,
                  ),
                  const SizedBox(height: 16),
                  _TodayStatusRow(
                    status: attendance.todayStatus,
                    sessionCount: todayCount,
                  ),
                  const SizedBox(height: 18),
                  SessionLogs(sessions: sessions),
                ],
              ),
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
    return '$h:$m';
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
    final statusColor = AttendanceStatusColor.fromStatus(context, status);

    return Row(
      children: [
        Expanded(
          child: Divider(color: HomeDashColors.muted.withValues(alpha: 0.25)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            sessionCount == 0
                ? 'No sessions yet'
                : '$status · $sessionCount/2 sessions',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: sessionCount == 0 ? HomeDashColors.muted : statusColor,
            ),
          ),
        ),
        Expanded(
          child: Divider(color: HomeDashColors.muted.withValues(alpha: 0.25)),
        ),
      ],
    );
  }
}

class _NotificationIcon extends ConsumerWidget {
  const _NotificationIcon();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadCountProvider);
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          iconSize: 24,
          splashRadius: 24,
          style: IconButton.styleFrom(
            splashFactory:
                isIOS ? NoSplash.splashFactory : InkSplash.splashFactory,
          ),
          icon: const Icon(Icons.notifications_none_rounded),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationScreen()),
            );
          },
        ),
        if (unreadCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: HomeDashColors.accentRed,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  unreadCount > 9 ? '9+' : unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
