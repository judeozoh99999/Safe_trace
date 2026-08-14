import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/subscription_service.dart';

/// Real-time stream of the current user's subscription info.
/// Updates automatically whenever the Firestore user doc changes.
final subscriptionProvider = StreamProvider<SubscriptionInfo>((ref) {
  return SubscriptionService.subscriptionStream();
});
