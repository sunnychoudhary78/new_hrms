import 'package:flutter/material.dart';
import 'package:lms/features/leave/data/models/leave_balance_model.dart';
import 'package:lms/features/leave/presentation/screens/leave_apply_screen.dart';
import '../utils/leave_color_mapper.dart';

class LeaveBalanceTile extends StatelessWidget {
  final LeaveBalance balance;

  const LeaveBalanceTile({super.key, required this.balance});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final name = balance.name;
    final available = balance.available < 0 ? 0.0 : balance.available;
    final carried = balance.carried;
    final reserved = balance.pendingReserved;

    final Color accentColor = LeaveColorMapper.colorFor(name);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        if (available <= 0 && !balance.allowNegativeBalance) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
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
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
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
                      color: scheme.onSurface,
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
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            if (carried > 0 || reserved > 0) ...[
              const SizedBox(height: 14),
              Divider(color: scheme.outlineVariant),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (carried > 0)
                    _MetaText(
                      label: 'Carried',
                      value: carried,
                      color: accentColor,
                    ),
                  if (reserved > 0) ...[
                    const SizedBox(width: 16),
                    _MetaText(
                      label: 'Reserved',
                      value: reserved,
                      color: Colors.orange,
                    ),
                  ],
                ],
              ),
            ],
          ],
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
    final scheme = Theme.of(context).colorScheme;

    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 13, color: scheme.onSurface),
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(color: scheme.onSurfaceVariant),
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
