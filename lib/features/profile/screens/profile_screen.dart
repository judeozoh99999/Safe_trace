import 'package:flutter/material.dart';
import 'profile_detail_screens.dart';
import 'safetrace_plus_screen.dart';

Route _createRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(1.0, 0.0);
      const end = Offset.zero;
      const curve = Curves.easeInOutCubic;

      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

      return SlideTransition(
        position: animation.drive(tween),
        child: FadeTransition(
          opacity: animation,
          child: child,
        ),
      );
    },
  );
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            // Center Header "Profile"
            const Padding(
              padding: EdgeInsets.only(top: 16.0, bottom: 12.0),
              child: Text(
                "Profile",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  children: [
                    // Profile Summary Card
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Avatar Circle
                          Container(
                            width: 80,
                            height: 80,
                            decoration: const BoxDecoration(
                              color: Color(0xFF131522), // Dark Navy
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              "VO",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Name
                          const Text(
                            "Voke Okoro-na-me",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Phone
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.phone, size: 14, color: Color(0xFF6B7280)),
                              SizedBox(width: 6),
                              Text(
                                "+234 802 345 6789",
                                style: TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Get SafeTrace Plus Button (Full width)
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEF4444),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                elevation: 0,
                              ),
                              onPressed: () {
                                Navigator.of(context).push(_createRoute(const SafeTracePlusScreen()));
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    "Get SafeTrace Plus",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Stats Row
                    Row(
                      children: [
                        _buildStatBox("247", "Days Protected"),
                        const SizedBox(width: 8),
                        _buildStatBox("38", "Locations Logged"),
                        const SizedBox(width: 8),
                        _buildStatBox("3", "Trusted Contacts"),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // SAFETY GROUP
                    _buildGroupHeader("SAFETY"),
                    _buildMenuItem(
                      icon: Icons.people_outline_rounded,
                      title: "Trusted Contacts",
                      subtitle: "3 contacts added",
                      iconBg: const Color(0xFFEEF2FF),
                      iconColor: const Color(0xFF4F46E5),
                      badge: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEB444E), // red notification
                          shape: BoxShape.circle,
                        ),
                        child: const Text(
                          "1",
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      rightLabel: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          "High Alert",
                          style: TextStyle(color: Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      onTap: () {
                        Navigator.of(context).push(_createRoute(const TrustedCircleScreen()));
                      },
                    ),
                    _buildMenuItem(
                      icon: Icons.info_outline_rounded,
                      title: "Check-In Alert",
                      subtitle: "Track 3-Day Inactive Users",
                      iconBg: const Color(0xFFEEF2FF),
                      iconColor: const Color(0xFF4F46E5),
                      onTap: () {
                        Navigator.of(context).push(_createRoute(const WelfareCheckAlertScreen()));
                      },
                    ),
                    const SizedBox(height: 20),

                    // PREFERENCES GROUP
                    _buildGroupHeader("PREFERENCES"),
                    _buildMenuItem(
                      icon: Icons.notifications_none,
                      title: "Notification Preferences",
                      subtitle: "Alerts, check-ins, updates",
                      iconBg: const Color(0xFFEEF2FF),
                      iconColor: const Color(0xFF4F46E5),
                      onTap: () {
                        Navigator.of(context).push(_createRoute(const NotificationPreferencesScreen()));
                      },
                    ),
                    _buildMenuItem(
                      icon: Icons.shield_outlined,
                      title: "Privacy & Data",
                      subtitle: "Location sharing, data retention",
                      iconBg: const Color(0xFFEEF2FF),
                      iconColor: const Color(0xFF4F46E5),
                      onTap: () {
                        Navigator.of(context).push(_createRoute(const PrivacyDataScreen()));
                      },
                    ),
                    const SizedBox(height: 20),

                    // SUPPORT GROUP
                    _buildGroupHeader("SUPPORT"),
                    _buildMenuItem(
                      icon: Icons.help_outline_rounded,
                      title: "Help & Support",
                      subtitle: "FAQs, contact SafeTrace team",
                      iconBg: const Color(0xFFEEF2FF),
                      iconColor: const Color(0xFF4F46E5),
                      onTap: () {
                        Navigator.of(context).push(_createRoute(const HelpSupportScreen()));
                      },
                    ),
                    const SizedBox(height: 20),

                    // DANGER ZONE GROUP
                    _buildGroupHeader("DANGER ZONE", isDanger: true),
                    _buildMenuItem(
                      icon: Icons.logout_rounded,
                      title: "Sign Out",
                      subtitle: "You'll need to verify your number again",
                      iconBg: const Color(0xFFFEE2E2),
                      iconColor: const Color(0xFFEF4444),
                      onTap: () {
                        Navigator.of(context).push(_createRoute(const SignOutScreen()));
                      },
                    ),
                    _buildMenuItem(
                      icon: Icons.delete_outline_rounded,
                      title: "Delete Account",
                      subtitle: "Permanently delete all your data",
                      iconBg: const Color(0xFFFEE2E2),
                      iconColor: const Color(0xFFEF4444),
                      onTap: () {
                        Navigator.of(context).push(_createRoute(const DeleteAccountConfirmScreen()));
                      },
                    ),
                    const SizedBox(height: 32),

                    // Footer
                    const Text(
                      "SafeTrace v2.4.1 · Made with care for Nigeria 🇳🇬",
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String val, String label) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Text(
              val,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupHeader(String title, {bool isDanger = false}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: isDanger ? const Color(0xFFEF4444) : const Color(0xFF6B7280),
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconBg,
    required Color iconColor,
    Widget? badge,
    Widget? rightLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              badge,
            ],
          ],
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (rightLabel != null) ...[
              rightLabel,
              const SizedBox(width: 8),
            ],
            const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF9CA3AF), size: 14),
          ],
        ),
      ),
    );
  }
}
