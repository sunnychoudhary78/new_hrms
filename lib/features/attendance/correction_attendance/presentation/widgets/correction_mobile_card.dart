import 'package:flutter/material.dart';
import 'package:lms/features/attendance/correction_attendance/presentation/dialogs/review_request_dialog.dart';
import '../../data/models/attendance_request_model.dart';
import 'user_cell.dart';

class RequestCard extends StatelessWidget {
  final AttendanceRequest item;

  const RequestCard({super.key, required this.item});

  String formatTime(String? iso) {
    if (iso == null) return "--";

    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return "--";

    final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour >= 12 ? "PM" : "AM";

    return "${hour == 0 ? 12 : hour}:$minute $suffix";
  }

  /// 🔥 STATUS COLOR (controlled)
  Color _statusColor() {
    switch (item.status) {
      case "APPROVED":
        return Colors.green;
      case "REJECTED":
        return Colors.red;
      default:
        return Colors.amber;
    }
  }

  /// 🔹 TYPE LABEL
  String _typeLabel() {
    if (item.isRemote) return "Remote";
    return "Correction";
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = _statusColor();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outline.withOpacity(.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 🔝 TOP ROW (TYPE + STATUS)
          Row(
            children: [
              _Chip(label: _typeLabel(), color: scheme.primary),
              const Spacer(),
              _Chip(label: item.status, color: statusColor, isFilled: true),
            ],
          ),

          const SizedBox(height: 12),

          /// 👤 USER
          UserCell(name: item.userName, image: item.userImage),

          const SizedBox(height: 10),

          /// 📝 REASON
          Text(
            item.reason ?? "—",
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),

          const SizedBox(height: 14),

          /// ⏱ TIME BLOCK (ONLY FOR ATTENDANCE TYPE)
          if (item.isCorrection || item.isRemote)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  /// ORIGINAL
                  Row(
                    children: [
                      Text(
                        "Original",
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        "${formatTime(item.originalCheckIn)} → ${formatTime(item.originalCheckOut)}",
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  /// PROPOSED
                  Row(
                    children: [
                      Text(
                        "Proposed",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        "${formatTime(item.proposedCheckIn)} → ${formatTime(item.proposedCheckOut)}",
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          const SizedBox(height: 14),

          /// 🔘 ACTIONS
          if (item.status == "PENDING")
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      showReviewDialog(context: context, req: item);
                    },
                    icon: const Icon(Icons.close_rounded),
                    label: const Text("Reject"),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      showReviewDialog(context: context, req: item);
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text("Approve"),
                  ),
                ),
              ],
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  showReviewDialog(context: context, req: item);
                },
                child: const Text("View details"),
              ),
            ),
        ],
      ),
    );
  }
}

/// 🔹 REUSABLE CHIP
class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isFilled;

  const _Chip({
    required this.label,
    required this.color,
    this.isFilled = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isFilled ? color.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isFilled
              ? color.withValues(alpha: 0.45)
              : scheme.outlineVariant,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
