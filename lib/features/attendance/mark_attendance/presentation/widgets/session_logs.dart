import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/attendance_session_model.dart';

class SessionLogs extends StatelessWidget {
  final List<AttendanceSession> sessions;

  const SessionLogs({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final cardRadius = BorderRadius.circular(isIOS ? 14 : 20);

    if (sessions.isEmpty) {
      return Center(
        child: Text(
          "No sessions yet",
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      );
    }

    return Column(
      children: sessions.map((s) {
        final bool isOngoing = s.checkOutTime == null;

        final DateTime inTime = s.checkInTime.toLocal();
        final DateTime? outTime = s.checkOutTime?.toLocal();

        final String dateLabel = DateFormat('EEE, MMM dd yyyy').format(inTime);

        final String punchInLabel = DateFormat('hh:mm a').format(inTime);

        final String punchOutLabel = isOngoing
            ? 'Now'
            : DateFormat('hh:mm a').format(outTime!);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: cardRadius,
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: isOngoing
                    ? scheme.primary.withOpacity(.1)
                    : scheme.surfaceContainerHigh,
                child: Icon(
                  isOngoing ? Icons.timer_outlined : Icons.check_circle_outline,
                  color: isOngoing ? scheme.primary : scheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isOngoing ? "Ongoing Session" : "Completed Session",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "In: $punchInLabel  •  Out: $punchOutLabel",
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isOngoing)
                Text(
                  _calculateDiff(inTime, outTime),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: scheme.tertiary,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _calculateDiff(DateTime start, DateTime? end) {
    if (end == null) return "";
    final diff = end.difference(start);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    return "${hours}h ${minutes}m";
  }
}
