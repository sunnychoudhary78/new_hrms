import 'package:flutter/material.dart';
import 'package:lms/core/theme/app_design.dart';
import 'package:lms/features/leave/data/models/leave_balance_model.dart';
import 'package:lms/features/leave/presentation/screens/leave_apply_screen.dart';
import '../utils/leave_color_mapper.dart';

class LeaveBalanceTile extends StatelessWidget {
  final LeaveBalance balance;

  const LeaveBalanceTile({super.key, required this.balance});

  @override
  Widget build(BuildContext context) {
    final name = balance.name;
    final available = balance.available < 0 ? 0.0 : balance.available;
    final carried = balance.carried;
    final reserved = balance.pendingReserved;

    final Color accentColor = LeaveColorMapper.colorFor(name);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () {
          if (available <= 0 && !balance.allowNegativeBalance) {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                title: const Text("Cannot Apply"),
                content: Text("You don't have any $name leave available."),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("OK"),
                  ),
                ],
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LeaveApplyScreen(initialLeave: balance),
              ),
            );
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm + 6),
          padding: const EdgeInsets.all(AppSpacing.md + 2),
          decoration: AppColors.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.title,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatDays(available),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                      Text(
                        'days available',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ],
              ),
              if (carried > 0 || reserved > 0) ...[
                SizedBox(height: AppSpacing.sm + 6),
                Divider(color: AppColors.border, height: 1),
                const SizedBox(height: AppSpacing.sm + 4),
                Row(
                  children: [
                    if (carried > 0)
                      _MetaText(
                        label: 'Carried',
                        value: carried,
                        color: accentColor,
                      ),
                    if (reserved > 0) ...[
                      const SizedBox(width: AppSpacing.md),
                      _MetaText(
                        label: 'Reserved',
                        value: reserved,
                        color: AppColors.statusOrange,
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MetaText({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 13, color: AppColors.title),
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(color: AppColors.muted),
          ),
          TextSpan(
            text: formatDays(value),
            style: TextStyle(fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

String formatDays(double value) {
  final safeValue = value < 0 ? 0.0 : value;

  if (safeValue % 1 == 0) {
    return safeValue.toStringAsFixed(0);
  }
  return safeValue.toStringAsFixed(1);
}
