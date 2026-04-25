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

      /// ✅ CLEAN DECORATION (let theme handle most things)
      decoration: const InputDecoration(
        labelText: "Leave Type",
        prefixIcon: Icon(Icons.work_outline),
      ),

      dropdownColor: scheme.surface,

      items: leaves.map((leave) {
        final disabled = !leave.canApply;

        return DropdownMenuItem<LeaveBalance>(
          value: leave,
          enabled: true,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                leave.name,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: disabled ? scheme.error : scheme.onSurface,
                ),
              ),

              if (disabled)
                Text(
                  "No balance",
                  style: TextStyle(fontSize: 12, color: scheme.error),
                ),
            ],
          ),
        );
      }).toList(),

      onChanged: onChanged,
    );
  }
}
