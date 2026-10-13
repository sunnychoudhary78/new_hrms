import 'package:flutter/material.dart';
import 'package:lms/features/attendance/mark_attendance/data/models/effective_shift_model.dart';
import 'package:lms/features/home/presentation/widgets/home_dashboard_style.dart';

class LiveClockCard extends StatelessWidget {
  final String workingTime;
  final double progress;
  final EffectiveShift? shift;
  final bool isCheckedIn;

  const LiveClockCard({
    super.key,
    required this.workingTime,
    required this.progress,
    required this.shift,
    required this.isCheckedIn,
  });

  @override
  Widget build(BuildContext context) {
    final lunch = shift?.lunchDisplay;
    final shiftLabel = shift?.startSubtitle.isNotEmpty == true
        ? shift!.startSubtitle
        : (shift?.modeLabel ?? 'Shift');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: HomeDashColors.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _ShiftChip(
                  icon: Icons.apartment_rounded,
                  label: 'Office Start',
                  value: shift?.officeStartDisplay ?? '--:--',
                  color: HomeDashColors.accentBlue,
                  bg: HomeDashColors.softBlue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ShiftChip(
                  icon: Icons.restaurant_rounded,
                  label: 'Lunch Break',
                  value: lunch ?? '--',
                  color: HomeDashColors.accentOrange,
                  bg: HomeDashColors.softOrange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ShiftChip(
                  icon: Icons.home_rounded,
                  label: 'Office End',
                  value: shift?.officeEndDisplay ?? '--:--',
                  color: HomeDashColors.accentPurple,
                  bg: HomeDashColors.softPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: HomeDashColors.softBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.sync_rounded,
                  size: 16,
                  color: HomeDashColors.accentBlue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  shiftLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: HomeDashColors.title,
                  ),
                ),
              ),
              if (isCheckedIn) ...[
                Text(
                  workingTime,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: HomeDashColors.accentGreen,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: HomeDashColors.muted,
                  ),
                ),
              ],
            ],
          ),
          if (isCheckedIn) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 7,
                backgroundColor: const Color(0xFFE2E8F0),
                color: HomeDashColors.accentPurple,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShiftChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color bg;

  const _ShiftChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: HomeDashColors.muted.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}
