import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/subscription_service.dart';

/// Direct stream provider of the user document snapshot from Firestore.
/// Emits a new DocumentSnapshot every time any field on users/{uid} changes.
final userDocumentStreamProvider = StreamProvider<DocumentSnapshot<Map<String, dynamic>>?>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    debugPrint('[USER_DOC_STREAM] No authenticated user found at stream creation');
    return const Stream.empty();
  }

  debugPrint('[USER_DOC_STREAM] Starting real-time Firestore stream for users/${user.uid}');
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((snap) {
    final data = snap.data();
    debugPrint(
      '[USER_DOC_STREAM] EMISSION -> '
      'exists: ${snap.exists}, '
      'subscription_active: ${data?['subscription_active']} (${data?['subscription_active']?.runtimeType}), '
      'subscription_tier: "${data?['subscription_tier']}", '
      'subscription_plan: "${data?['subscription_plan']}"',
    );
    return snap;
  });
});

/// Real-time stream of parsed SubscriptionInfo.
final subscriptionProvider = StreamProvider<SubscriptionInfo>((ref) {
  return SubscriptionService.subscriptionStream();
});

/// Synchronous subscription info provider evaluated directly from the real-time user document.
final currentSubscriptionProvider = Provider<SubscriptionInfo>((ref) {
  final docAsync = ref.watch(userDocumentStreamProvider);
  final doc = docAsync.valueOrNull;
  if (doc == null || !doc.exists || doc.data() == null) {
    return SubscriptionInfo.free;
  }
  return SubscriptionService.parseDocData(doc.data()!);
});
