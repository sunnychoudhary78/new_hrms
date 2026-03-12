import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateRangePicker extends StatelessWidget {
  final DateTime? from;
  final DateTime? to;
  final ValueChanged<DateTime> onFromPick;
  final ValueChanged<DateTime> onToPick;

  /// Maximum leave days allowed
  final double maxLeaveDays;

  /// Half day mode
  final bool isHalfDay;

  const DateRangePicker({
    super.key,
    required this.from,
    required this.to,
    required this.onFromPick,
    required this.onToPick,
    required this.maxLeaveDays,
    required this.isHalfDay,
  });

  //////////////////////////////////////////////////////////////
  /// FROM PICKER
  //////////////////////////////////////////////////////////////

  Future<void> _pickFrom(BuildContext context) async {
    debugPrint("📅 Opening FROM date picker");
    debugPrint("📅 Current FROM value: $from");

    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2030),
      initialDate: from ?? DateTime.now(),
    );

    if (picked != null) {
      debugPrint("✅ FROM date selected: $picked");

      onFromPick(picked);

      /// Half-day → TO must be same
      if (isHalfDay) {
        onToPick(picked);
        return;
      }

      /// FIX: ensure TO date never becomes invalid
      if (to != null && picked.isAfter(to!)) {
        onToPick(picked);
      }
    } else {
      debugPrint("⚠️ FROM date selection cancelled");
    }
  }

  //////////////////////////////////////////////////////////////
  /// TO PICKER WITH BALANCE LIMIT
  //////////////////////////////////////////////////////////////

  Future<void> _pickTo(BuildContext context) async {
    if (from == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select start date first")),
      );
      return;
    }

    /// Half-day → TO = FROM
    if (isHalfDay) {
      onToPick(from!);
      return;
    }

    DateTime lastDate;

    if (maxLeaveDays < 0) {
      /// Unlimited (LWP)
      lastDate = DateTime(2030);
    } else {
      lastDate = from!.add(Duration(days: maxLeaveDays.floor() - 1));
    }

    final picked = await showDatePicker(
      context: context,
      firstDate: from!,
      lastDate: lastDate,
      initialDate: to ?? from!,
    );

    if (picked != null) {
      /// Safety validation
      if (picked.isBefore(from!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("End date cannot be before start date")),
        );
        return;
      }

      /// Balance validation
      if (maxLeaveDays >= 0) {
        final selectedDays = picked.difference(from!).inDays + 1;

        if (selectedDays > maxLeaveDays + 0.001) {
          final formatted = maxLeaveDays % 1 == 0
              ? maxLeaveDays.toInt().toString()
              : maxLeaveDays.toString();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("You can only select up to $formatted days"),
            ),
          );
          return;
        }
      }

      onToPick(picked);
    }
  }

  //////////////////////////////////////////////////////////////
  /// UI
  //////////////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _box(context, "From", from, () => _pickFrom(context))),
        const SizedBox(width: 12),
        Expanded(child: _box(context, "To", to, () => _pickTo(context))),
      ],
    );
  }

  //////////////////////////////////////////////////////////////
  /// DATE BOX
  //////////////////////////////////////////////////////////////

  Widget _box(
    BuildContext context,
    String label,
    DateTime? date,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
        ).copyWith(labelText: label),
        child: Text(
          date == null ? "Select" : DateFormat('dd MMM yyyy').format(date),
        ),
      ),
    );
  }
}
