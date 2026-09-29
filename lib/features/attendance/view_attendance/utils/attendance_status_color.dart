import 'package:flutter/material.dart';

class AttendanceStatusColor {
  static Color fromStatus(BuildContext context, String status) {
    final scheme = Theme.of(context).colorScheme;

    switch (status.toLowerCase()) {
      case 'present':
      case 'on-time':
      case 'ontime':
        return scheme.primary;

      case 'late':
        return Colors.orange;

      case 'half-day':
      case 'half day':
      case '1st half working':
      case '2nd half working':
        return const Color(0xFFEAB308);

      case 'leave':
      case 'on-leave':
        return const Color(0xFFA855F7);

      case 'holiday':
        return const Color(0xFF0891B2);

      case 'weekoff':
      case 'week-off':
      case 'week off':
        return scheme.outlineVariant;

      case 'absent':
        return Colors.red;

      default:
        return scheme.outlineVariant;
    }
  }
}
