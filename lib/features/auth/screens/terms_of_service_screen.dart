import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Dark blue header banner
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF242946), // Dark blue matching image
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.only(top: 48, bottom: 28, left: 16, right: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top nav row
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.arrow_back,
                          color: Color(0xFF242946),
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.description_outlined,
                      color: Colors.white70,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Terms of Service",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Heading and date
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "Last updated: July 4, 2026",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "SafeTrace Terms of Service",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Please read these terms carefully before using SafeTrace. By using our service, you agree to these terms.",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          // Scrollable content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSection(
                  "1. Acceptance of Terms",
                  "By downloading, installing, or using the SafeTrace application, you agree to be bound by these Terms of Service. If you do not agree to all terms, you may not use the services.",
                ),
                _buildSection(
                  "2. Eligibility",
                  "You must be at least 18 years of age (or the legal age of majority in Nigeria) to create an account. You represent and warrant that all registration information you submit is accurate and truthful.",
                ),
                _buildSection(
                  "3. Use of Services",
                  "SafeTrace provides personal safety features, location tracking, and emergency alert routing. You agree to use the application solely for personal, non-commercial purposes and not for any unlawful tracking, stalking, or harassment.",
                ),
                _buildSection(
                  "4. User Accounts",
                  "You are responsible for maintaining the confidentiality of your account credentials, including the OTP codes sent to your phone. You agree to immediately notify SafeTrace of any unauthorized use of your account.",
                ),
                _buildSection(
                  "5. Data Privacy",
                  "We value your privacy. The collection and use of your personal details and location data are governed by our Privacy Policy. By agreeing to these terms, you also consent to the data practices described in the Privacy Policy.",
                ),
                _buildSection(
                  "6. Emergency Features",
                  "SafeTrace's panic button, crash detection, and location share tools are supplementary tools. They do not replace national emergency services (such as 112/199). SafeTrace is not liable for delayed notifications or signal failure.",
                ),
                _buildSection(
                  "7. SafeTrace Circle",
                  "Your emergency contacts must consent to receive SMS alerts and view your location coordinates. You represent that you have obtained consent from all 5 members of your emergency circle.",
                ),
                _buildSection(
                  "8. Subscription and Payments",
                  "Certain premium safety features require a paid subscription. Payments are securely processed via Paystack. Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current period.",
                ),
                _buildSection(
                  "9. Intellectual Property",
                  "All materials, trademarks, source code, logos, and UI designs of SafeTrace are the exclusive intellectual property of SafeTrace Technologies Ltd. No rights are transferred to you.",
                ),
                _buildSection(
                  "10. Termination",
                  "We reserve the right to suspend or terminate your account at our sole discretion, without notice, if we believe you have breached these terms or engaged in fraudulent behavior.",
                ),
                _buildSection(
                  "11. Disclaimer",
                  "The application is provided on an 'as-is' and 'as-available' basis. SafeTrace disclaims all warranties, express or implied, including the warranties of merchantability and fitness for a particular purpose.",
                ),
                _buildSection(
                  "12. Governing Law",
                  "These terms shall be governed by and construed in accordance with the laws of the Federal Republic of Nigeria. Any disputes shall be resolved in the courts of Lagos, Nigeria.",
                ),
                _buildSection(
                  "13. Contact Us",
                  "If you have any questions or feedback regarding these terms, please contact us at support@safetrace.ng, or visit our office in Yaba, Lagos, Nigeria.",
                ),
                const SizedBox(height: 12),

                // Note box at bottom
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF), // light blue matching mockup
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFF1D4ED8),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "These Terms of Service were last updated on July 4, 2026. Custom terms apply.",
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF1D4ED8).withOpacity(0.85),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF4B5563),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
