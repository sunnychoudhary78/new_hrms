import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:lms/shared/widgets/app_bar.dart';
import '../../../../core/theme/app_theme_provider.dart';
import '../../../../core/theme/theme_mode_provider.dart';

class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedColor = ref.watch(appThemeProvider);
    final themeMode = ref.watch(themeModeProvider);
    final scheme = Theme.of(context).colorScheme;
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
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppAppBar(title: "Theme Settings"),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: isIOS
            ? const BouncingScrollPhysics()
            : const ClampingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          /// 🌗 THEME MODE SECTION
          _SectionCard(
            title: "Appearance",
            isIOS: isIOS,
            child: Column(
              children: [
                const SizedBox(height: 10),

                /// Segmented Light/Dark Toggle
                Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(isIOS ? 22 : 30),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      _ModeButton(
                        label: "Light",
                        icon: Icons.light_mode,
                        selected: !isDark,
                        isIOS: isIOS,
                        onTap: () => ref
                            .read(themeModeProvider.notifier)
                            .changeMode(ThemeMode.light),
                      ),
                      _ModeButton(
                        label: "Dark",
                        icon: Icons.dark_mode,
                        selected: isDark,
                        isIOS: isIOS,
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

          const SizedBox(height: 30),

          /// 🎨 COLOR SECTION
          _SectionCard(
            title: "Primary Color",
            isIOS: isIOS,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),

                /// Preset colors
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
                              ? Border.all(color: scheme.onSurface, width: 3)
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

                const SizedBox(height: 24),

                /// 🌈 Advanced Picker Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(isIOS ? 12 : 20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(Icons.palette),
                  label: const Text("Pick Custom Color"),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) {
                        Color tempColor = selectedColor;

                        return AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              isIOS ? 14 : 24,
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
                              child: const Text("Cancel"),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    isIOS ? 12 : 20,
                                  ),
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
          const SizedBox(height: 30),

          /// RESET BUTTON
          _SectionCard(
            title: "Reset",
            isIOS: isIOS,
            child: Column(
              children: [
                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(isIOS ? 12 : 20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    icon: const Icon(Icons.restart_alt),
                    label: const Text("Reset to Defaults"),
                    onPressed: () {
                      ref.read(appThemeProvider.notifier).resetColor();
                      ref.read(themeModeProvider.notifier).resetMode();

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Theme reset to default")),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final bool isIOS;

  const _SectionCard({
    required this.title,
    required this.child,
    required this.isIOS,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(isIOS ? 14 : 20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool isIOS;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.isIOS,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final innerRadius = BorderRadius.circular(isIOS ? 18 : 26);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : Colors.transparent,
            borderRadius: innerRadius,
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
