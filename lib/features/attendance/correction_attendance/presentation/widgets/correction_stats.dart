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
        _StatCard(
          label: "Pending Corrections",
          value: pendingCorrections.toString(),
          color: scheme.tertiary,
        ),

        const SizedBox(width: AppSpacing.sm),

        _StatCard(
          label: "Pending Remote",
          value: pendingRemote.toString(),
          color: scheme.primary,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: scheme.outline.withOpacity(.2)),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withOpacity(.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
