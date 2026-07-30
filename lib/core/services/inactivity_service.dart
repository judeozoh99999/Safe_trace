import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/panic/screens/inactivity_alert_screen.dart';

class InactivityService {
  static const String _keyLastActivity = "last_activity_timestamp";

  // Mark user activity now
  static Future<void> updateActivity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyLastActivity, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  // Check if user has been inactive for over 24 hours.
  // If inactive, route them to the check-in countdown alert.
  static Future<void> checkInactivity(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastTime = prefs.getInt(_keyLastActivity);

      if (lastTime == null) {
        await updateActivity();
        return;
      }

      final lastActiveDate = DateTime.fromMillisecondsSinceEpoch(lastTime);
      final difference = DateTime.now().difference(lastActiveDate);

      if (difference.inHours >= 24) {
        // Reset last activity now to avoid loops or repeated popups on rebuilds
        await updateActivity();

        if (context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const InactivityAlertScreen()),
          );
        }
      }
    } catch (_) {}
  }
}
