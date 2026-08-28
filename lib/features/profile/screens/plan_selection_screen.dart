import 'package:flutter/material.dart';
import 'transfer_payment_screen.dart';

class PlanSelectionScreen extends StatefulWidget {
  const PlanSelectionScreen({super.key});

  @override
  State<PlanSelectionScreen> createState() => _PlanSelectionScreenState();
}

class _PlanSelectionScreenState extends State<PlanSelectionScreen> {
  String? _selectedPlanId; // 'plus_monthly' or 'plus_annual'

  void _onContinue() {
    if (_selectedPlanId == null) return;

    final bool isAnnual = _selectedPlanId == 'plus_annual';
    final planName = isAnnual ? 'SafeTrace Plus Annual' : 'SafeTrace Plus Monthly';
    final amount = isAnnual ? 20000 : 2000;
    final billingPeriod = isAnnual ? 'Billed annually' : 'Billed monthly';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TransferPaymentScreen(
          planId: _selectedPlanId!,
          planName: planName,
          amount: amount,
          billingPeriod: billingPeriod,
        ),
      ),
    );
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
          'SafeTrace Plus',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose Your Plan',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Select a subscription plan to unlock full protection features.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 24),

              // ── Option 1: Plus Monthly Card ──
              _buildPlanCard(
                planId: 'plus_monthly',
                title: 'Plus Monthly',
                priceText: '₦2,000',
                subText: 'per month',
                isDark: isDark,
              ),

              const SizedBox(height: 16),

              // ── Option 2: Plus Annual Card ──
              _buildPlanCard(
                planId: 'plus_annual',
                title: 'Plus Annual',
                priceText: '₦20,000',
                subText: 'per year',
                equivalentText: 'equivalent to ₦1,667 per month',
                badgeText: 'Save 2 months',
                isDark: isDark,
              ),

              const Spacer(),

              // ── Continue Button ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedPlanId != null
                        ? const Color(0xFFEF4444)
                        : (isDark ? const Color(0xFF2E3347) : const Color(0xFFE5E7EB)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: _selectedPlanId != null ? _onContinue : null,
                  child: Text(
                    'Continue',
                    style: TextStyle(
                      color: _selectedPlanId != null
                          ? Colors.white
                          : (isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Subtext below Continue
              Center(
                child: Text(
                  'Payments are secure and processed by Paystack',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Cancel link
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFEF4444),
                      ),
                    ),
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

  Widget _buildPlanCard({
    required String planId,
    required String title,
    required String priceText,
    required String subText,
    String? equivalentText,
    String? badgeText,
    required bool isDark,
  }) {
    final isSelected = _selectedPlanId == planId;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlanId = planId;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D27) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFEF4444)
                : (isDark ? const Color(0xFF2E3347) : const Color(0xFFD1D5DB)),
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),

                // Checkmark icon when selected
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFEF4444) : Colors.transparent,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? null
                        : Border.all(
                            color: isDark ? const Color(0xFF4B5563) : const Color(0xFF9CA3AF),
                            width: 1.5,
                          ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  priceText,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  subText,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            if (equivalentText != null) ...[
              const SizedBox(height: 6),
              Text(
                equivalentText,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
              ),
            ],

            if (badgeText != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.4)),
                ),
                child: Text(
                  badgeText,
                  style: const TextStyle(
                    color: Color(0xFF4ADE80),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
