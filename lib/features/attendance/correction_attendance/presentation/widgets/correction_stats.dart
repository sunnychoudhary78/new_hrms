import 'package:flutter/material.dart';
import 'package:lms/core/theme/app_design.dart';
import '../../data/models/attendance_request_model.dart';

class CorrectionStats extends StatelessWidget {
  final List<AttendanceRequest> requests;

  const CorrectionStats({super.key, required this.requests});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final pendingCorrections = requests
        .where((e) => e.isCorrection && e.isPending)
        .length;

    final pendingRemote = requests
        .where((e) => e.isRemote && e.isPending)
        .length;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: "Corrections",
            value: pendingCorrections.toString(),
            icon: Icons.access_time_rounded,
            baseColor: Colors.amber,
            bgColor: scheme.tertiaryContainer,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCard(
            label: "Remote",
            value: pendingRemote.toString(),
            icon: Icons.home_work_rounded,
            baseColor: Colors.blue,
            bgColor: scheme.primaryContainer,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color baseColor;
  final Color bgColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.baseColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outline.withOpacity(.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// TOP ROW (ICON + LABEL)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: baseColor.withOpacity(.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: baseColor),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          /// VALUE
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: baseColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
