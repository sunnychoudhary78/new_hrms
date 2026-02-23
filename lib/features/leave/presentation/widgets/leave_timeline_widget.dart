import 'package:flutter/material.dart';
import '../../data/models/leave_details_model.dart';

class LeaveTimelineWidget extends StatelessWidget {
  final List<LeaveHistory> histories;

  const LeaveTimelineWidget({super.key, required this.histories});

  @override
  Widget build(BuildContext context) {
    if (histories.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Timeline",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 16),

        ...List.generate(histories.length, (index) {
          final history = histories[index];
          final isLast = index == histories.length - 1;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// LEFT TIMELINE LINE + DOT
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _colorForAction(history.action),
                      shape: BoxShape.circle,
                    ),
                  ),

                  if (!isLast)
                    Container(
                      width: 2,
                      height: 50,
                      color: Colors.grey.shade300,
                    ),
                ],
              ),

              const SizedBox(width: 12),

              /// RIGHT CONTENT
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// ACTION
                      Text(
                        history.action,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),

                      if (history.actorName != null)
                        Text(
                          "by ${history.actorName}",
                          style: TextStyle(color: Colors.grey.shade600),
                        ),

                      if (history.at != null)
                        Text(
                          _formatDate(history.at!),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),

                      if (history.comment != null &&
                          history.comment!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text("Comment: ${history.comment}"),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Color _colorForAction(String action) {
    switch (action.toLowerCase()) {
      case "submitted":
        return Colors.blue;

      case "approved":
        return Colors.green;

      case "rejected":
        return Colors.red;

      case "revoked":
        return Colors.grey;

      default:
        return Colors.orange;
    }
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year} "
        "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }
}
