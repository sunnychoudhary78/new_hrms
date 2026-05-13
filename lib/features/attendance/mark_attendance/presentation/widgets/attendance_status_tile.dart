import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AttendanceStatusTiles extends StatelessWidget {
  final DateTime? punchInTime;
  final DateTime? punchOutTime;

  const AttendanceStatusTiles({
    super.key,
    required this.punchInTime,
    required this.punchOutTime,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: _StatusTile(
            label: "Check In",
            time: punchInTime,
            color: scheme.primary,
            icon: Icons.login_rounded,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatusTile(
            label: "Check Out",
            time: punchOutTime,
            color: scheme.tertiary,
            icon: Icons.logout_rounded,
          ),
        ),
      ],
    );
  }
}

class _StatusTile extends StatelessWidget {
  final String label;
  final DateTime? time;
  final Color color;
  final IconData icon;

  const _StatusTile({
    required this.label,
    required this.time,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    final formattedTime = time != null
        ? DateFormat('hh:mm a').format(time!)
        : "--:--";

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(isIOS ? 18 : 24),
        border: Border.all(color: color.withOpacity(.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            formattedTime,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
