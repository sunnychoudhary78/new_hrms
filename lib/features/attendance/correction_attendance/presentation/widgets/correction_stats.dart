import 'package:flutter/material.dart';
import 'package:lms/core/theme/app_design.dart';
import '../../data/models/attendance_request_model.dart';

class CorrectionStats extends StatelessWidget {
  final List<AttendanceRequest> requests;

  const CorrectionStats({super.key, required this.requests});

  @override
  Widget build(BuildContext context) {
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
            accent: AppColors.warning,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCard(
            label: "Remote",
            value: pendingRemote.toString(),
            icon: Icons.home_work_rounded,
            accent: AppColors.heroStart,
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
  final Color accent;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppColors.cardDecoration(radius: AppRadius.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, size: 16, color: accent),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: accent,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
