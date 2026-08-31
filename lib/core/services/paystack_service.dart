import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_paystack_plus/flutter_paystack_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/subscription_constants.dart';
import '../../features/profile/screens/payment_pending_screen.dart';

/// Central Paystack Payment Service
class PaystackService {
  static String get publicKey {
    final testKey = dotenv.env['PAYSTACK_PUBLIC_KEY_TEST'] ?? dotenv.env['PAYSTACK_PUBLIC_KEY'] ?? '';
    final liveKey = dotenv.env['PAYSTACK_PUBLIC_KEY_LIVE'] ?? '';
    return SubscriptionConstants.isTestMode ? testKey : (liveKey.isNotEmpty ? liveKey : testKey);
  }

  static String get secretKey {
    return dotenv.env['PAYSTACK_SECRET_KEY'] ?? '';
  }

  /// Generates a unique transaction reference formatted as:
  /// ST-{epoch_ms}-{6 random uppercase letters}
  static String generateReference() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final random = Random.secure();
    final randomSuffix = List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
    return 'ST-${DateTime.now().millisecondsSinceEpoch}-$randomSuffix';
  }

  /// Initiates the Paystack checkout flow
  static Future<void> startCheckout({
    required BuildContext context,
    required String planId, // 'plus_monthly' or 'plus_annual'
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

    // 1. Get email from Firestore or Auth
    String userEmail = user.email ?? '';
    if (userEmail.isEmpty) {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        userEmail = (userDoc.data()?['email'] ?? '').toString().trim();
      } catch (_) {}
    }

    if (userEmail.isEmpty) {
      userEmail = '${user.uid.substring(0, min(8, user.uid.length))}@safetrace.app';
    }

    // 2. Determine plan code
    final isAnnual = planId == 'plus_annual';
    final planCode = isAnnual
        ? SubscriptionConstants.annualPlanCode
        : SubscriptionConstants.monthlyPlanCode;

    // 3. Generate unique reference
    final reference = generateReference();

    debugPrint('[PAYSTACK] Initiating payment ->');
    debugPrint('[PAYSTACK] User UID: ${user.uid}');
    debugPrint('[PAYSTACK] Email: $userEmail');
    debugPrint('[PAYSTACK] Amount: $amountInKobo kobo');
    debugPrint('[PAYSTACK] Plan Code: $planCode');
    debugPrint('[PAYSTACK] Reference: $reference');
    debugPrint('[PAYSTACK] Public Key: ${publicKey.substring(0, min(10, publicKey.length))}...');

    // 4. Store pending reference & plan in Firestore before popup
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'pending_transaction_reference': reference,
        'pending_plan': planId,
        'pending_plan_code': planCode,
        'pending_amount': amountInKobo ~/ 100,
        'pending_currency': 'NGN',
        'pending_created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('[PAYSTACK] Stored pending transaction on Firestore user document.');
    } catch (e) {
      debugPrint('[PAYSTACK] Warning storing pending transaction: $e');
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
        callBackUrl: 'https://europe-west3-safetrace-b2aeb.cloudfunctions.net/onSubscriptionPaymentConfirmed',
        onClosed: () {
          debugPrint('[PAYSTACK] Checkout popup closed by user.');
        },
        onSuccess: () {
          debugPrint('[PAYSTACK] Checkout popup reported success for reference: $reference');
          if (context.mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PaymentPendingScreen(
                  planId: planId,
                  planName: planName,
                  amount: amountInKobo ~/ 100,
                  transactionReference: reference,
                ),
              ),
            );
          }
        },
      );
    } catch (e) {
      debugPrint('[PAYSTACK] Error during checkout popup: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment error: $e')),
        );
      }
    }
  }
}
