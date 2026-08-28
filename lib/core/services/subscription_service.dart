import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class SubscriptionInfo {
  final String tier; // 'free' or 'plus'
  final bool isActive;
  final DateTime? expiresAt;
  final DateTime? startedAt;
  final String? planId; // 'plus_monthly' or 'plus_annual'
  final String? planName;
  final bool cancellationRequested;
  final DateTime? cancellationRequestedAt;
  final bool autoRenew;
  final String? paystackReference;
  final int? amount;

  const SubscriptionInfo({
    required this.tier,
    required this.isActive,
    this.expiresAt,
    this.startedAt,
    this.planId,
    this.planName,
    this.cancellationRequested = false,
    this.cancellationRequestedAt,
    this.autoRenew = false,
    this.paystackReference,
    this.amount,
  });

  bool get isPlus => tier == 'plus' && isActive && (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  static const free = SubscriptionInfo(tier: 'free', isActive: false);

  String get formattedExpiry {
    if (expiresAt == null) return 'N/A';
    return formatDayMonthYear(expiresAt!);
  }

  String get formattedStart {
    if (startedAt == null) return 'N/A';
    return formatDayMonthYear(startedAt!);
  }

  static String formatDayMonthYear(DateTime dt) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
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
    final rawExpiry = data['subscription_expires_at'] ?? data['subscription_expires'];
    if (rawExpiry is Timestamp) {
      expiresAt = rawExpiry.toDate();
    } else if (rawExpiry is String) {
      expiresAt = DateTime.tryParse(rawExpiry);
    }

    DateTime? startedAt;
    final rawStart = data['subscription_started_at'] ?? data['subscription_start'];
    if (rawStart is Timestamp) {
      startedAt = rawStart.toDate();
    } else if (rawStart is String) {
      startedAt = DateTime.tryParse(rawStart);
    }

    final rawPlan = data['subscription_plan']?.toString();
    String? planName;
    if (rawPlan == 'plus_annual' || rawPlan == 'SafeTrace Plus Annual') {
      planName = 'SafeTrace Plus Annual';
    } else if (rawPlan == 'plus_monthly' || rawPlan == 'SafeTrace Plus Monthly') {
      planName = 'SafeTrace Plus Monthly';
    } else if (rawPlan != null && rawPlan.isNotEmpty) {
      planName = rawPlan;
    }

    final cancellationRequested = data['cancellation_requested'] == true || data['subscription_cancelled'] == true;

    DateTime? cancellationRequestedAt;
    final rawCancelAt = data['cancellation_requested_at'];
    if (rawCancelAt is Timestamp) {
      cancellationRequestedAt = rawCancelAt.toDate();
    }

    final autoRenew = data['auto_renew'] == true;

    final isActuallyActive = tier == 'plus' && active && (expiresAt == null || expiresAt.isAfter(DateTime.now()));

    return SubscriptionInfo(
      tier: isActuallyActive ? 'plus' : 'free',
      isActive: isActuallyActive,
      expiresAt: expiresAt,
      startedAt: startedAt,
      planId: rawPlan,
      planName: planName,
      cancellationRequested: cancellationRequested,
      cancellationRequestedAt: cancellationRequestedAt,
      autoRenew: autoRenew,
      paystackReference: data['paystack_reference'],
      amount: data['subscription_amount'] is int
          ? data['subscription_amount'] as int
          : int.tryParse(data['subscription_amount']?.toString() ?? ''),
    );
  }

  /// Legacy helper used by SentinelProvider etc.
  static Future<String> getUserTier() async {
    final info = await getSubscriptionInfo();
    return info.tier;
  }
}
