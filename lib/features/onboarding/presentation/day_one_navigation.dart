import 'package:flutter/material.dart';
import 'package:lms/features/onboarding/data/day_one_route.dart';
import 'package:lms/features/onboarding/data/models/day_one_models.dart';

void openDayOneStep(BuildContext context, DayOneStep item) {
  if (item.action == DayOneAction.password) return;

  final uri = parseDayOneRoute(item.route);
  final path = uri.path;
  final tour = uri.queryParameters['tour'];

  if (path == '/my-details') {
    Navigator.pushNamed(context, '/profile');
    return;
  }

  if (path.startsWith('/attendance')) {
    Navigator.pushNamed(
      context,
      '/mark-attendance',
      arguments: {'tour': tour ?? 'attendance'},
    );
    return;
  }

  if (path.startsWith('/leaves')) {
    Navigator.pushNamed(
      context,
      '/leave-balance',
      arguments: {'tour': tour ?? 'leave'},
    );
    return;
  }

  if (path.startsWith('/policies')) {
    Navigator.pushNamed(
      context,
      '/policies',
      arguments: {'tour': tour ?? 'policies'},
    );
  }
}
