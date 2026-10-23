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
          final mobileConfig = mobileConfigAsync.asData?.value;
          final requireSelfie = isCheckedIn
              ? (mobileConfig?.requireMobileCheckoutSelfie ?? false)
              : (mobileConfig?.requireMobileCheckinSelfie ?? false);

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
                        _PunchStatusChip(
                          isCheckedIn: isCheckedIn,
                          role: role,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _FingerprintBadge(
                    isCheckedIn: isCheckedIn,
                    enabled: canPunch,
                    requireSelfie: requireSelfie,
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

class _PunchStatusChip extends StatelessWidget {
  final bool isCheckedIn;
  final String role;

  const _PunchStatusChip({
    required this.isCheckedIn,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isCheckedIn
        ? HomeDashColors.accentGreen
        : const Color(0xFFFBBF24);
    final statusLabel = isCheckedIn ? 'PUNCHED IN' : 'PUNCHED OUT';
    final hint = isCheckedIn
        ? (role.isNotEmpty ? 'Working · $role' : 'You are currently in')
        : (role.isNotEmpty ? 'Ready · $role' : 'Tap thumb to punch in');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.65),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.55),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: Colors.white.withValues(alpha: 0.98),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          hint,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.82),
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _FingerprintBadge extends StatelessWidget {
  final bool isCheckedIn;
  final bool enabled;
  final bool requireSelfie;
  final VoidCallback onTap;

  const _FingerprintBadge({
    required this.isCheckedIn,
    required this.enabled,
    required this.requireSelfie,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Next action: Punch Out (red) when already in, Punch In (green) when out.
    final actionColor = !enabled
        ? const Color(0xFF94A3B8)
        : (isCheckedIn
            ? HomeDashColors.accentRed
            : HomeDashColors.accentGreen);
    final actionLabel = isCheckedIn ? 'PUNCH OUT' : 'PUNCH IN';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            customBorder: const CircleBorder(),
            child: Ink(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.14),
                border: Border.all(
                  color: actionColor.withValues(alpha: enabled ? 0.9 : 0.35),
                  width: 2.5,
                ),
              ),
              child: Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: actionColor.withValues(
                              alpha: enabled ? 0.35 : 0.12,
                            ),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.fingerprint_rounded,
                        size: 30,
                        color: actionColor,
                      ),
                    ),
                    if (requireSelfie)
                      Positioned(
                        right: -4,
                        bottom: -2,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: actionColor,
                            border: Border.all(color: Colors.white, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          actionLabel,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
            color: Colors.white.withValues(alpha: enabled ? 0.95 : 0.55),
          ),
        ),
        if (requireSelfie) ...[
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.camera_alt_rounded,
                  size: 9,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 3),
                Text(
                  'Selfie',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
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
                fontWeight: FontWeight.w700,
                color: inTime != null
                    ? HomeDashColors.accentGreen
                    : soft,
              ),
            ),
            const Spacer(),
            Text(
              outTime != null ? _fmt(outTime) : '—',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: outTime != null
                    ? HomeDashColors.accentRed
                    : soft,
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
