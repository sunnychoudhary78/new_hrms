import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TimePickerCard extends StatelessWidget {
  final String label;
  final TimeOfDay? time;
  final ValueChanged<TimeOfDay> onPick;
  final bool isProposed;

  const TimePickerCard({
    super.key,
    required this.label,
    required this.time,
    required this.onPick,
    this.isProposed = true,
  });

  String _format(TimeOfDay time) {
    final now = DateTime.now();

    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);

    return DateFormat('hh:mm a').format(dt); // ← FIXED AM/PM
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time ?? TimeOfDay.now(),

          /// 🚀 FORCE AM/PM MODE
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(alwaysUse24HourFormat: false),
              child: child!,
            );
          },
        );

        if (picked != null) {
          onPick(picked);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: time != null
                ? scheme.primary
                : scheme.outline.withOpacity(.3),
            width: 1.5,
          ),
          boxShadow: [
            if (time != null)
              BoxShadow(
                color: scheme.primary.withOpacity(.15),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                color: scheme.primary,
                fontWeight: FontWeight.w600,
                letterSpacing: .5,
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 18, color: scheme.primary),
                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    time != null ? _format(time!) : "Select time",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: time != null
                          ? scheme.onSurface
                          : scheme.onSurface.withOpacity(.4),
                    ),
                  ),
                ),

                if (time != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _format(time!).split(' ')[1], // AM / PM badge
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: scheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
