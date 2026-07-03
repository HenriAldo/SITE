import 'package:shared_preferences/shared_preferences.dart';

/// Tracks, per signed-in user, the most recent clinician-review timestamp
/// the patient has already seen — used to badge new in-app notifications
/// without needing any backend infrastructure.
class NotificationPrefs {
  NotificationPrefs._();

  static String _key(String userId) => 'last_seen_review_ts_$userId';

  static Future<DateTime?> getLastSeen(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_key(userId));
    return millis != null ? DateTime.fromMillisecondsSinceEpoch(millis) : null;
  }

  static Future<void> setLastSeen(String userId, DateTime timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key(userId), timestamp.millisecondsSinceEpoch);
  }
}
