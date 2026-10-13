import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:lms/features/attendance/mark_attendance/data/models/attendance_session_model.dart';
import 'package:lms/features/attendance/mark_attendance/presentation/providers/attendance_selectors.dart';
import 'package:lms/features/attendance/mark_attendance/presentation/providers/mark_attendance_provider.dart';
import 'package:lms/features/attendance/mark_attendance/presentation/providers/mobile_config_provider.dart';
import 'package:lms/features/attendance/shared/utils/attendance_date_utils.dart';
import 'package:lms/features/attendance/shared/utils/overtime_estimate_utils.dart';
import 'package:lms/features/home/presentation/widgets/home_dashboard_style.dart';

class AttendanceActionsSection extends ConsumerWidget {
  final bool hasOpenSession;
  final bool isRemoteMode;
  final String? remoteReason;
  final Function(String reason) onEnableRemoteMode;
  final VoidCallback onResetRemoteMode;
  final GlobalKey? punchInKey;
  final GlobalKey? punchOutKey;

  const AttendanceActionsSection({
    super.key,
    required this.hasOpenSession,
    required this.isRemoteMode,
    required this.remoteReason,
    required this.onEnableRemoteMode,
    required this.onResetRemoteMode,
    this.punchInKey,
    this.punchOutKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(markAttendanceProvider.notifier);
    final sessions = ref.watch(markAttendanceProvider).value?.sessions ?? [];
    final canStartNew = ref.watch(canStartNewSessionProvider(sessions));
    final mobileConfigAsync = ref.watch(mobileConfigProvider);
    final canMobileCheckIn = ref.watch(canMobileCheckInProvider);
    final canMobileCheckOut = ref.watch(canMobileCheckOutProvider);

    final canCheckIn = canStartNew && canMobileCheckIn;
    final canCheckOut = hasOpenSession && canMobileCheckOut;

    final times = _todayPunchTimes(sessions);
    final checkInLabel = times.checkIn != null
        ? _fmtTime(times.checkIn!)
        : '--:--';
    final checkOutLabel = hasOpenSession
        ? 'In progress'
        : (times.checkOut != null ? _fmtTime(times.checkOut!) : '--:--');
    final workedLabel = times.workedMinutes > 0
        ? _fmtDuration(times.workedMinutes)
        : null;

    Future<void> doPunchIn() async {
      if (isRemoteMode && remoteReason != null) {
        await notifier.punchInRemote(context, remoteReason!);
        onResetRemoteMode();
      } else {
        await notifier.punchIn(context);
      }
    }

    Future<void> doPunchOut() async {
      if (isRemoteMode && remoteReason != null) {
        await notifier.punchOutRemote(context, remoteReason!);
        onResetRemoteMode();
      } else {
        await notifier.punchOut(context);
      }
    }

    return mobileConfigAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Text('Attendance actions unavailable'),
      data: (_) => Column(
        children: [
          Row(
            children: [
              Expanded(
                child: KeyedSubtree(
                  key: punchInKey,
                  child: _ActionTile(
                    title: 'Check In',
                    subtitle: checkInLabel,
                    detail: times.checkIn != null
                        ? (workedLabel != null
                            ? 'Worked $workedLabel'
                            : 'First punch today')
                        : 'Start your day',
                    icon: Icons.login_rounded,
                    bg: HomeDashColors.softGreen,
                    fg: HomeDashColors.accentGreen,
                    enabled: canCheckIn,
                    onTap: canCheckIn ? doPunchIn : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: KeyedSubtree(
                  key: punchOutKey,
                  child: _ActionTile(
                    title: 'Check Out',
                    subtitle: checkOutLabel,
                    detail: hasOpenSession
                        ? 'Tap to end current session'
                        : (times.checkOut != null
                            ? 'Last punch out'
                            : 'End your day'),
                    icon: Icons.logout_rounded,
                    bg: const Color(0xFFFFE4E6),
                    fg: HomeDashColors.accentRed,
                    enabled: canCheckOut,
                    onTap: canCheckOut ? doPunchOut : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionTile(
                  title: 'Punch In',
                  subtitle: 'Tap to mark attendance',
                  icon: Icons.fingerprint_rounded,
                  bg: HomeDashColors.accentGreen,
                  fg: Colors.white,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                  ),
                  keepBrandColorsWhenDisabled: true,
                  enabled: canCheckIn,
                  onTap: canCheckIn ? doPunchIn : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionTile(
                  title: 'Punch Out',
                  subtitle: 'Tap to end shift',
                  icon: Icons.power_settings_new_rounded,
                  bg: HomeDashColors.accentRed,
                  fg: Colors.white,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                  ),
                  keepBrandColorsWhenDisabled: true,
                  enabled: canCheckOut,
                  onTap: canCheckOut ? doPunchOut : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openRemoteDialog(context),
              child: Ink(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.wifi_tethering_rounded,
                      color: HomeDashColors.accentBlue,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        hasOpenSession
                            ? 'Work remotely (remote check-out)'
                            : 'Work remotely (remote check-in)',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: HomeDashColors.title,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: HomeDashColors.muted.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isRemoteMode)
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HomeDashColors.softPurple,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                hasOpenSession
                    ? 'Remote check-out enabled'
                    : 'Remote check-in enabled',
                style: const TextStyle(
                  color: HomeDashColors.accentPurple,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openRemoteDialog(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final ctrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: isIOS,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: isIOS,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(isIOS ? 14 : 24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isIOS)
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  const Text(
                    'Remote Mode',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: ctrl,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Enter reason...',
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final reason = ctrl.text.trim();
                            if (reason.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a reason'),
                                ),
                              );
                              return;
                            }
                            onEnableRemoteMode(reason);
                            Navigator.pop(context);
                          },
                          child: const Text('Enable Remote Mode'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? detail;
  final IconData icon;
  final Color bg;
  final Color fg;
  final Gradient? gradient;
  final bool enabled;
  final bool keepBrandColorsWhenDisabled;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.title,
    required this.subtitle,
    this.detail,
    required this.icon,
    required this.bg,
    required this.fg,
    this.gradient,
    this.keepBrandColorsWhenDisabled = false,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final keepBrand = keepBrandColorsWhenDisabled || enabled;
    final effectiveBg = keepBrand ? bg : const Color(0xFFF1F5F9);
    final effectiveFg = keepBrand ? fg : HomeDashColors.muted;
    final effectiveGradient = keepBrand ? gradient : null;

    return Opacity(
      opacity: enabled ? 1 : (keepBrandColorsWhenDisabled ? 0.55 : 0.65),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: effectiveGradient == null ? effectiveBg : null,
              gradient: effectiveGradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: HomeDashColors.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: effectiveFg, size: 24),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: effectiveFg,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: detail != null ? 15 : 11,
                    fontWeight: detail != null
                        ? FontWeight.w800
                        : FontWeight.w500,
                    color: effectiveFg.withValues(
                      alpha: detail != null ? 0.95 : 0.8,
                    ),
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: effectiveFg.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PunchTimes {
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int workedMinutes;

  const _PunchTimes({
    required this.checkIn,
    required this.checkOut,
    required this.workedMinutes,
  });
}

_PunchTimes _todayPunchTimes(List<AttendanceSession> sessions) {
  final today = todaySessions(sessions);
  if (today.isEmpty) {
    return const _PunchTimes(checkIn: null, checkOut: null, workedMinutes: 0);
  }

  DateTime? firstIn;
  DateTime? lastOut;
  var worked = 0;

  for (final s in today) {
    final inAt = s.checkInTime.toLocal();
    if (firstIn == null || inAt.isBefore(firstIn)) firstIn = inAt;

    final outAt = s.checkOutTime?.toLocal();
    if (outAt != null && (lastOut == null || outAt.isAfter(lastOut))) {
      lastOut = outAt;
    }

    worked += sessionWorkedMinutes(s);
  }

  return _PunchTimes(
    checkIn: firstIn,
    checkOut: lastOut,
    workedMinutes: worked,
  );
}

String _fmtTime(DateTime dt) => DateFormat('h:mm a').format(dt.toLocal());

String _fmtDuration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h <= 0) return '${m}m';
  if (m <= 0) return '${h}h';
  return '${h}h ${m}m';
}
