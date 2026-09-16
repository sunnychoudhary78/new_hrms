Uri parseDayOneRoute(String? route) {
  if (route == null || route.isEmpty) return Uri();
  return Uri.parse(route.startsWith('http') ? route : 'app://hrms$route');
}

String? tourIdFromRoute(String? route) {
  final q = parseDayOneRoute(route).queryParameters['tour'];
  if (q == null || q.isEmpty) return null;
  return q;
}

String? tourIdFromArgs(Object? args) {
  if (args is Map && args['tour'] != null) {
    final tour = args['tour'].toString().trim();
    if (tour.isNotEmpty) return tour;
  }
  return null;
}
