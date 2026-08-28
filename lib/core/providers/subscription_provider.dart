import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/subscription_service.dart';

/// Real-time stream of the current user's subscription info.
/// Updates automatically whenever the Firestore user doc changes.
final subscriptionProvider = StreamProvider<SubscriptionInfo>((ref) {
  return SubscriptionService.subscriptionStream();
});

/// Synchronous subscription info provider (returns current value or SubscriptionInfo.free).
final currentSubscriptionProvider = Provider<SubscriptionInfo>((ref) {
  final asyncSub = ref.watch(subscriptionProvider);
  return asyncSub.valueOrNull ?? SubscriptionInfo.free;
});
