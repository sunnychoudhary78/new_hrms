import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lms/features/attendance/shared/data/attendance_repository_provider.dart';
import '../widgets/section_header.dart';
import '../widgets/time_picker_card.dart';

void showRequestCorrectionDialog({
  required BuildContext context,
  required DateTime selectedDate,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _RequestCorrectionDialog(),
  );
}

class _RequestCorrectionDialog extends ConsumerStatefulWidget {
  const _RequestCorrectionDialog();

  @override
  ConsumerState<_RequestCorrectionDialog> createState() =>
      _RequestCorrectionDialogState();
}

class _RequestCorrectionDialogState
    extends ConsumerState<_RequestCorrectionDialog> {
  late DateTime targetDate;
  TimeOfDay? proposedIn;
  TimeOfDay? proposedOut;
  final reasonController = TextEditingController();
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    targetDate = DateTime.now();
  }

  DateTime _combine(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }

  Future<void> _submit() async {
    if (proposedIn == null) {
      _showError("Please select check-in time");
      return;
    }

    if (reasonController.text.trim().isEmpty) {
      _showError("Please enter reason");
      return;
    }

    final checkIn = _combine(targetDate, proposedIn!);
    final checkOut = proposedOut != null
        ? _combine(targetDate, proposedOut!)
        : null;

    /// 🚨 CRITICAL FIX
    if (checkOut != null && checkOut.isBefore(checkIn)) {
      _showError("Checkout must be after check-in");
      return;
    }

    setState(() => isSubmitting = true);

    try {
      await ref.read(attendanceRepositoryProvider).requestCorrection({
        "targetDate": DateFormat('yyyy-MM-dd').format(targetDate),
        "proposedCheckIn": checkIn.toIso8601String(),
        if (checkOut != null) "proposedCheckOut": checkOut.toIso8601String(),
        "reason": reasonController.text.trim(),
      });

      if (mounted) Navigator.pop(context);

      _showSuccess("Correction request submitted");
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// HEADER
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Request Correction",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: scheme.onSurface),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              /// DATE
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: targetDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => targetDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    DateFormat('EEEE, d MMM y').format(targetDate),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const SectionHeader(
                title: "New Correction",
                icon: Icons.edit_note,
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TimePickerCard(
                      label: "In Time",
                      time: proposedIn,
                      onPick: (t) => setState(() => proposedIn = t),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TimePickerCard(
                      label: "Out Time",
                      time: proposedOut,
                      onPick: (t) => setState(() => proposedOut = t),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: "Reason",
                  border: const OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: scheme.primary),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                  ),
                  child: isSubmitting
                      ? CircularProgressIndicator(color: scheme.onPrimary)
                      : const Text("Submit Request"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
