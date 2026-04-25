import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/network_providers.dart';
import '../../data/models/attendance_day_data.dart';

//////////////////////////////////////////////////////////////
// PARAMS
//////////////////////////////////////////////////////////////

class AttendanceParams {
  final String userId;
  final DateTime month;

  const AttendanceParams({required this.userId, required this.month});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttendanceParams &&
          userId == other.userId &&
          month.year == other.month.year &&
          month.month == other.month.month;

  @override
  int get hashCode =>
      userId.hashCode ^ month.year.hashCode ^ month.month.hashCode;
}

//////////////////////////////////////////////////////////////
// SAFE DATE NORMALIZER
//////////////////////////////////////////////////////////////

String _normalizeDate(dynamic rawDate) {
  try {
    if (rawDate == null) return '';

    if (rawDate is String) {
      final value = rawDate.trim();
      if (value.isEmpty) return '';

      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return DateFormat('yyyy-MM-dd').format(parsed.toLocal());
      }

      return value;
    }

    if (rawDate is Map<String, dynamic>) {
      if (rawDate.containsKey('date')) return _normalizeDate(rawDate['date']);
      if (rawDate.containsKey('value')) return _normalizeDate(rawDate['value']);
    }

    return _normalizeDate(rawDate.toString());
  } catch (_) {
    return '';
  }
}

//////////////////////////////////////////////////////////////
// PROVIDER (WITH DEBUG LOGS)
//////////////////////////////////////////////////////////////

final employeeAttendanceProvider =
    FutureProvider.family<Map<String, AttendanceDayData>, AttendanceParams>((
      ref,
      params,
    ) async {
      try {
        final api = ref.read(apiServiceProvider);

        //////////////////////////////////////////////////////////
        // 1️⃣ FETCH ATTENDANCE (sessions + aggregates)
        //////////////////////////////////////////////////////////

        final attendanceRes = await api.get(
          'attendance',
          queryParams: {
            'month': params.month.month,
            'year': params.month.year,
            if (params.userId.isNotEmpty) 'userId': params.userId,
          },
        );

        final sessions = (attendanceRes['sessions'] as List?) ?? [];
        final aggregates = (attendanceRes['aggregates'] as List?) ?? [];

        //////////////////////////////////////////////////////////
        // 2️⃣ FETCH SUMMARY (days + summary)
        //////////////////////////////////////////////////////////

        final monthStr =
            "${params.month.year}-${params.month.month.toString().padLeft(2, '0')}";

        final summaryRes = await api.get(
          'attendance/summary',
          queryParams: {
            'month': monthStr,
            if (params.userId.isNotEmpty) 'userId': params.userId,
          },
        );

        final days = (summaryRes['days'] as List?) ?? [];

        //////////////////////////////////////////////////////////
        // 3️⃣ GROUP SESSIONS BY DATE
        //////////////////////////////////////////////////////////

        final Map<String, List> sessionsByDate = {};

        for (final session in sessions) {
          final date = _normalizeDate(
            session['date'] ?? session['checkInTime'] ?? session['checkOutTime'],
          );
          if (date.isEmpty) continue;

          sessionsByDate.putIfAbsent(date, () => []);
          sessionsByDate[date]!.add(session);
        }

        //////////////////////////////////////////////////////////
        // 4️⃣ CREATE RESULT MAP (FROM DAYS FIRST ✅)
        //////////////////////////////////////////////////////////

        final Map<String, AttendanceDayData> result = {};

        for (final d in days) {
          final date = _normalizeDate(d['date']);
          if (date.isEmpty) continue;

          final daySessions = sessionsByDate[date] ?? [];

          result[date] = AttendanceDayData.fromJson(
            aggregate: {
              'date': date,
              // "fullWorked" from summary.days is actual worked minutes.
              // "workCredit" is a day-credit flag (0/1), not minutes.
              'totalMinutes':
                  d['fullWorked'] ?? d['totalMinutes'] ?? d['workCredit'] ?? 0,
              'status': d['status'], // ✅ REAL STATUS
            },
            sessionsJson: daySessions,
          );
        }

        //////////////////////////////////////////////////////////
        // 5️⃣ FALLBACK: ADD MISSING AGGREGATES (if any)
        //////////////////////////////////////////////////////////

        for (final agg in aggregates) {
          final date = _normalizeDate(agg['date']);
          if (date.isEmpty) continue;

          if (result.containsKey(date)) continue;

          final daySessions = sessionsByDate[date] ?? [];

          result[date] = AttendanceDayData.fromJson(
            aggregate: {
              'date': date,
              'totalMinutes': agg['totalMinutes'] ?? 0,
              'status': agg['status'] ?? 'Unknown',
            },
            sessionsJson: daySessions,
          );
        }

        //////////////////////////////////////////////////////////
        // DONE ✅
        //////////////////////////////////////////////////////////

        return result;
      } catch (e) {
        print("❌ ERROR in employeeAttendanceProvider: $e");
        return {};
      }
    });

final employeeAttendanceSummaryProvider =
    FutureProvider.family<Map<String, dynamic>, AttendanceParams>((
      ref,
      params,
    ) async {
      try {
        final api = ref.read(apiServiceProvider);

        final monthStr =
            "${params.month.year}-${params.month.month.toString().padLeft(2, '0')}";

        final res = await api.get(
          'attendance/summary',
          queryParams: {
            'month': monthStr,
            if (params.userId.isNotEmpty) 'userId': params.userId,
          },
        );

        return res['summary'] ?? {};
      } catch (e) {
        print("❌ ERROR in summary provider: $e");
        return {};
      }
    });
