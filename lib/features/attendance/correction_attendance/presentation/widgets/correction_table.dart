import 'package:flutter/material.dart';
import '../../data/models/attendance_request_model.dart';
import '../dialogs/review_request_dialog.dart';
import 'user_cell.dart';

class CorrectionTable extends StatelessWidget {
  final List<AttendanceRequest> items;

  const CorrectionTable({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final isCorrection = items.first.isCorrection;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 28,
        horizontalMargin: 24,
        headingRowHeight: 48,
        dataRowMinHeight: 56,
        dataRowMaxHeight: 64,
        headingTextStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.black54,
          fontSize: 13,
        ),
        columns: [
          const DataColumn(label: Text('USER')),
          const DataColumn(label: Text('DATE')),

          if (isCorrection) ...[
            const DataColumn(label: Text('IN TIME')),
            const DataColumn(label: Text('OUT TIME')),
            const DataColumn(label: Text('REASON')),
          ] else ...[
            const DataColumn(label: Text('REASON')),
          ],

          const DataColumn(label: Text('ACTION')),
        ],
        rows: items.map((item) {
          return DataRow(
            cells: [
              DataCell(UserCell(name: item.userName, image: item.userImage)),

              DataCell(
                Text(
                  item.targetDate,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),

              if (item.isCorrection) ...[
                DataCell(_TimeChip(item.proposedCheckIn)),
                DataCell(_TimeChip(item.proposedCheckOut)),
                DataCell(
                  SizedBox(
                    width: 200,
                    child: Text(
                      item.reason ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ] else ...[
                DataCell(
                  SizedBox(
                    width: 240,
                    child: Text(
                      item.reason ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],

              DataCell(
                ElevatedButton(
                  onPressed: () {
                    showReviewDialog(context: context, req: item);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    elevation: 0,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Review'),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String? time;

  const _TimeChip(this.time);

  @override
  Widget build(BuildContext context) {
    if (time == null || time!.isEmpty) {
      return const Text('--:--');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.indigo.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        time!,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: Colors.indigo,
        ),
      ),
    );
  }
}
