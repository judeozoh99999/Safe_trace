import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_paystack_plus/flutter_paystack_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/subscription_provider.dart';
import '../../../core/services/subscription_service.dart';

class SafeTracePlusScreen extends ConsumerStatefulWidget {
  const SafeTracePlusScreen({super.key});

  @override
  ConsumerState<SafeTracePlusScreen> createState() => _SafeTracePlusScreenState();
}

class _SafeTracePlusScreenState extends ConsumerState<SafeTracePlusScreen> {
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _generateRef() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    final suffix = List.generate(16, (_) => chars[rand.nextInt(chars.length)]).join();
    return 'STR_${suffix.toUpperCase()}';
  }

  Future<void> _startPayment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('You need to be signed in to subscribe.');
      return;
    }

    final email = user.email ?? '${user.uid}@safetrace.app';
    final publicKey = dotenv.env['PAYSTACK_PUBLIC_KEY'] ?? '';
    if (publicKey.isEmpty) {
      _showError('Payment configuration error. Please contact support.');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final reference = _generateRef();

      await FlutterPaystackPlus.openPaystackPopup(
        context: context,
        publicKey: publicKey,
        customerEmail: email,
        amount: '199900', // ₦1,999 in kobo
        reference: reference,
        currency: 'NGN',
        callBackUrl: 'https://safetrace.app/payment/callback',
        onClosed: () {
          if (mounted) setState(() => _isProcessing = false);
        },
        onSuccess: () async {
          await _verifyAndActivate(reference);
        },
      );
    } catch (e) {
      debugPrint('[PAYSTACK] Error: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        _showError('Payment failed. Please try again.');
      }
    }
  }

  Future<void> _verifyAndActivate(String reference) async {
    if (!mounted) return;
    setState(() => _isProcessing = true);

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('verifyPaystackPayment');
      final result = await callable.call({'reference': reference});

      final data = result.data as Map<dynamic, dynamic>;
      if (data['success'] == true && mounted) {
        _showSuccessSheet();
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[PAYSTACK] Verification error: ${e.code} — ${e.message}');
      if (mounted) _showError('Verification failed: ${e.message}. Please contact support with reference: $reference');
    } catch (e) {
      debugPrint('[PAYSTACK] Unexpected verification error: $e');
      if (mounted) _showError('Unexpected error. Contact support with reference: $reference');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFE63946),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          color: Color(0xFF0F1117),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFF16A34A),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'SafeTrace Plus Activated!',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Welcome to SafeTrace Plus. Your subscription is now active for 30 days.',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () {
                  Navigator.of(context).pop(); // Close sheet
                  Navigator.of(context).pop(); // Go back to profile
                },
                child: const Text(
                  'Start Using Plus',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subAsync = ref.watch(subscriptionProvider);

    return subAsync.when(
      data: (sub) => sub.isPlus ? _buildStatusScreen(sub) : _buildPurchaseScreen(),
      loading: () => _buildPurchaseScreen(),
      error: (e, s) => _buildPurchaseScreen(),
    );
  }

  // ─── PURCHASE SCREEN ─────────────────────────────────────────────────────────
  Widget _buildPurchaseScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top Bar ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_rounded, size: 14, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'SafeTrace Plus',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1D27),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF2E3347)),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: const Icon(Icons.close, color: Color(0xFF9CA3AF), size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // ── Hero Headline ──
                  const Text(
                    'Upgrade to\nSafeTrace Plus',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                      children: [
                        TextSpan(
                          text: '₦1,999',
                          style: TextStyle(color: Color(0xFFEF4444)),
                        ),
                        TextSpan(
                          text: ' / month',
                          style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Feature Comparison Table ──
                  _buildComparisonTable(),
                  const SizedBox(height: 28),

                  // ── Trust Badges ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTrustBadge(Icons.lock_rounded, 'Paystack Secured'),
                      const SizedBox(width: 16),
                      _buildTrustBadge(Icons.bolt_rounded, 'Instant Activation'),
                      const SizedBox(width: 16),
                      _buildTrustBadge(Icons.cancel_outlined, 'Cancel Anytime'),
                    ],
                  ),
                ],
              ),
            ),

            // ── Sticky Bottom CTA ──
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0x000F1117),
                      const Color(0xFF0F1117),
                      const Color(0xFF0F1117),
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        onPressed: _isProcessing ? null : _startPayment,
                        child: _isProcessing
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.shield_rounded, color: Colors.white, size: 18),
                                  SizedBox(width: 10),
                                  Text(
                                    'Subscribe — ₦1,999 / month',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Billed monthly via Paystack · Cancel anytime',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonTable() {
    final features = [
      _FeatureRow('Panic Button contacts', '3 contacts', '5 contacts'),
      _FeatureRow('Trusted Circle', 'Up to 5', 'Up to 8'),
      _FeatureRow('Location Logging', '10 per month', 'Unlimited'),
      _FeatureRow('Location History', '7 days', '30 days'),
      _FeatureRow('Community Feed', '12km, read only', '30km, read only'),
      _FeatureRow('Audio Sentinel', '3 min, sound only', '20 min, full speech'),
      _FeatureRow('Nearby Alert', 'Receive only', 'Initiate + 5 active'),
      _FeatureRow('Recent Activity', 'Last 5 entries', 'Last 30 entries'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D27),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2E3347)),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFF141720),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('Feature', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text('Free', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
                Expanded(
                  flex: 2,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield_rounded, size: 12, color: Color(0xFFEF4444)),
                      SizedBox(width: 4),
                      Text('Plus', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ...features.asMap().entries.map((e) {
            final isEven = e.key % 2 == 0;
            final f = e.value;
            return Container(
              color: isEven ? const Color(0xFF1A1D27) : const Color(0xFF161921),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      f.feature,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      f.free,
                      style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF16A34A)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            f.plus,
                            style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTrustBadge(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF6B7280), size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ─── STATUS SCREEN ───────────────────────────────────────────────────────────
  Widget _buildStatusScreen(SubscriptionInfo sub) {
    final expiry = sub.expiresAt;
    final formattedExpiry = expiry != null
        ? _formatDate(expiry)
        : 'Unknown';
    final daysLeft = expiry != null
        ? expiry.difference(DateTime.now()).inDays
        : 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Bar ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14532D),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF16A34A)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF4ADE80)),
                        SizedBox(width: 6),
                        Text(
                          'SafeTrace Plus · Active',
                          style: TextStyle(
                            color: Color(0xFF4ADE80),
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1D27),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF2E3347)),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: const Icon(Icons.close, color: Color(0xFF9CA3AF), size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // ── Hero Status Card ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF14532D), Color(0xFF052E16)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x8016A34A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Color(0xFF16A34A),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shield_rounded, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 16),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SafeTrace Plus',
                              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                            ),
                            Text(
                              '₦1,999 / month',
                              style: TextStyle(color: Color(0xFF86EFAC), fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFF166534), height: 1),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatusStat(
                            'Renews On',
                            formattedExpiry,
                            Icons.calendar_today_rounded,
                          ),
                        ),
                        Container(width: 1, height: 40, color: const Color(0xFF166534)),
                        Expanded(
                          child: _buildStatusStat(
                            'Days Left',
                            '$daysLeft days',
                            Icons.hourglass_bottom_rounded,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Active Features ──
              const Text(
                'WHAT\'S ACTIVE ON YOUR PLAN',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 14),
              _buildActiveFeature(Icons.campaign_rounded, 'Panic Button', 'Alerts all 5 trusted contacts instantly'),
              _buildActiveFeature(Icons.people_rounded, 'Trusted Circle', 'Up to 8 trusted contacts'),
              _buildActiveFeature(Icons.location_on_rounded, 'Location Logging', 'Unlimited logs + 30-day history'),
              _buildActiveFeature(Icons.public_rounded, 'Community Feed', 'Expanded 30km radius'),
              _buildActiveFeature(Icons.mic_rounded, 'Audio Sentinel', '20-minute sessions with full speech detection'),
              _buildActiveFeature(Icons.sensors_rounded, 'Nearby Alert', 'Initiate connections, up to 5 active'),
              _buildActiveFeature(Icons.history_rounded, 'Recent Activity', 'Last 30 entries'),
              const SizedBox(height: 28),

              // ── Cancel ──
              Center(
                child: GestureDetector(
                  onTap: () => _showCancelConfirmation(),
                  child: const Text(
                    'Cancel Subscription',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                      decorationColor: Color(0xFF6B7280),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF86EFAC), size: 16),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF86EFAC), fontSize: 11),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildActiveFeature(IconData icon, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D27),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2E3347)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF14532D),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF4ADE80), size: 16),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
        ],
      ),
    );
  }

  void _showCancelConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D27),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Subscription?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        content: const Text(
          'Your SafeTrace Plus access will remain active until the current period ends. After that, you\'ll be moved to the Free tier.',
          style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Plus', style: TextStyle(color: Color(0xFF4ADE80), fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _cancelSubscription();
            },
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelSubscription() async {
    setState(() => _isProcessing = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('cancelSubscription');
      await callable.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subscription cancelled. Access continues until expiry.'),
            backgroundColor: Color(0xFF374151),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) _showError('Could not cancel. Please contact support.');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}

String _formatDate(DateTime dt) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}

class _FeatureRow {
  final String feature;
  final String free;
  final String plus;
  const _FeatureRow(this.feature, this.free, this.plus);
}
