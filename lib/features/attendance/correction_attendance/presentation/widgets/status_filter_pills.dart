import 'package:flutter/foundation.dart';
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

  Color _pillAccent(String status) {
    switch (status) {
      case 'APPROVED':
        return AppColors.success;
      case 'REJECTED':
        return AppColors.danger;
      case 'PENDING':
        return AppColors.warning;
      default:
        return AppColors.heroStart;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: isIOS
            ? const BouncingScrollPhysics()
            : const ClampingScrollPhysics(),
        itemCount: statuses.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final s = statuses[index];
          final active = s == selected;
          final accent = _pillAccent(s);

          return InkWell(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            onTap: () => onChanged(s),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              decoration: BoxDecoration(
                color: active ? accent : scheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: active
                      ? accent
                      : scheme.outline.withValues(alpha: 0.55),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                s,
                style: TextStyle(
                  color: active ? Colors.white : scheme.onSurfaceVariant,
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
