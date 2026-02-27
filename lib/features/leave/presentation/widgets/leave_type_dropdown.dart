import 'package:flutter/material.dart';
import '../../data/models/leave_balance_model.dart';

class LeaveTypeDropdown extends StatelessWidget {
  final List<LeaveBalance> leaves;
  final LeaveBalance? selected;
  final ValueChanged<LeaveBalance?> onChanged;

  const LeaveTypeDropdown({
    super.key,
    required this.leaves,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DropdownButtonFormField<LeaveBalance>(
      value: selected,
      isExpanded: true,

      decoration: InputDecoration(
        labelText: "Select Leave Type",
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),

      items: leaves.map((leave) {
        return DropdownMenuItem<LeaveBalance>(
          value: leave,
          child: Text(
            leave.name, // ✅ ONLY NAME
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: scheme.onSurface,
            ),
          ),
        );
      }).toList(),

      onChanged: onChanged,
    );
  }
}
