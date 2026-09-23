export 'package:lms/core/auth/auth_features.dart';

String cleanApiError(Object error) {
  return error.toString().replaceFirst('Exception: ', '');
}

String localDateTimeLabel(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $hh:$mm';
}

String hhmm(DateTime time) {
  return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

String recurrenceTimeForApi(String raw) {
  final t = raw.trim();
  if (t.length >= 5) return t.substring(0, 5);
  return t;
}
