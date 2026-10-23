import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:lms/core/theme/app_design.dart';
import 'package:lms/shared/widgets/app_bar.dart';
import 'package:lms/shared/widgets/app_form_widgets.dart';
import '../../../../core/theme/app_theme_provider.dart';
import '../../../../core/theme/theme_mode_provider.dart';

class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedColor = ref.watch(appThemeProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    final isDark = themeMode == ThemeMode.dark;

    final presetColors = [
      Colors.indigo,
      Colors.blue,
      Colors.teal,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.purple,
      Colors.pink,
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const AppAppBar(title: "Theme Settings"),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: isIOS
            ? const BouncingScrollPhysics()
            : const ClampingScrollPhysics(),
        padding: appScreenPadding,
        children: [
          AppSectionCard(
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSectionTitle("Appearance"),
                SizedBox(height: AppSpacing.md),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.softFill,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: AppColors.border),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      _ModeButton(
                        label: "Light",
                        icon: Icons.light_mode,
                        selected: !isDark,
                        onTap: () => ref
                            .read(themeModeProvider.notifier)
                            .changeMode(ThemeMode.light),
                      ),
                      _ModeButton(
                        label: "Dark",
                        icon: Icons.dark_mode,
                        selected: isDark,
                        onTap: () => ref
                            .read(themeModeProvider.notifier)
                            .changeMode(ThemeMode.dark),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSectionCard(
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSectionTitle("Primary Color"),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: presetColors.map((color) {
                    final isSelected = selectedColor.value == color.value;

                    return GestureDetector(
                      onTap: () {
                        ref.read(appThemeProvider.notifier).changeColor(color);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: AppColors.title, width: 3)
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.5),
                                    blurRadius: isIOS ? 8 : 12,
                                  ),
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppSecondaryButton(
                  label: "Pick Custom Color",
                  icon: Icons.palette,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) {
                        Color tempColor = selectedColor;

                        return AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              isIOS ? 14 : AppRadius.lg,
                            ),
                          ),
                          title: const Text("Select Color"),
                          content: SingleChildScrollView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            physics: isIOS
                                ? const BouncingScrollPhysics()
                                : const ClampingScrollPhysics(),
                            child: ColorPicker(
                              pickerColor: selectedColor,
                              onColorChanged: (color) {
                                tempColor = color;
                              },
                              enableAlpha: false,
                              displayThumbColor: true,
                              pickerAreaHeightPercent: 0.8,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text("Cancel"),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md),
                                ),
                              ),
                              onPressed: () {
                                ref
                                    .read(appThemeProvider.notifier)
                                    .changeColor(tempColor);
                                Navigator.pop(context);
                              },
                              child: const Text("Select"),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSectionCard(
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSectionTitle("Reset"),
                const SizedBox(height: AppSpacing.md),
                AppSecondaryButton(
                  label: "Reset to Defaults",
                  icon: Icons.restart_alt,
                  onPressed: () {
                    ref.read(appThemeProvider.notifier).resetColor();
                    ref.read(themeModeProvider.notifier).resetMode();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Theme reset to default"),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? scheme.onPrimary : scheme.onSurface,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected ? scheme.onPrimary : scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
