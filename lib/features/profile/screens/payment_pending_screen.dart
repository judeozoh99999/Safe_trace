import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'subscription_success_screen.dart';

class PaymentPendingScreen extends StatefulWidget {
  final String planId;
  final String planName;
  final int amount;
  final String? transactionReference;

  const PaymentPendingScreen({
    super.key,
    required this.planId,
    required this.planName,
    required this.amount,
    this.transactionReference,
  });

  @override
  State<PaymentPendingScreen> createState() => _PaymentPendingScreenState();
}

class _PaymentPendingScreenState extends State<PaymentPendingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _isTimedOut = false;
  bool _isManualChecking = false;

  StreamSubscription<DocumentSnapshot>? _userDocSub;

  @override
  void initState() {
    super.initState();

    // 1. Pulsing animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 2. Start timer counting up (10 min timeout = 600s)
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds++;
        if (_elapsedSeconds >= 600) { // 10 minutes = 600 seconds
          _isTimedOut = true;
          _timer?.cancel();
        }
      });
    });

    // 3. Real-time Firestore listener watching subscription_active
    _listenToUserSubscription();
  }

  void _listenToUserSubscription() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _userDocSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        final isActive = data['subscription_active'] == true;
        final tier = (data['subscription_tier'] ?? '').toString().toLowerCase();

        if (isActive && tier == 'plus') {
          _userDocSub?.cancel();
          _timer?.cancel();

          DateTime? expiresAt;
          final rawExp = data['subscription_expires_at'] ?? data['subscription_expires'];
          if (rawExp is Timestamp) {
            expiresAt = rawExp.toDate();
          } else {
            final isAnnual = widget.planId == 'plus_annual';
            expiresAt = DateTime.now().add(Duration(days: isAnnual ? 365 : 30));
          }

          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => SubscriptionSuccessScreen(expiryDate: expiresAt!),
            ),
            (route) => route.isFirst,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timer?.cancel();
    _userDocSub?.cancel();
    super.dispose();
  }

  String _formatTimer(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _checkStatusManually() async {
    setState(() => _isManualChecking = true);
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west3').httpsCallable('verifyTransactionManually');
      final result = await callable.call({
        'reference': widget.transactionReference,
      });

      final data = result.data as Map<dynamic, dynamic>?;
      if (data != null && data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment verified! Activating SafeTrace Plus...')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment not confirmed yet. Please wait a moment.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification check: $e')),
      );
    } finally {
      if (mounted) setState(() => _isManualChecking = false);
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
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.close_rounded, color: isDark ? Colors.white : const Color(0xFF111827)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),

              // Pulsing Icon Animation
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4), width: 2),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.sync_rounded,
                      size: 48,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Title
              Text(
                'Confirming Your Payment',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),

              const SizedBox(height: 12),

              // Description
              Text(
                'We are verifying your transaction with Paystack.\nThis screen will automatically update once confirmed.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
              ),

              if (widget.transactionReference != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Ref: ${widget.transactionReference}',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // Timer Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTimer(_elapsedSeconds),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                        color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Timed out warning or Manual check button
              if (_isTimedOut) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                  ),
                  child: const Text(
                    'Payment not confirmed yet. If you have completed payment, tap "Check Payment Status" below or contact support.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFF59E0B),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Manual Check Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isManualChecking ? null : _checkStatusManually,
                  child: _isManualChecking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Check Payment Status',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 12),

              // Contact Support Button
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Support email: support@safetrace.app')),
                  );
                },
                child: Text(
                  'Having issues? Contact Support',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
