import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/providers/global_loading_provider.dart';
import 'package:lms/features/home/presentation/widgets/app_drawer.dart';
import 'package:lms/shared/widgets/app_bar.dart';
import 'package:lms/shared/widgets/global_error.dart';
import 'package:lms/shared/widgets/global_loader.dart';
import 'package:lms/shared/widgets/global_sucess.dart';

import '../providers/leave_apply_provider.dart';
import '../providers/leave_balance_provider.dart';

import '../widgets/leave_type_dropdown.dart';
import '../widgets/date_range_picker.dart';
import '../widgets/reason_input.dart';
import '../widgets/submit_button.dart';

import '../../data/models/leave_balance_model.dart';

enum DayType { full, half }

enum HalfDayPart { am, pm }

class LeaveApplyScreen extends ConsumerStatefulWidget {
  final LeaveBalance? initialLeave;
  const LeaveApplyScreen({super.key, this.initialLeave});

  @override
  ConsumerState<LeaveApplyScreen> createState() => _LeaveApplyScreenState();
}

class _LeaveApplyScreenState extends ConsumerState<LeaveApplyScreen> {
  LeaveBalance? selectedLeave;
  DateTime? fromDate;
  DateTime? toDate;

  DayType dayType = DayType.full;
  HalfDayPart? halfDayPart;

  String reason = '';
  File? document;

  @override
  void initState() {
    super.initState();

    selectedLeave = widget.initialLeave;

    ref.listenManual<GlobalLoadingState>(globalLoadingProvider, (prev, next) {
      if (next.isSuccess) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    });
  }

  String _formatDate(DateTime date) {
    return "${date.year.toString().padLeft(4, '0')}-"
        "${date.month.toString().padLeft(2, '0')}-"
        "${date.day.toString().padLeft(2, '0')}";
  }

  double _calculateLeaveDays() {
    if (fromDate == null || toDate == null) return 0;
    if (dayType == DayType.half) return 0.5;
    return (toDate!.difference(fromDate!).inDays + 1).toDouble();
  }

  bool get isDocumentRequired {
    if (selectedLeave == null) return false;
    final name = selectedLeave!.name.toLowerCase();
    return name.contains('maternity') || name.contains('paternity');
  }

  Future<void> _submit() async {
    if (selectedLeave == null ||
        fromDate == null ||
        toDate == null ||
        reason.isEmpty) {
      ref
          .read(globalLoadingProvider.notifier)
          .showError("Please fill all required fields");
      return;
    }

    if (dayType == DayType.half && halfDayPart == null) {
      ref
          .read(globalLoadingProvider.notifier)
          .showError("Please select AM or PM");
      return;
    }

    if (isDocumentRequired && document == null) {
      ref
          .read(globalLoadingProvider.notifier)
          .showError("Document required for this leave");
      return;
    }

    final requestedDays = _calculateLeaveDays();
    final availableDays = selectedLeave!.available;

    if (requestedDays > availableDays + 0.001) {
      ref
          .read(globalLoadingProvider.notifier)
          .showError(
            "You only have ${availableDays.toStringAsFixed(1)} ${selectedLeave!.name} remaining",
          );
      return;
    }

    final requestData = {
      "leaveTypeId": selectedLeave!.leaveTypeId,
      "startDate": _formatDate(fromDate!),
      "endDate": _formatDate(toDate!),
      "reason": reason,
      "isHalfDay": dayType == DayType.half,
    };

    if (dayType == DayType.half) {
      requestData["halfDayPart"] = halfDayPart!.name.toUpperCase();
    }

    try {
      /// 🔥 SHOW LOADING OVERLAY
      ref
          .read(globalLoadingProvider.notifier)
          .showLoading("Submitting leave request...");

      await ref
          .read(leaveApplyProvider.notifier)
          .submitLeave(data: requestData, document: document);

      /// 🔥 SHOW SUCCESS ANIMATION
      ref
          .read(globalLoadingProvider.notifier)
          .showSuccess("Leave applied successfully 🎉");
    } catch (e) {
      ref
          .read(globalLoadingProvider.notifier)
          .showError(e.toString().replaceAll("Exception: ", ""));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final balanceAsync = ref.watch(leaveBalanceProvider);
    final applyState = ref.watch(leaveApplyProvider);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: scheme.surfaceContainerLowest,
          appBar: const AppAppBar(title: "Apply Leave", showBack: false),
          drawer: const AppDrawer(),
          body: balanceAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(e.toString())),
            data: (leaves) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle("Leave Type"),

                        LeaveTypeDropdown(
                          leaves: leaves,
                          selected: selectedLeave,
                          onChanged: (leave) {
                            setState(() {
                              selectedLeave = leave;
                              fromDate = null;
                              toDate = null;
                              dayType = DayType.full;
                              halfDayPart = null;
                            });

                            if (leave != null && leave.available <= 0) {
                              Future.microtask(() {
                                showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    title: const Text("No Leave Available"),
                                    content: Text(
                                      "You don't have any ${leave.name} remaining.",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text("OK"),
                                      ),
                                    ],
                                  ),
                                );
                              });
                            }
                          },
                        ),

                        if (selectedLeave != null) ...[
                          const SizedBox(height: 12),
                          _BalanceCard(leave: selectedLeave!),
                        ],

                        const SizedBox(height: 24),
                        const _SectionTitle("Duration"),
                        const SizedBox(height: 8),

                        _DayTypeSelector(
                          value: dayType,
                          onChanged: (v) {
                            setState(() {
                              dayType = v;
                              halfDayPart = null;
                              if (v == DayType.half && fromDate != null) {
                                toDate = fromDate;
                              }
                            });
                          },
                        ),

                        if (dayType == DayType.half) ...[
                          const SizedBox(height: 12),
                          _HalfDaySelector(
                            value: halfDayPart,
                            onChanged: (v) => setState(() => halfDayPart = v),
                          ),
                        ],

                        const SizedBox(height: 16),

                        if (selectedLeave == null ||
                            selectedLeave!.available > 0)
                          DateRangePicker(
                            from: fromDate,
                            to: toDate,
                            maxLeaveDays: selectedLeave?.available ?? 0,
                            isHalfDay: dayType == DayType.half,
                            onFromPick: (d) {
                              setState(() {
                                fromDate = d;
                                if (dayType == DayType.half) {
                                  toDate = d;
                                }
                              });
                            },
                            onToPick: (d) {
                              setState(() {
                                toDate = d;
                              });
                            },
                          )
                        else
                          Opacity(
                            opacity: 0.4,
                            child: IgnorePointer(
                              child: DateRangePicker(
                                from: fromDate,
                                to: toDate,
                                maxLeaveDays: 0,
                                isHalfDay: dayType == DayType.half,
                                onFromPick: (_) {},
                                onToPick: (_) {},
                              ),
                            ),
                          ),

                        if (selectedLeave != null &&
                            fromDate != null &&
                            toDate != null) ...[
                          const SizedBox(height: 16),
                          _LeaveSummaryCard(
                            available: selectedLeave!.available,
                            requested: _calculateLeaveDays(),
                          ),
                        ],

                        const SizedBox(height: 24),
                        const _SectionTitle("Reason"),
                        ReasonInput(onChanged: (v) => reason = v),

                        const SizedBox(height: 28),

                        SubmitButton(
                          isLoading: false,
                          onPressed:
                              (selectedLeave != null &&
                                  selectedLeave!.available > 0)
                              ? _submit
                              : () {},
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Consumer(
          builder: (context, ref, _) {
            final overlay = ref.watch(globalLoadingProvider);

            if (!overlay.isVisible) return const SizedBox.shrink();

            if (overlay.isLoading) {
              return GlobalLoader(message: overlay.message);
            }

            if (overlay.isSuccess) {
              return GlobalSuccess(message: overlay.message);
            }

            if (overlay.isError) {
              return GlobalError(message: overlay.message);
            }

            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _DayTypeSelector extends StatelessWidget {
  final DayType value;
  final ValueChanged<DayType> onChanged;

  const _DayTypeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SegmentedButton<DayType>(
      style: ButtonStyle(
        backgroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return scheme.primary;
          }
          return scheme.surfaceContainerHighest;
        }),
        foregroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return scheme.onPrimary;
          }
          return scheme.onSurface;
        }),
      ),
      segments: const [
        ButtonSegment(value: DayType.full, label: Text("Full Day")),
        ButtonSegment(value: DayType.half, label: Text("Half Day")),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

class _HalfDaySelector extends StatelessWidget {
  final HalfDayPart? value;
  final ValueChanged<HalfDayPart> onChanged;

  const _HalfDaySelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      children: [
        ChoiceChip(
          label: const Text("AM"),
          selected: value == HalfDayPart.am,
          onSelected: (_) => onChanged(HalfDayPart.am),
        ),
        ChoiceChip(
          label: const Text("PM"),
          selected: value == HalfDayPart.pm,
          onSelected: (_) => onChanged(HalfDayPart.pm),
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final LeaveBalance leave;
  const _BalanceCard({required this.leave});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isZero = leave.available <= 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: isZero
              ? [scheme.errorContainer, scheme.errorContainer.withOpacity(0.7)]
              : [
                  scheme.primaryContainer,
                  scheme.primaryContainer.withOpacity(0.7),
                ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Available Balance",
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            "${leave.available} days",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _LeaveSummaryCard extends StatelessWidget {
  final double available;
  final double requested;

  const _LeaveSummaryCard({required this.available, required this.requested});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final remaining = available - requested;
    final exceeds = requested > available;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: exceeds ? scheme.errorContainer : scheme.surfaceContainerHighest,
      ),
      child: Column(
        children: [
          _row("Available", available),
          const SizedBox(height: 6),
          _row("Requested", requested),
          const Divider(height: 20),
          _row(
            "Remaining",
            remaining < 0 ? 0 : remaining,
            highlight: true,
            isError: exceeds,
          ),
        ],
      ),
    );
  }

  Widget _row(
    String label,
    double value, {
    bool highlight = false,
    bool isError = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        Text(
          "$value days",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isError ? Colors.red : null,
          ),
        ),
      ],
    );
  }
}
