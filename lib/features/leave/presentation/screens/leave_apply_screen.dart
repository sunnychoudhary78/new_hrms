import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lms/core/providers/global_loading_provider.dart';
import 'package:lms/features/home/presentation/widgets/app_drawer.dart';
import 'package:lms/shared/widgets/app_bar.dart';
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

  late final ProviderSubscription<LeaveApplyStatus> _leaveSub;

  @override
  void initState() {
    super.initState();

    selectedLeave = widget.initialLeave;

    _leaveSub = ref.listenManual<LeaveApplyStatus>(leaveApplyProvider, (
      prev,
      next,
    ) {
      if (next == LeaveApplyStatus.success && mounted) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    });
  }

  @override
  void dispose() {
    _leaveSub.close();
    super.dispose();
  }

  void _showLocalError(String message) {
    ref.read(globalLoadingProvider.notifier).showError(message);
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

  bool get isDocumentRequired => selectedLeave?.documentRequired ?? false;

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result == null) return;

      final path = result.files.single.path;

      if (path == null) {
        _showLocalError("Unable to read selected file");
        return;
      }

      setState(() {
        document = File(path);
      });
    } catch (e) {
      _showLocalError("Failed to pick document");
    }
  }

  Future<void> _submit() async {
    final overlay = ref.read(globalLoadingProvider.notifier);

    /// ---------- UI VALIDATIONS ----------

    if (selectedLeave == null) {
      overlay.showError("Please select leave type");
      return;
    }

    if (fromDate == null || toDate == null) {
      overlay.showError("Please select leave dates");
      return;
    }

    if (reason.trim().isEmpty) {
      overlay.showError("Please enter reason");
      return;
    }

    if (dayType == DayType.half && halfDayPart == null) {
      overlay.showError("Please select AM or PM");
      return;
    }

    if (isDocumentRequired && document == null) {
      overlay.showError("Please upload required document");
      return;
    }

    final requestedDays = _calculateLeaveDays();
    final availableDays = selectedLeave!.available;

    if (!selectedLeave!.allowNegativeBalance &&
        requestedDays > availableDays + 0.001) {
      overlay.showError(
        "You only have ${availableDays.toStringAsFixed(1)} ${selectedLeave!.name} remaining",
      );
      return;
    }

    /// ---------- PREPARE DATA ----------

    final startDate = _formatDate(fromDate!);
    final endDate = dayType == DayType.half ? startDate : _formatDate(toDate!);

    final requestData = {
      "leaveTypeId": selectedLeave!.leaveTypeId,
      "startDate": startDate,
      "endDate": endDate,
      "reason": reason.trim(),
      "isHalfDay": dayType == DayType.half,
    };

    if (dayType == DayType.half) {
      requestData["halfDayPart"] = _toBackendHalfDayPart(halfDayPart!);
    }

    /// ---------- CALL API ----------

    await ref
        .read(leaveApplyProvider.notifier)
        .submitLeave(data: requestData, document: document);
  }

  String _toBackendHalfDayPart(HalfDayPart value) {
    switch (value) {
      case HalfDayPart.am:
        return "AM";
      case HalfDayPart.pm:
        return "PM";
    }
  }

  @override
  Widget build(BuildContext context) {
    final balanceAsync = ref.watch(leaveBalanceProvider);
    final applyState = ref.watch(leaveApplyProvider);

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: const AppAppBar(title: "Apply Leave", showBack: false),
      drawer: const AppDrawer(),
      body: balanceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (leaves) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: [scheme.primaryContainer, scheme.secondaryContainer],
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: scheme.primary,
                    child: Icon(
                      Icons.event_note_outlined,
                      color: scheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Submit your leave request with date, reason and supporting document.",
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            /// 🔹 LEAVE TYPE
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle("Leave Type"),
                  const SizedBox(height: 12),

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
                        document = null;
                      });
                    },
                  ),

                  if (selectedLeave != null) ...[
                    const SizedBox(height: 12),
                    _BalanceCard(leave: selectedLeave!),
                  ],
                ],
              ),
            ),

            /// 🔹 DURATION
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle("Duration"),
                  const SizedBox(height: 12),

                  _DayTypeSelector(
                    value: dayType,
                    allowHalfDay: selectedLeave?.allowHalfDay ?? false,
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

                  DateRangePicker(
                    from: fromDate,
                    to: toDate,
                    maxLeaveDays: selectedLeave == null
                        ? 0
                        : selectedLeave!.allowNegativeBalance
                        ? -1
                        : selectedLeave!.available,
                    isHalfDay: dayType == DayType.half,
                    onFromPick: (d) {
                      setState(() {
                        fromDate = d;
                        if (dayType == DayType.half) toDate = d;
                      });
                    },
                    onToPick: (d) {
                      setState(() {
                        toDate = d;
                      });
                    },
                  ),
                ],
              ),
            ),

            /// 🔹 REASON
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle("Reason"),
                  const SizedBox(height: 12),

                  ReasonInput(onChanged: (v) => reason = v),
                ],
              ),
            ),

            /// 🔹 DOCUMENT
            if (isDocumentRequired)
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle("Supporting Document"),
                    const SizedBox(height: 12),

                    InkWell(
                      onTap: _pickDocument,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: scheme.surfaceContainerHighest,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.upload_file),
                            const SizedBox(width: 12),

                            Expanded(
                              child: Text(
                                document == null
                                    ? "Tap to upload document"
                                    : document!.path.split('/').last,
                              ),
                            ),

                            if (document != null)
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  setState(() {
                                    document = null;
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            /// 🔹 SUBMIT
            SubmitButton(
              isLoading: applyState == LeaveApplyStatus.loading,
              onPressed: _submit,
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

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
        const SizedBox(width: 8),

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

class _DayTypeSelector extends StatelessWidget {
  final DayType value;
  final bool allowHalfDay;
  final ValueChanged<DayType> onChanged;

  const _DayTypeSelector({
    required this.value,
    required this.allowHalfDay,
    required this.onChanged,
  });

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
      segments: [
        const ButtonSegment(value: DayType.full, label: Text("Full Day")),
        if (allowHalfDay)
          const ButtonSegment(value: DayType.half, label: Text("Half Day")),
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
              ? [scheme.errorContainer, scheme.errorContainer.withOpacity(0.8)]
              : [
                  scheme.primaryContainer,
                  scheme.primaryContainer.withOpacity(0.8),
                ],
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.wallet, color: scheme.onPrimaryContainer),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Available Balance", style: TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  "${leave.available} days",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
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

class SectionCard extends StatelessWidget {
  final Widget child;

  const SectionCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}
