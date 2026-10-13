import 'package:flutter/material.dart';
import 'package:lms/core/theme/app_design.dart';
import 'package:lms/shared/widgets/app_form_widgets.dart';

class ProfileDetailsCard extends StatelessWidget {
  final List<(String title, String value, IconData icon)> details;

  const ProfileDetailsCard({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        decoration: AppColors.cardDecoration(radius: AppRadius.lg),
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm + 4,
          horizontal: AppSpacing.xs,
        ),
        child: Column(
          children: details.map((d) {
            return ListTile(
              leading: AppIconBadge(
                icon: d.$3,
                size: 40,
                backgroundColor: AppColors.softBlueStart,
                iconColor: AppColors.primary,
              ),
              title: Text(
                d.$1,
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              subtitle: Text(
                d.$2,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.title,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
