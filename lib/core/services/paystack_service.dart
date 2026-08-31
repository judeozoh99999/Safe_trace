import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_paystack_plus/flutter_paystack_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../constants/subscription_constants.dart';
import '../../features/profile/screens/subscription_success_screen.dart';

/// Central Paystack Payment Service
class PaystackService {
  static String get publicKey {
    final testKey = dotenv.env['PAYSTACK_PUBLIC_KEY_TEST'] ??
        dotenv.env['PAYSTACK_PUBLIC_KEY'] ?? '';
    final liveKey = dotenv.env['PAYSTACK_PUBLIC_KEY_LIVE'] ?? '';
    return SubscriptionConstants.isTestMode
        ? testKey
        : (liveKey.isNotEmpty ? liveKey : testKey);
  }

  static String get secretKey {
    return dotenv.env['PAYSTACK_SECRET_KEY'] ?? '';
  }

  /// Generates a unique transaction reference: ST-{epoch_ms}-{6 random uppercase letters}
  static String generateReference() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final random = Random.secure();
    final suffix =
        List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
    return 'ST-${DateTime.now().millisecondsSinceEpoch}-$suffix';
  }

  /// Calls the Cloud Function to activate subscription via Admin SDK.
  /// This bypasses all Firestore security rules.
  static Future<DateTime> _activateViaCloudFunction({
    required String planId,
    required String reference,
    required int amountInKobo,
  }) async {
    debugPrint('[PAYSTACK_CF] Calling activateSubscriptionAfterPayment...');
    debugPrint('[PAYSTACK_CF] Plan: $planId | Ref: $reference');

    final callable = FirebaseFunctions.instanceFor(region: 'europe-west3')
        .httpsCallable('activateSubscriptionAfterPayment');

    final result = await callable.call({
      'planId': planId,
      'reference': reference,
      'amountInKobo': amountInKobo,
    });

    final data = result.data as Map<dynamic, dynamic>;
    debugPrint('[PAYSTACK_CF] Result: $data');

    if (data['success'] == true) {
      final expiresIso = data['expiresAt']?.toString();
      if (expiresIso != null) {
        return DateTime.parse(expiresIso);
      }
    }

    // Fallback: compute expiry locally
    final isAnnual = planId.contains('annual');
    return DateTime.now().add(Duration(days: isAnnual ? 365 : 30));
  }

  /// Initiates the Paystack checkout flow
  static Future<void> startCheckout({
    required BuildContext context,
    required String planId,
    required String planName,
    required int amountInKobo,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to subscribe.')),
      );
      return;
    }

    // 1. Get email from Auth or Firestore
    String userEmail = user.email ?? '';
    if (userEmail.isEmpty) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        userEmail = (userDoc.data()?['email'] ?? '').toString().trim();
      } catch (_) {}
    }
    if (userEmail.isEmpty) {
      userEmail =
          '${user.uid.substring(0, min(8, user.uid.length))}@safetrace.app';
    }

    // 2. Determine plan code
    final isAnnual = planId == 'plus_annual';
    final planCode = isAnnual
        ? SubscriptionConstants.annualPlanCode
        : SubscriptionConstants.monthlyPlanCode;

    // 3. Generate unique reference
    final reference = generateReference();

    debugPrint('[PAYSTACK] ========== CHECKOUT START ==========');
    debugPrint('[PAYSTACK] UID:       ${user.uid}');
    debugPrint('[PAYSTACK] Email:     $userEmail');
    debugPrint('[PAYSTACK] Amount:    $amountInKobo kobo');
    debugPrint('[PAYSTACK] PlanCode:  $planCode');
    debugPrint('[PAYSTACK] Reference: $reference');
    debugPrint(
        '[PAYSTACK] PublicKey: ${publicKey.substring(0, min(15, publicKey.length))}...');

    // 4. Store pending reference & plan in Firestore before popup
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'pending_transaction_reference': reference,
        'pending_plan': planId,
        'pending_plan_code': planCode,
        'pending_amount': amountInKobo ~/ 100,
        'pending_currency': 'NGN',
        'pending_created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('[PAYSTACK] Pending transaction stored in Firestore.');
    } catch (e) {
      debugPrint('[PAYSTACK] Warning storing pending: $e');
    }

    if (!context.mounted) return;

    // 5. Open Paystack Popup
    try {
      await FlutterPaystackPlus.openPaystackPopup(
        publicKey: publicKey,
        context: context,
        secretKey: secretKey,
        currency: 'NGN',
        customerEmail: userEmail,
        amount: amountInKobo.toString(),
        reference: reference,
        plan: planCode,
        callBackUrl:
            'https://europe-west3-safetrace-b2aeb.cloudfunctions.net/onSubscriptionPaymentConfirmed',
        onClosed: () {
          debugPrint('[PAYSTACK] Popup closed by user (no payment).');
        },
        onSuccess: () async {
          debugPrint('[PAYSTACK] onSuccess fired! Reference: $reference');
          debugPrint('[PAYSTACK] Calling Cloud Function to activate subscription...');

          try {
            // ── Call Admin SDK Cloud Function — bypasses Firestore rules ──
            final expiresAt = await _activateViaCloudFunction(
              planId: planId,
              reference: reference,
              amountInKobo: amountInKobo,
            );

            debugPrint('[PAYSTACK] Subscription activated! Expires: $expiresAt');

            if (context.mounted) {
              // Navigate to success screen, clearing the nav stack
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) =>
                      SubscriptionSuccessScreen(expiryDate: expiresAt),
                ),
                (route) => route.isFirst,
              );
            }
          } catch (e) {
            debugPrint('[PAYSTACK] Cloud Function activation error: $e');
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Payment successful but activation failed: $e\nPlease contact support.',
                  ),
                  duration: const Duration(seconds: 8),
                  backgroundColor: Colors.red[800],
                ),
              );
            }
          }
        },
      );
    } catch (e) {
      debugPrint('[PAYSTACK] Checkout popup error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment error: $e')),
        );
      }
    }
  }
}
