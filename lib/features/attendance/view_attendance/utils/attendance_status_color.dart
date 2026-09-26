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
      case 'half-day':
      case 'half day':
        return Colors.orange;

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
