import 'package:flutter/material.dart';

/// Short codes and distinct colors for leave vs holiday on the calendar.
/// Leave types use a warm/jewel palette. Holidays stay on a cyan/teal palette.
class CalendarTypeStyle {
  CalendarTypeStyle._();

  static const Color leaveCategory = Color(0xFFA855F7);
  static const Color holidayCategory = Color(0xFF0891B2);

  static const Map<String, String> _knownLeaveCodes = {
    'casual leave': 'CL',
    'casual': 'CL',
    'sick leave': 'SL',
    'sick': 'SL',
    'medical leave': 'ML',
    'medical': 'ML',
    'earned leave': 'EL',
    'earned': 'EL',
    'privilege leave': 'PL',
    'privileged leave': 'PL',
    'privilege': 'PL',
    'annual leave': 'AL',
    'annual': 'AL',
    'maternity leave': 'ML',
    'maternity': 'ML',
    'paternity leave': 'PT',
    'paternity': 'PT',
    'compensatory off': 'CO',
    'compensatory leave': 'CO',
    'comp off': 'CO',
    'comp-off': 'CO',
    'compoff': 'CO',
    'loss of pay': 'LOP',
    'lop': 'LOP',
    'unpaid leave': 'UL',
    'unpaid': 'UL',
    'restricted holiday': 'RH',
    'optional holiday': 'OH',
    'bereavement leave': 'BL',
    'marriage leave': 'MR',
    'half day': 'HD',
  };

  static const Map<String, Color> _knownLeaveColors = {
    'CL': Color(0xFF7C3AED),
    'SL': Color(0xFFDB2777),
    'EL': Color(0xFF2563EB),
    'PL': Color(0xFF4F46E5),
    'AL': Color(0xFF1D4ED8),
    'ML': Color(0xFFBE185D),
    'PT': Color(0xFF9333EA),
    'CO': Color(0xFFEA580C),
    'LOP': Color(0xFF64748B),
    'UL': Color(0xFF78716C),
    'RH': Color(0xFFC026D3),
    'OH': Color(0xFFD946EF),
    'BL': Color(0xFF9F1239),
    'MR': Color(0xFFC2410C),
    'HD': Color(0xFF7E22CE),
  };

  static const List<Color> _leaveFallback = [
    Color(0xFF7C3AED),
    Color(0xFFDB2777),
    Color(0xFF2563EB),
    Color(0xFFEA580C),
    Color(0xFF4F46E5),
    Color(0xFFBE185D),
    Color(0xFF9333EA),
    Color(0xFFC2410C),
  ];

  static const List<Color> _holidayPalette = [
    Color(0xFF0891B2),
    Color(0xFF0E7490),
    Color(0xFF155E75),
    Color(0xFF06B6D4),
    Color(0xFF0F766E),
  ];

  static const Set<String> _skipWords = {
    'leave',
    'day',
    'days',
    'of',
    'the',
    'and',
    'a',
    'an',
  };

  static String leaveCode(String raw) {
    final extracted = _codeInParentheses(raw);
    if (extracted != null) return extracted;

    final core = _coreName(raw);
    if (core.isEmpty) return 'LV';

    final known = _knownLeaveCodes[core];
    if (known != null) return known;

    final withoutLeave = core.replaceFirst(RegExp(r'\s+leave$'), '').trim();
    if (withoutLeave.isNotEmpty) {
      final mapped = _knownLeaveCodes[withoutLeave] ??
          _knownLeaveCodes['$withoutLeave leave'];
      if (mapped != null) return mapped;
    }

    if (RegExp(r'^[a-z0-9]{1,4}$').hasMatch(core)) {
      return core.toUpperCase();
    }

    return _initials(core, fallback: 'LV');
  }

  static String holidayCode(String raw) {
    final extracted = _codeInParentheses(raw);
    if (extracted != null) return extracted;

    final core = _coreName(raw);
    if (core.isEmpty || core == 'holiday') return 'H';

    if (RegExp(r'^[a-z0-9]{1,4}$').hasMatch(core)) {
      return core.toUpperCase();
    }

    return _initials(core, fallback: 'H');
  }

  static String displayName(String raw) {
    var text = raw.trim();
    text = text.replaceAll(RegExp(r'\s*\(half[-\s]?day.*\)$', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.isEmpty ? raw.trim() : text;
  }

  static Color leaveColor(String raw) {
    final code = leaveCode(raw);
    return _knownLeaveColors[code] ??
        _leaveFallback[_stableIndex(code, _leaveFallback.length)];
  }

  static Color holidayColor([String? raw]) {
    final name = (raw ?? '').trim();
    if (name.isEmpty) return holidayCategory;
    return _holidayPalette[_stableIndex(holidayCode(name), _holidayPalette.length)];
  }

  static List<({String label, Color color})> uniqueLegend({
    required Iterable<String> leaveNames,
    required Iterable<String> holidayNames,
  }) {
    final seen = <String>{};
    final items = <({String label, Color color})>[];

    for (final name in leaveNames) {
      final trimmed = name.trim();
      if (trimmed.isEmpty) continue;
      final code = leaveCode(trimmed);
      if (!seen.add('L:$code')) continue;
      items.add((label: code, color: leaveColor(trimmed)));
    }

    for (final name in holidayNames) {
      final trimmed = name.trim();
      if (trimmed.isEmpty) continue;
      final code = holidayCode(trimmed);
      if (!seen.add('H:$code')) continue;
      items.add((label: code, color: holidayColor(trimmed)));
    }

    return items;
  }

  static Color? typeColor({String? leaveName, String? holidayName}) {
    final holiday = holidayName?.trim() ?? '';
    if (holiday.isNotEmpty) return holidayColor(holiday);

    final leave = leaveName?.trim() ?? '';
    if (leave.isNotEmpty) return leaveColor(leave);

    return null;
  }

  static String? _codeInParentheses(String raw) {
    final match = RegExp(r'\(([A-Za-z0-9]{1,5})\)\s*$').firstMatch(raw.trim());
    if (match == null) return null;
    return match.group(1)!.toUpperCase();
  }

  static String _coreName(String raw) {
    var text = raw.trim();
    text = text.replaceAll(RegExp(r'\s*\(half[-\s]?day.*\)$', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'\s*\(([A-Za-z0-9]{1,5})\)\s*$'), '');
    return text.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
  }

  static String _initials(String core, {required String fallback}) {
    final words = core
        .split(RegExp(r'[\s\-/,]+'))
        .where((w) => w.isNotEmpty && !_skipWords.contains(w))
        .toList();

    if (words.isEmpty) return fallback;
    if (words.length == 1) {
      final word = words.first;
      if (word.length <= 3) return word.toUpperCase();
      return word.substring(0, 2).toUpperCase();
    }

    return words.take(3).map((w) => w[0].toUpperCase()).join();
  }

  static int _stableIndex(String key, int length) {
    var hash = 0;
    for (final unit in key.codeUnits) {
      hash = 0x1fffffff & (hash * 31 + unit);
    }
    return hash.abs() % length;
  }
}
