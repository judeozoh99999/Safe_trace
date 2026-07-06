import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Dark green header banner (matching green theme in mockup)
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF1B4332), // Dark green matching image
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
                          color: Color(0xFF1B4332),
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.verified_user_outlined,
                      color: Colors.white70,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Privacy Policy",
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
                  "SafeTrace Privacy Policy",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Your privacy is our utmost priority. Learn how we collect, protect, and handle your security data.",
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
                  "1. Information We Collect",
                  "SafeTrace collects personal profile information (name, email address, phone number), location coordinates (latitude and longitude coordinates in real-time), and emergency contact numbers you designate.",
                ),
                _buildSection(
                  "2. How We Use Information",
                  "We use your location information to update members of your emergency circle, calculate route steps during active alerts, and trigger automatic warning triggers (like inactivity alerts or watch mode alerts).",
                ),
                _buildSection(
                  "3. Sharing Data",
                  "We only share your location history, battery level, and emergency status with your designated Emergency Contacts. We do not sell, rent, or lease your private location information to third-party advertisers.",
                ),
                _buildSection(
                  "4. Storing Your Information",
                  "All location histories, user credentials, and security settings are safely stored in Firestore and Google Cloud Databases with modern industry-standard TLS encryption protocols.",
                ),
                _buildSection(
                  "5. Keeping You Safe",
                  "You maintain full control of your location. You can disable location reporting, adjust watch mode parameters, or cancel temporary sharing directly from your Home Screen settings dashboard.",
                ),
                _buildSection(
                  "6. Data Retention",
                  "Active safety alert history is kept for 30 days to review logs, after which it is deleted. If you delete your account, we wipe all stored profile details and location records within 48 hours.",
                ),
                _buildSection(
                  "7. Your Rights",
                  "You have the right to request access to the location logs we store, ask for corrections, or request complete account erasure by contacting our support team at privacy@safetrace.ng.",
                ),
                _buildSection(
                  "8. Security Measures",
                  "We deploy strict security measures, including HTTPS endpoints, API call limits, and database rule firewalls to protect you from unauthorized data interception.",
                ),
                _buildSection(
                  "9. Children's Privacy",
                  "SafeTrace is not designed for children under 13. We do not knowingly collect personal safety tracking details for minors without explicit parental consent.",
                ),
                _buildSection(
                  "10. Contact Us",
                  "If you have inquiries regarding location data sharing, please contact the Data Protection Officer at privacy@safetrace.ng or our main Lagos headquarters.",
                ),
                const SizedBox(height: 12),

                // Note box at bottom
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9), // light green matching theme
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFC8E6C9)),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        color: Color(0xFF2E7D32),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Privacy Policy was last updated on July 4, 2026. Custom policies apply.",
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF2E7D32).withOpacity(0.85),
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
