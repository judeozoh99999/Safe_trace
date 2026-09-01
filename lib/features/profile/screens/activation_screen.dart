import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'subscription_success_screen.dart';

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _activateSubscription();
  }

  Future<void> _activateSubscription() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'User not signed in. Please log in first.';
        });
      }
      return;
    }

    final now = DateTime.now();
    final expiresAt = now.add(const Duration(days: 365));

    try {
      // 1. Refresh Auth Token to avoid stale token permission-denied errors
      try {
        await user.getIdToken(true);
      } catch (tokenErr) {
        debugPrint('[ACTIVATION_SCREEN] Token refresh warning: $tokenErr');
      }

      final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

      final subscriptionData = {
        'subscription_tier': 'plus',
        'subscription_active': true,
        'subscription_plan': 'free_claim',
        'subscription_start': FieldValue.serverTimestamp(),
        'subscription_started_at': FieldValue.serverTimestamp(),
        'subscription_expires': Timestamp.fromDate(expiresAt),
        'subscription_expires_at': Timestamp.fromDate(expiresAt),
        'auto_renew': false,
        'subscription_cancelled': false,
        'cancellation_requested': false,
        'cancellation_requested_at': null,
      };

      // 2. Write subscription to Firestore
      try {
        await userDocRef.set(subscriptionData, SetOptions(merge: true));
      } catch (setError) {
        debugPrint('[ACTIVATION_SCREEN] set() failed, trying update(): $setError');
        await userDocRef.update(subscriptionData);
      }

      // 3. Notification write (best effort)
      try {
        await userDocRef.collection('notifications').add({
          'title': 'SafeTrace Plus Activated',
          'body': 'Your free claim subscription is active. Enjoy unlimited features.',
          'notification_type': 'subscription_activated',
          'timestamp': FieldValue.serverTimestamp(),
          'created_at': FieldValue.serverTimestamp(),
        });
      } catch (notifErr) {
        debugPrint('[ACTIVATION_SCREEN] Notification write warning: $notifErr');
      }

      if (!mounted) return;

      // 4. Navigate to Success Screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SubscriptionSuccessScreen(expiryDate: expiresAt),
        ),
      );
    } catch (e) {
      debugPrint('[ACTIVATION_SCREEN] Error activating subscription: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Activation error: $e\nPlease tap Retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F1117) : const Color(0xFFF9FAFB);
    final headingColor = isDark ? Colors.white : const Color(0xFF111827);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: _isLoading
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Centered pulsing SafeTrace shield icon with gentle scale animation
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.shield_rounded,
                            size: 64,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      )
                          .animate(onPlay: (controller) => controller.repeat(reverse: true))
                          .scaleXY(begin: 0.92, end: 1.08, duration: 800.ms, curve: Curves.easeInOut),

                      const SizedBox(height: 28),

                      // Text: Activating SafeTrace Plus in dark navy
                      Text(
                        'Activating SafeTrace Plus',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: headingColor,
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.error_outline_rounded,
                          size: 48,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _errorMessage ?? 'Something went wrong. Please try again',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: headingColor,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          onPressed: _activateSubscription,
                          child: const Text(
                            'Retry',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            'Go Back',
                            style: TextStyle(
                              color: subtextColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
