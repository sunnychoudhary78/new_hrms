import 'package:flutter/material.dart';
import 'package:lms/core/theme/app_design.dart';

class StatusFilterPills extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const StatusFilterPills({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  static const statuses = ['PENDING', 'APPROVED', 'REJECTED', 'ALL'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: statuses.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final s = statuses[index];
          final active = s == selected;

          return InkWell(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            onTap: () => onChanged(s),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              decoration: BoxDecoration(
                color: active ? scheme.primary : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: active ? scheme.primary : scheme.outlineVariant,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                s,
                style: TextStyle(
                  color: active ? scheme.onPrimary : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
