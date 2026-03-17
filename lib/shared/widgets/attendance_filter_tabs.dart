import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/attendance/correction_attendance/presentation/providers/attendance_requests_provider.dart';

class AttendanceFilterTabs extends ConsumerWidget {
  const AttendanceFilterTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(attendanceRequestsProvider).value;

    final current = state?.statusFilter ?? "PENDING";

    final counts = {
      "PENDING": state?.requests.where((e) => e.isPending).length ?? 0,
      "APPROVED": state?.requests.where((e) => e.isApproved).length ?? 0,
      "REJECTED": state?.requests.where((e) => e.isRejected).length ?? 0,
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _TabItem(
            label: "Pending",
            value: "PENDING",
            count: counts["PENDING"]!,
            selected: current == "PENDING",
            color: Colors.amber,
            onTap: () {
              ref
                  .read(attendanceRequestsProvider.notifier)
                  .changeStatus("PENDING");
            },
          ),
          const SizedBox(width: 8),
          _TabItem(
            label: "Approved",
            value: "APPROVED",
            count: counts["APPROVED"]!,
            selected: current == "APPROVED",
            color: Colors.green,
            onTap: () {
              ref
                  .read(attendanceRequestsProvider.notifier)
                  .changeStatus("APPROVED");
            },
          ),
          const SizedBox(width: 8),
          _TabItem(
            label: "Rejected",
            value: "REJECTED",
            count: counts["REJECTED"]!,
            selected: current == "REJECTED",
            color: Colors.red,
            onTap: () {
              ref
                  .read(attendanceRequestsProvider.notifier)
                  .changeStatus("REJECTED");
            },
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final String value;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TabItem({
    required this.label,
    required this.value,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(.15)
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected
                ? color.withOpacity(.5)
                : scheme.outline.withOpacity(.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// LABEL
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? color : scheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(width: 6),

            /// COUNT BADGE
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: selected ? color.withOpacity(.25) : scheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: selected ? color : scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
