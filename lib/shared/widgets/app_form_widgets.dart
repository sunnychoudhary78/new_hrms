import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lms/core/theme/app_design.dart';

EdgeInsets get appScreenPadding => const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.lg,
    );

class AppSectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final bool highlighted;

  const AppSectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.margin,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final radius = isIOS ? AppRadius.md + 2 : AppRadius.lg;

    return Container(
      width: double.infinity,
      margin: margin ?? const EdgeInsets.only(bottom: AppSpacing.sm + 4),
      padding: padding,
      decoration: AppColors.cardDecoration(
        radius: radius,
        highlighted: highlighted,
      ),
      child: child,
    );
  }
}

class AppIconBadge extends StatelessWidget {
  final IconData icon;
  final Color? backgroundColor;
  final Color? iconColor;
  final double size;

  const AppIconBadge({
    super.key,
    required this.icon,
    this.backgroundColor,
    this.iconColor,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? primary,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(
        icon,
        color: iconColor ?? Colors.white,
        size: size * 0.45,
      ),
    );
  }
}

class AppHeroBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? title;
  final Widget? trailing;

  const AppHeroBanner({
    super.key,
    required this.icon,
    required this.message,
    this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final radius = isIOS ? AppRadius.md + 2 : AppRadius.lg - 2;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: AppColors.softHeroGradient,
        border: Border.all(color: scheme.outline.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIconBadge(icon: icon, size: 42),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  message,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class AppStatusPill extends StatelessWidget {
  final String label;

  const AppStatusPill({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.statusColor(label);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: isDark ? color : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.0 : 0.35),
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: isDark ? Colors.white : color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

InputDecoration appInputDecoration({
  required String labelText,
  IconData? prefixIcon,
  String? prefixText,
  String? hintText,
  double radius = AppRadius.md,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(radius),
    borderSide: BorderSide(color: AppColors.border),
  );

  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    prefixIcon: prefixIcon != null
        ? Icon(prefixIcon, color: AppColors.muted, size: 22)
        : null,
    prefixText: prefixText,
    filled: true,
    fillColor: AppColors.softFill,
    labelStyle: TextStyle(
      color: AppColors.muted,
      fontWeight: FontWeight.w500,
    ),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(color: AppColors.primary, width: 1.5),
    ),
  );
}

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          disabledBackgroundColor: primary.withValues(alpha: 0.45),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          elevation: 0,
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: onPrimary,
                ),
              )
            : icon != null
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  )
                : Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
      ),
    );
  }
}

class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        onPressed: onPressed,
        child: icon != null
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              )
            : Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}

class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      labelStyle: TextStyle(
        color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      selectedColor: scheme.primary,
      backgroundColor: AppColors.softFill,
      side: BorderSide(
        color: selected ? scheme.primary : scheme.outline,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      showCheckmark: false,
    );
  }
}

class AppSectionTitle extends StatelessWidget {
  final String text;

  const AppSectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          text,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }
}
