import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/features/attendance/shared/utils/attendance_date_utils.dart';

import '../../data/models/attendance_session_model.dart';

final openSessionProvider =
    Provider.family<AttendanceSession?, List<AttendanceSession>>((
      ref,
      sessions,
    ) {
      return findOpenSession(sessions);
    });

/// @deprecated Use [openSessionProvider].
final activeSessionProvider = openSessionProvider;

final hasOpenSessionProvider = Provider.family<bool, List<AttendanceSession>>((
  ref,
  sessions,
) {
  return hasOpenSession(sessions);
});

final todaySessionsProvider =
    Provider.family<List<AttendanceSession>, List<AttendanceSession>>((
      ref,
      sessions,
    ) {
      return todaySessions(sessions);
    });

final canStartNewSessionProvider =
    Provider.family<bool, List<AttendanceSession>>((
      ref,
      sessions,
    ) {
      return canStartNewSession(sessions);
    });

final isStaleOpenSessionProvider =
    Provider.family<bool, List<AttendanceSession>>((
      ref,
      sessions,
    ) {
      return isStaleOpenSession(sessions);
    });
