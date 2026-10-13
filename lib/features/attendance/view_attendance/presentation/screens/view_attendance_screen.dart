import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:lms/features/attendance/correction_attendance/presentation/dialogs/request_correction_dialog.dart';
import 'package:lms/features/attendance/view_attendance/data/models/attendance_aggregate_model.dart';
import 'package:lms/features/attendance/view_attendance/presentation/providers/view_attendance_provider.dart';
import 'package:lms/features/attendance/view_attendance/presentation/widgets/view_attendance_header.dart';
import 'package:lms/features/auth/presentation/providers/auth_provider.dart';
import 'package:lms/features/dashboard/presentation/providers/team_attendance_provider.dart';
import 'package:lms/features/home/presentation/widgets/app_drawer.dart';
import 'package:lms/features/home/presentation/widgets/home_dashboard_style.dart';

import 'package:lms/shared/widgets/attendance_calender_widget.dart';
import 'package:lms/shared/widgets/attendance_day_detail_bottom_sheet.dart';

import 'package:lms/features/dashboard/data/models/attendance_day_data.dart';
import 'package:lms/features/attendance/mark_attendance/data/models/company_settings_model.dart';
import 'package:lms/features/attendance/mark_attendance/presentation/providers/company_settings_provider.dart';
import 'package:lms/features/attendance/shared/utils/overtime_estimate_utils.dart';
import 'package:lms/features/attendance/view_attendance/utils/elapsed_month_summary.dart';
import 'package:lms/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:lms/features/notifications/presentation/screens/notifications_screen.dart';

import '../widgets/attendance_summary_grid.dart';
import '../widgets/view_attendance_stats_row.dart';

class ViewAttendanceScreen extends ConsumerStatefulWidget {
  const ViewAttendanceScreen({super.key});

  @override
  ConsumerState<ViewAttendanceScreen> createState() =>
      _ViewAttendanceScreenState();
}

class _ViewAttendanceScreenState extends ConsumerState<ViewAttendanceScreen> {
  DateTime focused = DateTime.now();
  DateTime? selectedDay;

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.invalidate(viewAttendanceProvider);

      ref.invalidate(
        employeeAttendanceProvider(
          AttendanceParams(
            userId: "",
            month: focused, // ✅ FIXED
          ),
        ),
      );
    });
  }

  ////////////////////////////////////////////////////////////////
  /// BUILD ATTENDANCE MAP FROM AGGREGATES + SESSIONS
  ////////////////////////////////////////////////////////////////

  AttendanceDayData? _sessionDataForDay(
    DateTime day,
    Map<String, AttendanceDayData> sessionMap,
  ) {
    final directKey = DateFormat('yyyy-MM-dd').format(day);
    final direct = sessionMap[directKey];
    if (direct != null) return direct;

    for (final entry in sessionMap.entries) {
      final parsed = DateTime.tryParse(entry.key);
      if (parsed != null && DateUtils.isSameDay(parsed.toLocal(), day)) {
        return entry.value;
      }
    }

    return null;
  }

  Map<String, AttendanceDayData> _buildAttendanceMap(
    List aggregates,
    Map<String, AttendanceDayData> sessionMap,
  ) {
    final Map<String, AttendanceDayData> map = {};

    for (final agg in aggregates) {
      final key = DateFormat('yyyy-MM-dd').format(agg.date);
      final sessionData = _sessionDataForDay(agg.date, sessionMap);
      final sessions = sessionData?.sessions ?? [];

      map[key] = AttendanceDayData(
        date: key,
        status: AttendanceDayData.resolveStatusWithSessions(
          agg.status,
          sessions,
        ),
        totalMinutes: sessionData?.totalMinutes ?? 0,
        sessions: sessions,
        leaveType: agg.leaveType ?? sessionData?.leaveType,
        holidayName: agg.holidayName ?? sessionData?.holidayName,
        leaveDetails: agg.leaveDetails.isNotEmpty
            ? agg.leaveDetails
            : (sessionData?.leaveDetails ?? const []),
        isLate: _isLateForSchedule(
          sessions,
          ref.watch(companySettingsProvider).asData?.value,
          agg.isLate,
        ),
      );
    }

    return map;
  }

  bool _isLateForSchedule(
    List<AttendanceSessionData> sessions,
    CompanySettings? settings,
    bool apiLate,
  ) {
    final start = settings?.officeStart?.trim() ?? '';
    final grace = settings?.lateGraceMinutes;
    if (start.isEmpty || grace == null) return apiLate;

    DateTime? first;
    for (final session in sessions) {
      final checkIn = session.checkIn;
      if (checkIn == null) continue;
      if (first == null || checkIn.isBefore(first)) first = checkIn;
    }
    if (first == null) return apiLate;

    return isCheckInLate(
      checkIn: first,
      officeStart: start,
      graceMinutes: grace,
    );
  }

  ////////////////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(viewAttendanceProvider);
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    return Scaffold(
      backgroundColor: HomeDashColors.bg,
      drawer: const AppDrawer(),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: HomeDashColors.bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: HomeDashColors.title,
        centerTitle: false,
        titleSpacing: 0,
        title: const Text(
          'View Attendance',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: HomeDashColors.title,
          ),
        ),
        actions: [
          const _NotificationIcon(),
          const _ProfileAvatarButton(),
          SizedBox(width: isIOS ? 4 : 8),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            e.toString(),
            style: const TextStyle(color: HomeDashColors.accentRed),
          ),
        ),
        data: (state) {
          final summary = state.summary;
          final sessionAsync = ref.watch(
            employeeAttendanceProvider(
              AttendanceParams(userId: '', month: focused),
            ),
          );

          final attendanceMap = sessionAsync.when(
            data: (sessionMap) => _buildAttendanceMap(state.days, sessionMap),
            loading: () => <String, AttendanceDayData>{},
            error: (_, __) => <String, AttendanceDayData>{},
          );

          final displaySummary = resolveElapsedMonthSummary(
            apiSummary: summary,
            aggregates: state.days,
            attendanceMap: attendanceMap,
          );

          final daysInMonth = DateUtils.getDaysInMonth(
            focused.year,
            focused.month,
          );

          return RefreshIndicator(
            onRefresh: () async {
              await ref
                  .read(viewAttendanceProvider.notifier)
                  .changeMonth(focused);
              ref.invalidate(
                employeeAttendanceProvider(
                  AttendanceParams(userId: '', month: focused),
                ),
              );
            },
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: isIOS
                  ? const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    )
                  : const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ViewAttendanceHeader(),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: HomeDashColors.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
                          child: Text(
                            'Attendance Calendar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: HomeDashColors.title,
                            ),
                          ),
                        ),
                        AttendanceCalendarWidget(
                          focusedDay: focused,
                          selectedDay: selectedDay,
                          statusResolver: (day) {
                            final key = DateFormat('yyyy-MM-dd').format(day);
                            return attendanceMap[key]?.calendarStatus;
                          },
                          typeLabelResolver: (day) {
                            final key = DateFormat('yyyy-MM-dd').format(day);
                            return attendanceMap[key]?.calendarCellLabel;
                          },
                          typeColorResolver: (day) {
                            final key = DateFormat('yyyy-MM-dd').format(day);
                            return attendanceMap[key]?.calendarCellColor;
                          },
                          hasSelfie: (day) {
                            final key = DateFormat('yyyy-MM-dd').format(day);
                            final data = attendanceMap[key];
                            if (data == null) return false;
                            return data.sessions.any(
                              (s) =>
                                  s.checkInSelfie != null ||
                                  s.checkOutSelfie != null,
                            );
                          },
                          hasLocation: (day) {
                            final key = DateFormat('yyyy-MM-dd').format(day);
                            final data = attendanceMap[key];
                            if (data == null) return false;
                            return data.sessions.any(
                              (s) => s.lat != null && s.lng != null,
                            );
                          },
                          onDaySelected: (selected, focusedDay) {
                            setState(() {
                              selectedDay = selected;
                              focused = focusedDay;
                            });
                            final key =
                                DateFormat('yyyy-MM-dd').format(selected);
                            AttendanceDayDetailBottomSheet.show(
                              context,
                              date: selected,
                              data: attendanceMap[key],
                            );
                          },
                          onPageChanged: (d) {
                            setState(() => focused = d);
                            ref
                                .read(viewAttendanceProvider.notifier)
                                .changeMonth(d);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  ViewAttendanceStatsRow(
                    workingDays: displaySummary.workingDays,
                    daysInMonth: daysInMonth,
                    onRequestCorrection: () {
                      showRequestCorrectionDialog(
                        context: context,
                        selectedDate: selectedDay ?? DateTime.now(),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  AttendanceSummaryGrid(summary: displaySummary),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProfileAvatarButton extends ConsumerWidget {
  const _ProfileAvatarButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final url = auth.profileUrl;
    final name = auth.profile?.associatesName ?? 'U';
    final parts = name.trim().split(' ');
    final initials = parts.isEmpty || parts.first.isEmpty
        ? 'U'
        : (parts.length == 1
            ? parts.first[0].toUpperCase()
            : (parts.first[0] + parts.last[0]).toUpperCase());

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/profile'),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: HomeDashColors.softBlue,
              backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
              child: url.isEmpty
                  ? Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: HomeDashColors.accentBlue,
                      ),
                    )
                  : null,
            ),
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: HomeDashColors.accentGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
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
