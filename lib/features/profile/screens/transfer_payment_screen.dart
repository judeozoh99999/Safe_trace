import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/subscription_constants.dart';
import '../../../core/services/paystack_service.dart';
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
  static const String bankName = 'Wema Bank / Paystack';
  static const String accountNumber = '0123456789';
  static const String accountName = 'SafeTrace Safety / Paystack';

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handlePaystackCheckout() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to complete subscription.')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final amountInKobo = SubscriptionConstants.isTestMode
          ? SubscriptionConstants.testPriceInKobo
          : (widget.amount * 100);

      await PaystackService.startCheckout(
        context: context,
        planId: widget.planId,
        planName: widget.planName,
        amountInKobo: amountInKobo,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment initiation failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayAmount = SubscriptionConstants.isTestMode ? 100 : widget.amount;
    final formattedAmount = '₦${displayAmount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

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
              // ── 1. Plan Summary Card ──
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          formattedAmount,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.billingPeriod,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    if (SubscriptionConstants.isTestMode)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.blue.withOpacity(0.3)),
                          ),
                          child: const Text(
                            'TEST MODE: ₦100 charges using test card',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── 2. How it works / Instructions ──
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
                      'Payment Instructions',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildStepRow('1', 'Tap the "Pay with Paystack" button below.', isDark),
                    const SizedBox(height: 10),
                    _buildStepRow('2', 'Enter your card or test card details.', isDark),
                    const SizedBox(height: 10),
                    _buildStepRow('3', 'Complete verification to instantly activate your subscription.', isDark),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── 3. Test Card Info Card (When in Test Mode) ──
              if (SubscriptionConstants.isTestMode)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.credit_card_rounded, color: Color(0xFF38BDF8), size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Paystack Official Test Card',
                            style: TextStyle(
                              color: Color(0xFF38BDF8),
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Card: 4084 0840 8408 4081\nExpiry: Any future date (e.g. 12/28)\nCVV: 408   |   PIN: 0000   |   OTP: 123456',
                        style: const TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontSize: 12,
                          fontFamily: 'monospace',
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // ── 4. Pay with Paystack Button ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: _isProcessing ? null : _handlePaystackCheckout,
                  child: _isProcessing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.lock_outline_rounded, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Pay with Paystack',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // ── 5. Contact Support Link ──
              Center(
                child: GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Support email: support@safetrace.app')),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Having trouble? Contact support.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        decoration: TextDecoration.underline,
                      ),
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

  Widget _buildStepRow(String number, String text, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: Color(0xFFEF4444),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
            ),
          ),
        ),
      ],
    );
  }
}
