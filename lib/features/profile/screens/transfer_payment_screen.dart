import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../core/constants/subscription_constants.dart';
import 'subscription_success_screen.dart';
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

  Future<void> _handleIHavePaid() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to complete subscription.')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      if (SUBSCRIPTION_TEST_MODE) {
        // ── TEST MODE: Instant Activation ──
        final bool isAnnual = widget.planId == 'plus_annual';
        final expiresAt = DateTime.now().add(Duration(days: isAnnual ? 365 : 30));
        final refStr = 'STR_TEST_${DateTime.now().millisecondsSinceEpoch}';

        // 1. Execute Cloud Function (Admin SDK privileges, 100% bypasses rules)
        try {
          final callable = FirebaseFunctions.instanceFor(region: 'europe-west3').httpsCallable('verifyPaystackPayment');
          await callable.call({
            'reference': refStr,
            'plan_id': widget.planId,
            'amount': widget.amount,
          });
        } catch (cfErr) {
          debugPrint('[TEST_MODE] Cloud Function call warning: $cfErr');
        }

        // 2. Direct Firestore update as client fallback
        try {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'subscription_tier': 'plus',
            'subscription_active': true,
            'subscription_plan': widget.planId,
            'subscription_start': FieldValue.serverTimestamp(),
            'subscription_started_at': FieldValue.serverTimestamp(),
            'subscription_expires': Timestamp.fromDate(expiresAt),
            'subscription_expires_at': Timestamp.fromDate(expiresAt),
            'auto_renew': false,
            'cancellation_requested': false,
            'cancellation_requested_at': null,
            'subscription_cancelled': false,
            'paystack_reference': refStr,
            'subscription_amount': widget.amount,
          }, SetOptions(merge: true));

          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('notifications')
              .add({
            'title': 'SafeTrace Plus Activated',
            'body': 'Your SafeTrace Plus subscription is now active. Enjoy unlimited access.',
            'notification_type': 'subscription_activated',
            'timestamp': FieldValue.serverTimestamp(),
            'created_at': FieldValue.serverTimestamp(),
          });
        } catch (clientErr) {
          debugPrint('[TEST_MODE] Client Firestore write warning: $clientErr');
        }

        if (!mounted) return;

        // 3. Navigate immediately to SubscriptionSuccessScreen clearing payment stack
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => SubscriptionSuccessScreen(expiryDate: expiresAt),
          ),
          (route) => route.isFirst,
        );
        return;
      }

      // ── NORMAL / PRODUCTION MODE: Go to Payment Pending Screen ──
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PaymentPendingScreen(
            planId: widget.planId,
            planName: widget.planName,
            amount: widget.amount,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error activating subscription: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formattedAmount = '₦${widget.amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

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
                    Text(
                      formattedAmount,
                      style: const TextStyle(
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

              const SizedBox(height: 20),

              // ── 2. How to Pay Section ──
              Text(
                'How to Pay',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF12141C) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildStepRow('1', 'Open your banking app or USSD.', isDark),
                    const SizedBox(height: 10),
                    _buildStepRow('2', 'Transfer exactly the amount shown above to the account below.', isDark),
                    const SizedBox(height: 10),
                    _buildStepRow('3', 'Return to SafeTrace — your subscription activates automatically.', isDark),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── 3. Bank Account Details Card ──
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1D27) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2E3347) : const Color(0xFFE5E7EB),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TEST MODE Amber Banner (ONLY when SUBSCRIPTION_TEST_MODE is true)
                    if (SUBSCRIPTION_TEST_MODE) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        color: const Color(0xFFF59E0B).withOpacity(0.18),
                        child: Row(
                          children: const [
                            Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'TEST MODE — Tap I Have Paid to activate instantly without transferring',
                                style: TextStyle(
                                  color: Color(0xFFF59E0B),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bank Name',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            bankName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                          ),

                          const SizedBox(height: 14),

                          Text(
                            'Account Number',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            accountNumber,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                          ),

                          const SizedBox(height: 14),

                          Text(
                            'Account Name',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            accountName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Copy Account Number Button
                          SizedBox(
                            width: double.infinity,
                            height: 42,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => _copyToClipboard(accountNumber, 'Account number'),
                              icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFFEF4444)),
                              label: const Text(
                                'Copy Account Number',
                                style: TextStyle(
                                  color: Color(0xFFEF4444),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── 4. Warning Card in Amber ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Transfer exactly the correct amount. Sending a different amount may delay activation.',
                        style: TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── 5. I Have Paid Button ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: _isProcessing ? null : _handleIHavePaid,
                  child: _isProcessing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          SUBSCRIPTION_TEST_MODE ? 'I Have Paid — Test Mode' : 'I Have Paid',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // ── 6. Contact Support Link ──
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
