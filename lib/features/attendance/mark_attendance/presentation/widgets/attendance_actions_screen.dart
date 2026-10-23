import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:lms/features/attendance/mark_attendance/data/models/attendance_session_model.dart';
import 'package:lms/features/attendance/mark_attendance/presentation/providers/mark_attendance_provider.dart';
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
    final sessions = ref.watch(markAttendanceProvider).value?.sessions ?? [];
    final times = _todayPunchTimes(sessions);
    final checkInLabel =
        times.checkIn != null ? _fmtTime(times.checkIn!) : '--:--';
    final checkOutLabel = hasOpenSession
        ? 'In progress'
        : (times.checkOut != null ? _fmtTime(times.checkOut!) : '--:--');
    final workedLabel =
        times.workedMinutes > 0 ? _fmtDuration(times.workedMinutes) : null;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: KeyedSubtree(
                key: punchInKey,
                child: _TimeInfoCard(
                  title: 'Check In',
                  time: checkInLabel,
                  detail: times.checkIn != null
                      ? (workedLabel != null
                          ? 'Worked $workedLabel'
                          : 'Today')
                      : 'Not yet',
                  icon: Icons.login_rounded,
                  accent: HomeDashColors.accentGreen,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: KeyedSubtree(
                key: punchOutKey,
                child: _TimeInfoCard(
                  title: 'Check Out',
                  time: checkOutLabel,
                  detail: hasOpenSession
                      ? 'Session open'
                      : (times.checkOut != null ? 'Today' : 'Not yet'),
                  icon: Icons.logout_rounded,
                  accent: HomeDashColors.accentRed,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openRemoteDialog(context),
            child: Ink(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: HomeDashColors.of(context).card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.45),
                ),
                boxShadow: HomeDashColors.of(context).cardShadow,
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      Icons.wifi_tethering_rounded,
                      size: 20,
                      color: HomeDashColors.of(context).muted,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      hasOpenSession
                          ? 'Work remotely (check-out)'
                          : 'Work remotely (check-in)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: HomeDashColors.of(context).title,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: HomeDashColors.of(context)
                        .muted
                        .withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isRemoteMode)
          Builder(
            builder: (context) {
              final dash = HomeDashColors.of(context);
              return Container(
                margin: const EdgeInsets.only(top: 10),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: dash.softBlue,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: dash.accentBlue.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  hasOpenSession
                      ? 'Remote check-out enabled'
                      : 'Remote check-in enabled',
                  style: TextStyle(
                    color: dash.accentBlue,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              );
            },
          ),
      ],
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

class _TimeInfoCard extends StatelessWidget {
  final String title;
  final String time;
  final String detail;
  final IconData icon;
  final Color accent;

  const _TimeInfoCard({
    required this.title,
    required this.time,
    required this.detail,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final dash = HomeDashColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dash.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.45)),
        boxShadow: dash.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: dash.muted),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: dash.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: dash.title,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: dash.muted,
            ),
          ),
        ],
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
