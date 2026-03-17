import 'package:flutter/material.dart';
import 'package:lms/core/theme/app_design.dart';
import '../../data/models/attendance_request_model.dart';
import 'correction_mobile_card.dart';
import 'correction_table.dart';

class CorrectionSection extends StatelessWidget {
  final List<AttendanceRequest> requests;

  const CorrectionSection({super.key, required this.requests});

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        /// 📱 MOBILE VIEW
        if (constraints.maxWidth < 800) {
          return Column(
            children: [
              for (int i = 0; i < requests.length; i++) ...[
                RequestCard(item: requests[i]),
                if (i != requests.length - 1)
                  const SizedBox(height: AppSpacing.md),
              ],
            ],
          );
        }

        /// 💻 TABLE VIEW
        return CorrectionTable(items: requests);
      },
    );
  }
}
