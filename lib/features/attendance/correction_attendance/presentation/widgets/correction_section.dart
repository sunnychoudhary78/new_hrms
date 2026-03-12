import 'package:flutter/material.dart';
import 'package:lms/core/theme/app_design.dart';
import '../../data/models/attendance_request_model.dart';
import 'correction_mobile_card.dart';
import 'correction_table.dart';

class CorrectionSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final String type;
  final List<AttendanceRequest> requests;

  const CorrectionSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.requests,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final items = requests.where((e) => e.type == type).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outline.withOpacity(.2)),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withOpacity(.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return constraints.maxWidth < 800
              ? Column(
                  children: items
                      .map((e) => CorrectionMobileCard(item: e))
                      .toList(),
                )
              : CorrectionTable(items: items);
        },
      ),
    );
  }
}
