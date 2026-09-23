import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lms/features/meetings/data/models/meeting_model.dart';

class MeetingEmployeePicker extends StatelessWidget {
  const MeetingEmployeePicker({
    super.key,
    required this.employees,
    required this.selectedIds,
    required this.filter,
    required this.onFilterChanged,
    required this.onToggle,
    this.label = 'Invite employees',
    this.hint = 'Search employees…',
    this.helper,
  });

  final List<MeetingEmployee> employees;
  final List<String> selectedIds;
  final String filter;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<String> onToggle;
  final String label;
  final String hint;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final q = filter.trim().toLowerCase();
    final filtered = q.isEmpty
        ? employees
        : employees
              .where((e) => e.name.toLowerCase().contains(q))
              .toList();
    final selected = selectedIds.map((e) => e.toString()).toSet();
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.search_rounded),
          ),
          onChanged: onFilterChanged,
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 180),
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(isIOS ? 12 : 14),
          ),
          child: filtered.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No employees found',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final emp = filtered[i];
                    final checked = selected.contains(emp.id);
                    return CheckboxListTile(
                      dense: true,
                      value: checked,
                      title: Text(emp.name),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (_) => onToggle(emp.id),
                    );
                  },
                ),
        ),
        const SizedBox(height: 6),
        Text(
          helper ??
              '${selectedIds.length} selected — they get invite email + reminders',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class WeekdayChipRow extends StatelessWidget {
  const WeekdayChipRow({
    super.key,
    required this.selectedDays,
    required this.onToggle,
  });

  final List<int> selectedDays;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = selectedDays.toSet();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: meetingWeekdays.entries.map((e) {
        final on = selected.contains(e.key);
        return FilterChip(
          label: Text(e.value),
          selected: on,
          onSelected: (_) => onToggle(e.key),
          selectedColor: scheme.primary,
          labelStyle: TextStyle(
            color: on ? scheme.onPrimary : scheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
          checkmarkColor: scheme.onPrimary,
        );
      }).toList(),
    );
  }
}
