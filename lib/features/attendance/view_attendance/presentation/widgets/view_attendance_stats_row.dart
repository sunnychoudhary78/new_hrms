import 'package:flutter/material.dart';
import 'package:lms/features/home/presentation/widgets/home_dashboard_style.dart';

class ViewAttendanceStatsRow extends StatelessWidget {
  final num workingDays;
  final int daysInMonth;
  final VoidCallback? onRequestCorrection;

  const ViewAttendanceStatsRow({
    super.key,
    required this.workingDays,
    required this.daysInMonth,
    this.onRequestCorrection,
  });

  @override
  Widget build(BuildContext context) {
    final worked = workingDays.toDouble();
    final total = daysInMonth <= 0 ? 1 : daysInMonth.toDouble();
    final progress = (worked / total).clamp(0.0, 1.0);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Working Days',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_fmt(workingDays)} / $daysInMonth',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${(progress * 100).round()}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onRequestCorrection,
                borderRadius: BorderRadius.circular(20),
                child: Ink(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                    boxShadow: HomeDashColors.cardShadow,
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
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.description_outlined,
                              size: 18,
                              color: HomeDashColors.accentBlue,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: HomeDashColors.muted.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Text(
                        'Request\nCorrection',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: HomeDashColors.title,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Fix attendance errors',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: HomeDashColors.muted.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(num value) =>
      value == value.truncateToDouble() ? value.toInt().toString() : '$value';
}
