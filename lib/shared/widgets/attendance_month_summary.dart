import 'package:flutter/material.dart';

class AttendanceMonthSummary extends StatelessWidget {
  final Map<String, int> counts;

  const AttendanceMonthSummary({super.key, required this.counts});

  Widget _item(String label, int count, Color color, ColorScheme scheme) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              "$count",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        _item(
          "On-Time",
          counts["On-Time"] ?? 0,
          const Color(0xFF22C55E),
          scheme,
        ),
        const SizedBox(width: 8),
        _item("Late", counts["Late"] ?? 0, const Color(0xFFF59E0B), scheme),
        const SizedBox(width: 8),
        _item("Absent", counts["Absent"] ?? 0, const Color(0xFFEF4444), scheme),
        const SizedBox(width: 8),
        _item(
          "Holiday",
          counts["Holiday"] ?? 0,
          const Color(0xFF3B82F6),
          scheme,
        ),
        const SizedBox(width: 8),
        _item(
          "Leave",
          counts["On-Leave"] ?? 0,
          const Color(0xFFA855F7),
          scheme,
        ),
      ],
    );
  }
}
