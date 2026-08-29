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
  final int locationLogsThisMonth;

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
    this.locationLogsThisMonth = 0,
  });

  /// Section 4: isPlus returns true ONLY when subscription_active is boolean true
  /// AND subscription_tier is string plus AND subscription_expires is in the future.
  bool get isPlus =>
      tier == 'plus' &&
      isActive &&
      expiresAt != null &&
      expiresAt!.isAfter(DateTime.now());

  /// Section 4: isFree returns true when isPlus is false.
  bool get isFree => !isPlus;

  /// Section 4: locationLogsRemainingThisMonth returns (10 - location_logs_this_month) for free users.
  /// For Plus users returns null (unlimited).
  int? get locationLogsRemainingThisMonth {
    if (isPlus) return null; // Unlimited for Plus users
    final remaining = 10 - locationLogsThisMonth;
    return remaining < 0 ? 0 : remaining;
  }

  /// Section 4: trustedContactsLimit returns 3 for free users, 5 for Plus users.
  int get trustedContactsLimit => isPlus ? 5 : 3;

  /// Section 4: locationHistoryDays returns 7 for free users, 90 for Plus users.
  int get locationHistoryDays => isPlus ? 90 : 7;

  /// Section 4: recentActivityLimit returns 5 for free users, 100 for Plus users.
  int get recentActivityLimit => isPlus ? 100 : 5;

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

  /// Stream that emits subscription info whenever the auth user or user doc changes.
  static Stream<SubscriptionInfo> subscriptionStream() {
    return FirebaseAuth.instance.userChanges().asyncExpand((user) {
      if (user == null) {
        debugPrint('[SUBSCRIPTION_STREAM] Auth user is null -> emitting free info');
        return Stream.value(SubscriptionInfo.free);
      }

      debugPrint('[SUBSCRIPTION_STREAM] Listening to Firestore user doc: users/${user.uid}');
      return FirebaseFirestore.instance
          .collection(_collection)
          .doc(user.uid)
          .snapshots()
          .map((snap) {
        if (!snap.exists || snap.data() == null) {
          debugPrint('[SUBSCRIPTION_STREAM] Snapshot received: Document does not exist');
          return SubscriptionInfo.free;
        }
        final info = _parseDoc(snap.data()!);
        debugPrint(
          '[SUBSCRIPTION_STREAM] Snapshot received -> '
          'subscription_active: ${snap.data()!['subscription_active']}, '
          'subscription_tier: ${snap.data()!['subscription_tier']}, '
          'isPlus: ${info.isPlus}, expiresAt: ${info.expiresAt}',
        );
        return info;
      });
    }).handleError((e) {
      debugPrint('[SUBSCRIPTION_STREAM] Stream error: $e');
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

    final isActuallyActive = tier == 'plus' && active && (expiresAt != null && expiresAt.isAfter(DateTime.now()));

    final logsThisMonth = data['location_logs_this_month'] is num
        ? (data['location_logs_this_month'] as num).toInt()
        : 0;

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
      locationLogsThisMonth: logsThisMonth,
    );
  }

  /// Legacy helper used by SentinelProvider etc.
  static Future<String> getUserTier() async {
    final info = await getSubscriptionInfo();
    return info.tier;
  }
}
