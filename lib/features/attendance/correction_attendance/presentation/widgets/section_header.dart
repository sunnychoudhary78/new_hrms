import 'package:flutter/material.dart';
import 'package:lms/core/theme/app_design.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const SectionHeader({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 16, color: scheme.onSurfaceVariant),

        const SizedBox(width: AppSpacing.xs),

        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: scheme.onSurfaceVariant,
          ),
        ),

        const SizedBox(width: AppSpacing.sm),

        Expanded(child: Divider(color: scheme.outlineVariant, thickness: 1)),
      ],
    );
  }
}
