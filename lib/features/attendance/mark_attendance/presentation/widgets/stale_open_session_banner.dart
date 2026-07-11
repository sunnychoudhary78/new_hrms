import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:lms/features/attendance/mark_attendance/data/models/attendance_session_model.dart';

/// Shown when an open session exists from a previous calendar day.
class StaleOpenSessionBanner extends StatelessWidget {
  final AttendanceSession openSession;

  const StaleOpenSessionBanner({super.key, required this.openSession});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final dateLabel = DateFormat('EEE, MMM dd').format(
      openSession.checkInTime.toLocal(),
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withOpacity(0.6),
        borderRadius: BorderRadius.circular(isIOS ? 10 : 12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: scheme.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Open session from $dateLabel — please check out to continue.',
              style: TextStyle(
                fontSize: 13,
                color: scheme.onTertiaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
