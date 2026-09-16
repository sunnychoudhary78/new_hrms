import 'package:shared_preferences/shared_preferences.dart';

/// Remembers, per user, that the Day-one guide was finished once so the
/// dashboard entry points never come back for that account.
class DayOneCompletionStore {
  static String _key(String userId) => 'day_one_finished_$userId';

  Future<bool> isFinished(String userId) async {
    if (userId.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(userId)) ?? false;
  }

  Future<void> markFinished(String userId) async {
    if (userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(userId), true);
  }
}
