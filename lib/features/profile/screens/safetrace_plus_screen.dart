import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/subscription_provider.dart';
import 'plan_selection_screen.dart';
import 'manage_subscription_screen.dart';

class SafeTracePlusScreen extends ConsumerWidget {
  const SafeTracePlusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAsync = ref.watch(subscriptionProvider);
    final sub = subAsync.valueOrNull;

    if (sub?.isPlus ?? false) {
      return const ManageSubscriptionScreen();
    }

    return const PlanSelectionScreen();
  }
}
