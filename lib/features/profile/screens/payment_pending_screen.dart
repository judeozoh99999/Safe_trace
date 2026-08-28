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

  const PaymentPendingScreen({
    super.key,
    required this.planId,
    required this.planName,
    required this.amount,
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

    // 2. Start timer counting up
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds++;
        if (_elapsedSeconds >= 900) { // 15 minutes = 900 seconds
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
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west3').httpsCallable('verifyPaystackPayment');
      final result = await callable.call();

      final data = result.data as Map<dynamic, dynamic>?;
      if (data != null && data['success'] == true) {
        // Active! Listener will navigate automatically or handle here
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment verified! Activating subscription...')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transfer not confirmed by Paystack yet. Please wait a moment.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification check failed: $e')),
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
                  child: const Icon(
                    Icons.hourglass_top_rounded,
                    color: Color(0xFFEF4444),
                    size: 44,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Heading
              Text(
                'Waiting for Payment Confirmation',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),

              const SizedBox(height: 12),

              // Body text
              Text(
                'We are waiting to confirm your transfer. This usually takes 1 to 5 minutes. Keep the app open.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
              ),

              const SizedBox(height: 24),

              // Live Timer Count
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1D27) : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _formatTimer(_elapsedSeconds),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Pulsing status indicator reading "Listening for your transfer..."
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF16A34A),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Listening for your transfer...',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 15-Minute Timeout Banner
              if (_isTimedOut) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Transfer not detected yet. If you have already paid please wait a few more minutes or contact support.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _elapsedSeconds = 0;
                                _isTimedOut = false;
                              });
                            },
                            child: const Text('Retry'),
                          ),
                          const SizedBox(width: 12),
                          TextButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Support email: support@safetrace.app')),
                              );
                            },
                            child: const Text('Contact Support'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              const Spacer(),

              // Check Status Manually Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: _isManualChecking ? null : _checkStatusManually,
                  child: _isManualChecking
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text(
                          'Check Status Manually',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                ),
              ),

              const SizedBox(height: 12),

              // I Will Do This Later text button
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'I Will Do This Later',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
