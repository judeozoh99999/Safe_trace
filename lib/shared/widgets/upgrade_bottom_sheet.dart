import 'package:flutter/material.dart';
import '../../features/wallet/screens/claim_plus_screen.dart';

class UpgradeBottomSheet extends StatelessWidget {
  final String message;

  const UpgradeBottomSheet({
    super.key,
    required this.message,
  });

  static void show(BuildContext context, {required String message}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => UpgradeBottomSheet(message: message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E2230) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.58,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle pill
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Gold shield icon
          const Icon(
            Icons.shield_rounded,
            size: 48,
            color: Color(0xFFF59E0B),
          ),
          const SizedBox(height: 10),

          // Title
          Text(
            'SafeTrace Plus',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),

          // Specific feature message
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),

          // Features Summary Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF11141F) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF2E3347) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              children: const [
                _FeatureRow(text: 'Panic alerts to all 5 trusted contacts'),
                SizedBox(height: 6),
                _FeatureRow(text: 'Unlimited location logging & history'),
                SizedBox(height: 6),
                _FeatureRow(text: 'AI Route Intelligence & threat summaries'),
                SizedBox(height: 6),
                _FeatureRow(text: 'Audio Sentinel speech distress detection'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Free claim line
          const Text(
            'Free Claim — No payment required',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const Spacer(),

          // Primary button: Get SafeTrace Plus
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ClaimPlusScreen()),
                );
              },
              child: const Text(
                'Get SafeTrace Plus',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Secondary button: Maybe Later
          SizedBox(
            width: double.infinity,
            height: 38,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Maybe Later',
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String text;
  const _FeatureRow({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFFEF4444),
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
