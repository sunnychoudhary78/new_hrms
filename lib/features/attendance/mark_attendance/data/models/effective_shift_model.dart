import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EffectiveShift {
  final String? shiftId;
  final String? shiftName;
  final String shiftMode;
  final bool isFixed;
  final String? shiftSource;
  final bool? matchedInWindow;
  final String? officeStartTime;
  final String? officeEndTime;
  final String? lunchBreakStartTime;
  final String? lunchBreakEndTime;
  final int lateGracePeriodMinutes;
  final bool autoCloseEnabled;
  final String? autoCloseTime;
  final bool isOvernight;
  final String timezone;

  const EffectiveShift({
    this.shiftId,
    this.shiftName,
    this.shiftMode = 'rotation',
    this.isFixed = false,
    this.shiftSource,
    this.matchedInWindow,
    this.officeStartTime,
    this.officeEndTime,
    this.lunchBreakStartTime,
    this.lunchBreakEndTime,
    this.lateGracePeriodMinutes = 15,
    this.autoCloseEnabled = false,
    this.autoCloseTime,
    this.isOvernight = false,
    this.timezone = 'Asia/Kolkata',
  });

  bool get isFixedMode => isFixed || shiftMode.toLowerCase() == 'fixed';

  String get modeLabel => isFixedMode ? 'Fixed' : 'Rotation';

  TimeOfDay? get officeStartTod => parseHhMm(officeStartTime);

  TimeOfDay? get officeEndTod => parseHhMm(officeEndTime);

  String get officeStartDisplay => formatOfficeTime(officeStartTime);

  String get officeEndDisplay => formatOfficeTime(officeEndTime);

  String get startSubtitle {
    final name = shiftName?.trim();
    if (name != null && name.isNotEmpty) {
      return '$name · $modeLabel';
    }
    if (isFixedMode) return 'Fixed';
    return '';
  }

  String? get lunchDisplay {
    if (lunchBreakStartTime == null && lunchBreakEndTime == null) {
      return null;
    }
    return '${formatOfficeTime(lunchBreakStartTime)} – ${formatOfficeTime(lunchBreakEndTime)}';
  }

  factory EffectiveShift.fromJson(Map<String, dynamic> json) {
    return EffectiveShift(
      shiftId: json['shift_id']?.toString(),
      shiftName: json['shift_name']?.toString(),
      shiftMode: json['shift_mode']?.toString() ?? 'rotation',
      isFixed: json['is_fixed'] == true,
      shiftSource: json['shift_source']?.toString(),
      matchedInWindow: json['matched_in_window'] is bool
          ? json['matched_in_window'] as bool
          : null,
      officeStartTime: json['office_start_time']?.toString(),
      officeEndTime: json['office_end_time']?.toString(),
      lunchBreakStartTime: json['lunch_break_start_time']?.toString(),
      lunchBreakEndTime: json['lunch_break_end_time']?.toString(),
      lateGracePeriodMinutes:
          int.tryParse(json['late_grace_period_minutes']?.toString() ?? '') ??
          15,
      autoCloseEnabled: json['auto_close_enabled'] == true,
      autoCloseTime: json['auto_close_time']?.toString(),
      isOvernight: json['is_overnight'] == true,
      timezone: json['timezone']?.toString() ?? 'Asia/Kolkata',
    );
  }

  static TimeOfDay? parseHhMm(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  static String formatOfficeTime(String? raw) {
    final tod = parseHhMm(raw);
    if (tod == null) return '--:--';
    final dt = DateTime(2000, 1, 1, tod.hour, tod.minute);
    return DateFormat('h:mm a').format(dt);
  }
}
