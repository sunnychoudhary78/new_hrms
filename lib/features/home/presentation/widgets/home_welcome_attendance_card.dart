import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:lms/features/attendance/mark_attendance/presentation/providers/attendance_selectors.dart';
import 'package:lms/features/attendance/mark_attendance/presentation/providers/mark_attendance_provider.dart';
import 'package:lms/features/attendance/mark_attendance/presentation/providers/mobile_config_provider.dart';

class HomeWelcomeAttendanceCard extends ConsumerStatefulWidget {
  final String name;
  final String role;
  final String? imageUrl;

  const HomeWelcomeAttendanceCard({
    super.key,
    required this.name,
    required this.role,
    this.imageUrl,
  });

  @override
  ConsumerState<HomeWelcomeAttendanceCard> createState() =>
      _HomeWelcomeAttendanceCardState();
}

class _HomeWelcomeAttendanceCardState
    extends ConsumerState<HomeWelcomeAttendanceCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shineController;

  @override
  void initState() {
    super.initState();

    /// Shine animation runs ONLY once
    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _shineController.forward();
      }
    });
  }

  Widget _buildDisabledButton(ColorScheme scheme, String text) {
    return FilledButton.icon(
      onPressed: null,

      icon: const Icon(Icons.fingerprint),

      label: Text(text),

      style: FilledButton.styleFrom(
        backgroundColor: scheme.outlineVariant,
        foregroundColor: scheme.onSurfaceVariant,
      ),
    );
  }

  @override
  void dispose() {
    _shineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final attendanceAsync = ref.watch(markAttendanceProvider);

    final mobileConfigAsync = ref.watch(mobileConfigProvider);

    final canMobileCheckIn = ref.watch(canMobileCheckInProvider);

    final canMobileCheckOut = ref.watch(canMobileCheckOutProvider);

    final greeting = _greeting();

    return AnimatedBuilder(
          animation: _shineController,

          builder: (context, child) {
            final floatOffset =
                4 *
                (0.5 -
                    Curves.easeInOut.transform(
                      _shineController.value.clamp(0, 1),
                    ));

            return Transform.translate(
              offset: Offset(0, floatOffset),

              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),

                child: Stack(
                  children: [
                    /// GLASS BASE
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),

                      child: Container(
                        padding: const EdgeInsets.all(20),

                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),

                          color: scheme.surface.withOpacity(0.55),

                          border: Border.all(
                            color: scheme.outline.withOpacity(0.2),
                            width: 1.2,
                          ),

                          boxShadow: [
                            BoxShadow(
                              color: scheme.shadow.withOpacity(0.15),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),

                        child: attendanceAsync.when(
                          loading: () => const SizedBox(height: 130),

                          error: (_, __) => const SizedBox(height: 130),

                          data: (sessions) {
                            final activeSession = ref.watch(
                              activeSessionProvider(sessions),
                            );

                            final isCheckedIn =
                                activeSession != null &&
                                activeSession.checkOutTime == null;

                            /// Backend permission check
                            final canPunchIn = !isCheckedIn && canMobileCheckIn;

                            final canPunchOut =
                                isCheckedIn && canMobileCheckOut;

                            final statusBg = isCheckedIn
                                ? scheme.tertiaryContainer
                                : scheme.secondaryContainer;

                            final statusFg = isCheckedIn
                                ? scheme.onTertiaryContainer
                                : scheme.onSecondaryContainer;

                            final buttonBg =
                                (isCheckedIn && canMobileCheckOut) ||
                                    (!isCheckedIn && canMobileCheckIn)
                                ? scheme.error
                                : scheme.outlineVariant;

                            final buttonFg =
                                (isCheckedIn && canMobileCheckOut) ||
                                    (!isCheckedIn && canMobileCheckIn)
                                ? scheme.onError
                                : scheme.onSurfaceVariant;

                            final buttonText = isCheckedIn
                                ? (canMobileCheckOut
                                      ? "Punch Out"
                                      : "Check-Out Disabled")
                                : (canMobileCheckIn
                                      ? "Punch In"
                                      : "Check-In Disabled");

                            final buttonEnabled = isCheckedIn
                                ? canPunchOut
                                : canPunchIn;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,

                              children: [
                                /// HEADER
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            greeting,
                                            style: TextStyle(
                                              color: scheme.onSurfaceVariant,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),

                                          const SizedBox(height: 6),

                                          Text(
                                            widget.name,
                                            style: TextStyle(
                                              color: scheme.onSurface,
                                              fontSize: 22,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),

                                          const SizedBox(height: 2),

                                          Text(
                                            widget.role,
                                            style: TextStyle(
                                              color: scheme.onSurfaceVariant,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    _Avatar(
                                      name: widget.name,
                                      imageUrl: widget.imageUrl,
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 20),

                                /// STATUS + BUTTON
                                Row(
                                  children: [
                                    _StatusChip(
                                      text: isCheckedIn
                                          ? "Checked in"
                                          : "Not checked in",
                                      bg: statusBg,
                                      fg: statusFg,
                                    ),

                                    const Spacer(),

                                    mobileConfigAsync.when(
                                      loading: () => _buildDisabledButton(
                                        scheme,
                                        "Checking...",
                                      ),

                                      error: (_, __) => _buildDisabledButton(
                                        scheme,
                                        "Unavailable",
                                      ),

                                      data: (_) => FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: buttonBg,
                                          foregroundColor: buttonFg,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 18,
                                            vertical: 10,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              30,
                                            ),
                                          ),
                                        ),

                                        icon: Icon(
                                          isCheckedIn
                                              ? Icons.logout_rounded
                                              : Icons.fingerprint,
                                          size: 18,
                                        ),

                                        label: Text(buttonText),

                                        onPressed: buttonEnabled
                                            ? () async {
                                                if (isCheckedIn) {
                                                  await ref
                                                      .read(
                                                        markAttendanceProvider
                                                            .notifier,
                                                      )
                                                      .punchOut(context);
                                                } else {
                                                  await ref
                                                      .read(
                                                        markAttendanceProvider
                                                            .notifier,
                                                      )
                                                      .punchIn(context);
                                                }
                                              }
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),

                                if (isCheckedIn)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Text(
                                      "Checked in at ${_fmt(activeSession.checkInTime)}",
                                      style: TextStyle(
                                        color: scheme.onSurfaceVariant,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),

                    /// SHINE EFFECT (unchanged)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: _shineController.isCompleted ? 0 : 1,
                          child: Transform.translate(
                            offset: Offset(
                              350 * _shineController.value - 175,
                              0,
                            ),
                            child: Container(
                              width: 120,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withOpacity(.25),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        )
        .animate()
        .fadeIn(duration: 600.ms)
        .scale(begin: const Offset(.96, .96), end: const Offset(1, 1));
  }

  static String _fmt(DateTime t) => DateFormat('hh:mm a').format(t.toLocal());

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good morning";
    if (hour < 17) return "Good afternoon";
    return "Good evening";
  }
}

class _StatusChip extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;

  const _StatusChip({required this.text, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? imageUrl;

  const _Avatar({required this.name, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return CircleAvatar(
      radius: 28,
      backgroundColor: scheme.surface.withOpacity(.6),
      backgroundImage: imageUrl != null && imageUrl!.isNotEmpty
          ? NetworkImage(imageUrl!)
          : null,
      child: imageUrl == null || imageUrl!.isEmpty
          ? Text(
              _initials(name),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: scheme.primary,
                fontSize: 16,
              ),
            )
          : null,
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
