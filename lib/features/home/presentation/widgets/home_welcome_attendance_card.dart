import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:lms/features/attendance/mark_attendance/data/models/attendance_session_model.dart';
import 'package:lms/features/attendance/mark_attendance/data/models/effective_shift_model.dart';
import 'package:lms/features/attendance/mark_attendance/presentation/providers/attendance_selectors.dart';
import 'package:lms/features/attendance/mark_attendance/presentation/providers/effective_shift_provider.dart';
import 'package:lms/features/attendance/mark_attendance/presentation/providers/mark_attendance_provider.dart';
import 'package:lms/features/attendance/mark_attendance/presentation/providers/mobile_config_provider.dart';
import 'package:lms/features/attendance/mark_attendance/presentation/widgets/stale_open_session_banner.dart';
import 'package:lms/features/attendance/shared/utils/attendance_date_utils.dart';
import 'package:lms/features/attendance/shared/utils/overtime_estimate_utils.dart';
import 'package:lms/features/home/presentation/widgets/home_dashboard_style.dart';

class HomeWelcomeAttendanceCard extends ConsumerWidget {
  final String name;
  final String role;
  final String? imageUrl;

  const HomeWelcomeAttendanceCard({
    super.key,
    required this.name,
    required this.role,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendanceAsync = ref.watch(markAttendanceProvider);
    final mobileConfigAsync = ref.watch(mobileConfigProvider);
    final canMobileCheckIn = ref.watch(canMobileCheckInProvider);
    final canMobileCheckOut = ref.watch(canMobileCheckOutProvider);
    final shift = ref.watch(effectiveShiftProvider).asData?.value;
    final greeting = _greeting();
    final firstName = _titleCase(name.trim().split(' ').first);
    final primary = Theme.of(context).colorScheme.primary;
    final primaryEnd =
        Color.lerp(primary, Colors.white, 0.18) ?? primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary, primaryEnd],
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.32),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: attendanceAsync.when(
        loading: () => const SizedBox(height: 180),
        error: (_, __) => const SizedBox(height: 180),
        data: (attendance) {
          final sessions = attendance.sessions;
          final openSession = ref.watch(openSessionProvider(sessions));
          final hasOpen = ref.watch(hasOpenSessionProvider(sessions));
          final canStartNew = ref.watch(canStartNewSessionProvider(sessions));
          final isStale = ref.watch(isStaleOpenSessionProvider(sessions));
          final todayList = todaySessions(sessions);

          final isCheckedIn = hasOpen;
          final canPunchIn = canStartNew && canMobileCheckIn;
          final canPunchOut = hasOpen && canMobileCheckOut;
          final configReady = mobileConfigAsync.hasValue;
          final canPunch =
              configReady && (isCheckedIn ? canPunchOut : canPunchIn);

          Future<void> handlePunch() async {
            if (!canPunch) return;
            final notifier = ref.read(markAttendanceProvider.notifier);
            if (isCheckedIn) {
              await notifier.punchOut(context);
            } else {
              await notifier.punchIn(context);
            }
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.2),
                                backgroundImage:
                                    imageUrl != null && imageUrl!.isNotEmpty
                                        ? NetworkImage(imageUrl!)
                                        : null,
                                child: imageUrl == null || imageUrl!.isEmpty
                                    ? Text(
                                        _initials(name),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '$greeting, ',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withValues(
                                          alpha: 0.95,
                                        ),
                                      ),
                                    ),
                                    TextSpan(
                                      text: '$firstName 👋',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          role.isNotEmpty
                              ? 'Ready to make today count · $role'
                              : 'Ready to make today count ✨',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.82),
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _FingerprintBadge(
                    isCheckedIn: isCheckedIn,
                    enabled: canPunch,
                    onTap: handlePunch,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: _LivePunchTimeline(
                  sessions: sessions,
                  openSession: openSession,
                  shift: shift,
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${todayList.length}/2 sessions',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isStale && openSession != null) ...[
                const SizedBox(height: 12),
                StaleOpenSessionBanner(openSession: openSession),
              ],
            ],
          );
        },
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic);
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  static String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  static String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class _FingerprintBadge extends StatelessWidget {
  final bool isCheckedIn;
  final bool enabled;
  final VoidCallback onTap;

  const _FingerprintBadge({
    required this.isCheckedIn,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = !enabled
        ? const Color(0xFF94A3B8)
        : (isCheckedIn
            ? HomeDashColors.accentRed
            : HomeDashColors.accentGreen);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.16),
          ),
          child: Center(
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                Icons.fingerprint_rounded,
                size: 28,
                color: accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LivePunchTimeline extends StatefulWidget {
  final List<AttendanceSession> sessions;
  final AttendanceSession? openSession;
  final EffectiveShift? shift;

  const _LivePunchTimeline({
    required this.sessions,
    required this.openSession,
    required this.shift,
  });

  @override
  State<_LivePunchTimeline> createState() => _LivePunchTimelineState();
}

class _LivePunchTimelineState extends State<_LivePunchTimeline> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant _LivePunchTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.openSession?.id != widget.openSession?.id) {
      _syncTicker();
    }
  }

  void _syncTicker() {
    _ticker?.cancel();
    if (widget.openSession != null) {
      _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  int get _workMinutes {
    final fromShift = expectedMinutesFromOfficeHours(
      widget.shift?.officeStartTime,
      widget.shift?.officeEndTime,
    );
    return fromShift > 0 ? fromShift : 9 * 60;
  }

  int get _workedMinutes {
    final today = todaySessions(widget.sessions);
    var total = 0;
    for (final s in today) {
      total += sessionWorkedMinutes(s);
    }
    final open = widget.openSession;
    if (open != null && sessionDateIso(open) == localTodayIso()) {
      final already = today.any((s) => s.id == open.id);
      if (!already) total += sessionWorkedMinutes(open);
    }
    return total;
  }

  double get _progress {
    if (_workMinutes <= 0) return 0;
    return (_workedMinutes / _workMinutes).clamp(0.0, 1.0);
  }

  String get _durationLabel {
    final m = _workedMinutes;
    final h = m ~/ 60;
    final mins = m % 60;
    return '$h:${mins.toString().padLeft(2, '0')}';
  }

  (DateTime? inTime, DateTime? outTime) get _inOut {
    final today = todaySessions(widget.sessions);
    DateTime? firstIn;
    DateTime? lastOut;
    var hasOpenToday = false;

    for (final s in today) {
      final cin = s.checkInTime.toLocal();
      if (firstIn == null || cin.isBefore(firstIn)) firstIn = cin;
      if (s.checkOutTime == null) {
        hasOpenToday = true;
      } else {
        final cout = s.checkOutTime!.toLocal();
        if (lastOut == null || cout.isAfter(lastOut)) lastOut = cout;
      }
    }

    final open = widget.openSession;
    if (open != null && sessionDateIso(open) == localTodayIso()) {
      hasOpenToday = true;
      final cin = open.checkInTime.toLocal();
      if (firstIn == null || cin.isBefore(firstIn)) firstIn = cin;
    }

    if (hasOpenToday) lastOut = null;

    return (firstIn, lastOut);
  }

  @override
  Widget build(BuildContext context) {
    final (inTime, outTime) = _inOut;
    final hasActivity = widget.openSession != null || _workedMinutes > 0;
    final fill = hasActivity ? _progress : 0.0;
    final light = Colors.white.withValues(alpha: 0.9);
    final soft = Colors.white.withValues(alpha: 0.72);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Today',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: soft,
              ),
            ),
            const Spacer(),
            Text(
              _durationLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: light,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 10,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Container(
                      width: constraints.maxWidth,
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      width: constraints.maxWidth * fill,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF86EFAC), Color(0xFF22C55E)],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              inTime != null ? _fmt(inTime) : '—',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: soft,
              ),
            ),
            const Spacer(),
            Text(
              outTime != null ? _fmt(outTime) : '—',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: soft,
              ),
            ),
          ],
        ),
        if (widget.shift != null) ...[
          const SizedBox(height: 6),
          Text(
            'Office ${widget.shift!.officeStartDisplay} – ${widget.shift!.officeEndDisplay}'
            '${widget.shift!.startSubtitle.isNotEmpty ? ' · ${widget.shift!.startSubtitle}' : ''}',
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.68),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  static String _fmt(DateTime t) => DateFormat('hh:mm a').format(t.toLocal());
}
