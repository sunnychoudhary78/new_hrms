import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lms/features/attendance/mark_attendance/presentation/providers/mark_attendance_provider.dart';
import 'package:lms/features/attendance/mark_attendance/presentation/providers/mobile_config_provider.dart';

import '../widgets/modern_punch_button.dart';

class AttendanceActionsSection extends ConsumerWidget {
  final DateTime? punchInTime;
  final DateTime? punchOutTime;

  final bool isRemoteMode;
  final String? remoteReason;

  final Function(String reason) onEnableRemoteMode;
  final VoidCallback onResetRemoteMode;

  const AttendanceActionsSection({
    super.key,
    required this.punchInTime,
    required this.punchOutTime,
    required this.isRemoteMode,
    required this.remoteReason,
    required this.onEnableRemoteMode,
    required this.onResetRemoteMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    final notifier = ref.read(markAttendanceProvider.notifier);

    /// Watch backend config
    final mobileConfigAsync = ref.watch(mobileConfigProvider);

    final canMobileCheckIn = ref.watch(canMobileCheckInProvider);
    final canMobileCheckOut = ref.watch(canMobileCheckOutProvider);

    /// Combine backend + session state
    final canCheckIn = punchInTime == null && canMobileCheckIn;

    final canCheckOut =
        punchInTime != null && punchOutTime == null && canMobileCheckOut;

    return Column(
      children: [
        /// BUTTON ROW
        Row(
          children: [
            /// PUNCH IN BUTTON
            Expanded(
              child: mobileConfigAsync.when(
                /// LOADING STATE
                loading: () => ModernPunchButton(
                  text: "Checking...",
                  icon: Icons.fingerprint,
                  onPressed: null,
                  colors: [
                    scheme.outlineVariant,
                    scheme.surfaceContainerHighest,
                  ],
                ),

                /// ERROR STATE
                error: (_, __) => ModernPunchButton(
                  text: "Unavailable",
                  icon: Icons.fingerprint,
                  onPressed: null,
                  colors: [
                    scheme.outlineVariant,
                    scheme.surfaceContainerHighest,
                  ],
                ),

                /// DATA STATE
                data: (_) => ModernPunchButton(
                  text: canMobileCheckIn ? "Punch In" : "Check-In Disabled",

                  icon: Icons.fingerprint,

                  onPressed: canCheckIn
                      ? () async {
                          if (isRemoteMode && remoteReason != null) {
                            await notifier.punchInRemote(
                              context,
                              remoteReason!,
                            );

                            onResetRemoteMode();
                          } else {
                            await notifier.punchIn(context);
                          }
                        }
                      : null,

                  colors: canMobileCheckIn
                      ? [scheme.primary, scheme.primaryContainer]
                      : [scheme.outlineVariant, scheme.surfaceContainerHighest],
                ),
              ),
            ),

            const SizedBox(width: 16),

            /// PUNCH OUT BUTTON
            Expanded(
              child: mobileConfigAsync.when(
                loading: () => ModernPunchButton(
                  text: "Checking...",
                  icon: Icons.power_settings_new_rounded,
                  onPressed: null,
                  colors: [
                    scheme.outlineVariant,
                    scheme.surfaceContainerHighest,
                  ],
                ),

                error: (_, __) => ModernPunchButton(
                  text: "Unavailable",
                  icon: Icons.power_settings_new_rounded,
                  onPressed: null,
                  colors: [
                    scheme.outlineVariant,
                    scheme.surfaceContainerHighest,
                  ],
                ),

                data: (_) => ModernPunchButton(
                  text: canMobileCheckOut ? "Punch Out" : "Check-Out Disabled",

                  icon: Icons.power_settings_new_rounded,

                  onPressed: canCheckOut
                      ? () async {
                          if (isRemoteMode && remoteReason != null) {
                            await notifier.punchOutRemote(
                              context,
                              remoteReason!,
                            );

                            onResetRemoteMode();
                          } else {
                            await notifier.punchOut(context);
                          }
                        }
                      : null,

                  colors: canMobileCheckOut
                      ? [scheme.secondary, scheme.secondaryContainer]
                      : [scheme.outlineVariant, scheme.surfaceContainerHighest],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        /// REMOTE OPTION
        if (punchOutTime == null)
          TextButton.icon(
            onPressed: () => _openRemoteDialog(context),

            icon: Icon(Icons.wifi_tethering_rounded, color: scheme.primary),

            label: Text(
              punchInTime == null
                  ? "Work remotely (remote check-in)"
                  : "Work remotely (remote check-out)",
            ),
          ),

        /// REMOTE ACTIVE INDICATOR
        if (isRemoteMode)
          Container(
            margin: const EdgeInsets.only(top: 12),

            padding: const EdgeInsets.all(12),

            decoration: BoxDecoration(
              color: scheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),

            child: Text(
              punchInTime == null
                  ? "Remote check-in enabled"
                  : "Remote check-out enabled",

              style: TextStyle(
                color: scheme.onTertiaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  /// REMOTE DIALOG
  Future<void> _openRemoteDialog(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;

    final ctrl = TextEditingController();

    await showModalBottomSheet(
      context: context,

      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,

      backgroundColor: Colors.transparent,

      builder: (context) {
        return SafeArea(
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 200),

            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),

            child: Container(
              padding: const EdgeInsets.all(20),

              decoration: BoxDecoration(
                color: scheme.surface,

                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),

              child: Column(
                mainAxisSize: MainAxisSize.min,

                children: [
                  Text(
                    "Remote Mode",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 20),

                  TextField(
                    controller: ctrl,

                    maxLines: 4,

                    decoration: InputDecoration(
                      hintText: "Enter reason...",
                      filled: true,

                      fillColor: scheme.surfaceContainerHighest,

                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),

                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),

                          child: const Text("Cancel"),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final reason = ctrl.text.trim();

                            if (reason.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Please enter a reason"),
                                ),
                              );

                              return;
                            }

                            onEnableRemoteMode(reason);

                            Navigator.pop(context);
                          },

                          child: const Text("Enable Remote Mode"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
