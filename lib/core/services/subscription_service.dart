import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class SubscriptionInfo {
  final String tier; // 'free' or 'plus'
  final bool isActive;
  final DateTime? expiresAt;
  final String? paystackReference;
  final int? amount;

  const SubscriptionInfo({
    required this.tier,
    required this.isActive,
    this.expiresAt,
    this.paystackReference,
    this.amount,
  });

  bool get isPlus => tier == 'plus' && isActive && (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  static const free = SubscriptionInfo(tier: 'free', isActive: false);
}

class SubscriptionService {
  static const _collection = 'users';

  /// Fetches the user's subscription info from Firestore.
  static Future<SubscriptionInfo> getSubscriptionInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return SubscriptionInfo.free;

      final doc = await FirebaseFirestore.instance.collection(_collection).doc(user.uid).get();
      if (!doc.exists) return SubscriptionInfo.free;

      return _parseDoc(doc.data()!);
    } catch (e) {
      debugPrint('[SUBSCRIPTION] Error: $e');
      return SubscriptionInfo.free;
    }
  }

  /// Stream that emits subscription info whenever the user doc changes.
  static Stream<SubscriptionInfo> subscriptionStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value(SubscriptionInfo.free);
    }

    return FirebaseFirestore.instance
        .collection(_collection)
        .doc(user.uid)
        .snapshots()
        .map((snap) {
      if (!snap.exists || snap.data() == null) return SubscriptionInfo.free;
      return _parseDoc(snap.data()!);
    }).handleError((e) {
      debugPrint('[SUBSCRIPTION] Stream error: $e');
      return SubscriptionInfo.free;
    });
  }

  static SubscriptionInfo _parseDoc(Map<String, dynamic> data) {
    final tier = (data['subscription_tier'] ?? 'free').toString().toLowerCase();
    final active = data['subscription_active'] == true;

    DateTime? expiresAt;
    final rawExpiry = data['subscription_expires_at'];
    if (rawExpiry is Timestamp) {
      expiresAt = rawExpiry.toDate();
    }

    final isActuallyActive = tier == 'plus' && active && (expiresAt == null || expiresAt.isAfter(DateTime.now()));

    return SubscriptionInfo(
      tier: isActuallyActive ? 'plus' : 'free',
      isActive: isActuallyActive,
      expiresAt: expiresAt,
      paystackReference: data['paystack_reference'],
      amount: data['subscription_amount'],
    );
  }

  /// Legacy helper used by SentinelProvider etc.
  static Future<String> getUserTier() async {
    final info = await getSubscriptionInfo();
    return info.tier;
  }
}
