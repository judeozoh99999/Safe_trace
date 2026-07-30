import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class SubscriptionService {
  /// Fetches the user's subscription tier: 'basic', 'pro', or 'plus'
  static Future<String> getUserTier() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 'basic';

      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!doc.exists) return 'basic';

      final data = doc.data();
      if (data == null) return 'basic';

      final tier = data['subscription_tier'] ?? data['tier'] ?? data['plan'];
      if (tier != null && tier.toString().isNotEmpty) {
        return tier.toString().toLowerCase();
      }

      final isActive = data['subscription_active'] == true || data['subscriptionActive'] == true;
      if (isActive) {
        return 'pro';
      }
    } catch (e) {
      debugPrint("[SUBSCRIPTION_SERVICE] Error checking tier: $e");
    }
    return 'basic';
  }
}
