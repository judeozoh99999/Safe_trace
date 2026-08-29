import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'payment_pending_screen.dart';

class TransferPaymentScreen extends StatefulWidget {
  final String planId;
  final String planName;
  final int amount;
  final String billingPeriod;

  const TransferPaymentScreen({
    super.key,
    required this.planId,
    required this.planName,
    required this.amount,
    required this.billingPeriod,
  });

  @override
  State<TransferPaymentScreen> createState() => _TransferPaymentScreenState();
}

class _TransferPaymentScreenState extends State<TransferPaymentScreen> {
  bool _isProcessing = false;

  Future<void> _handleCompleteSubscription() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to complete subscription.')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final refStr = 'STR_${DateTime.now().millisecondsSinceEpoch}';

      // 1. Record pending_plan on user document
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      try {
        await userDocRef.set({
          'pending_plan': widget.planId,
          'pending_payment_reference': refStr,
          'pending_payment_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[SUBSCRIPTION] Pending plan write note: $e');
      }

      // 2. Call Cloud Function to initiate ₦0 transaction / virtual account
      try {
        final callable = FirebaseFunctions.instanceFor(region: 'europe-west3').httpsCallable('createOrGetVirtualAccount');
        await callable.call({
          'reference': refStr,
          'plan_id': widget.planId,
          'amount': 0,
          'email': user.email ?? '${user.uid}@safetrace.app',
        });
      } catch (cfErr) {
        debugPrint('[SUBSCRIPTION] createOrGetVirtualAccount Cloud Function note: $cfErr');
      }

      // Also trigger verifyPaystackPayment in background for ₦0 plan instant webhook processing
      unawaited(() async {
        try {
          final verifyCallable = FirebaseFunctions.instanceFor(region: 'europe-west3').httpsCallable('verifyPaystackPayment');
          await verifyCallable.call({
            'reference': refStr,
            'plan_id': widget.planId,
            'amount': 0,
          });
        } catch (e) {
          debugPrint('[SUBSCRIPTION] verifyPaystackPayment note: $e');
        }
      }());

      if (!mounted) return;

      // 3. Navigate immediately to PaymentPendingScreen to wait for the real webhook confirmation
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PaymentPendingScreen(
            planId: widget.planId,
            planName: widget.planName,
            amount: 0,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initiating subscription: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1117) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F1117) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : const Color(0xFF111827),
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Complete Payment',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Plan Summary Card showing ₦0 ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1D27) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2E3347) : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.planName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '₦0',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.billingPeriod,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── 2. Instructions Section for ₦0 ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF12141C) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2E3347) : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Tap the Complete Subscription button below to activate your SafeTrace Plus subscription. No payment is required at this time.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── 3. Complete Subscription Button ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: _isProcessing ? null : _handleCompleteSubscription,
                  child: _isProcessing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Complete Subscription',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
