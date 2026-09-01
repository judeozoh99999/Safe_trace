import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'profile_detail_screens.dart';
import 'claim_plus_screen.dart';
import 'manage_subscription_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../location/providers/home_provider.dart';
import '../../contacts/providers/trusted_contacts_provider.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/subscription_provider.dart';

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

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authNotifierProvider);
    final homeState = ref.watch(homeProvider);

    final userName = authState.displayName.isEmpty ? 'User' : authState.displayName;
    final userPhone = authState.phoneNumber.isEmpty ? 'No phone set' : authState.phoneNumber;
    final String initials;
    if (authState.firstName.isEmpty && authState.lastName.isEmpty) {
      initials = 'U';
    } else {
      final fLetter = authState.firstName.isNotEmpty ? authState.firstName[0] : '';
      final lLetter = authState.lastName.isNotEmpty ? authState.lastName[0] : '';
      initials = "$fLetter$lLetter".toUpperCase();
    }

    // Calculate days protected
    final created = authState.createdAt;
    final int daysProtectedVal = created != null
        ? DateTime.now().difference(created).inDays
        : 0;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            // Center Header "Profile"
            Padding(
              padding: const EdgeInsets.only(top: 16.0, bottom: 12.0),
              child: Text(
                "Profile",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF111827),
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
                        color: isDark ? AppColors.cardDark : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark ? AppColors.dividerDark : const Color(0xFFE5E7EB),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
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
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1F2937) : const Color(0xFF131522), // Dark Navy
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Name
                          Text(
                            userName,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Phone
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.phone, size: 14, color: isDark ? AppColors.textDarkSecondary : const Color(0xFF6B7280)),
                              const SizedBox(width: 6),
                              Text(
                                userPhone,
                                style: TextStyle(
                                  color: isDark ? AppColors.textDarkSecondary : const Color(0xFF6B7280),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // SafeTrace Plus / Active button
                          _SubscriptionButton(
                            onPressed: () {
                              Navigator.of(context).push(_createRoute(const ClaimPlusScreen()));
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Stats Row & Trusted Contacts Count
                    Builder(
                      builder: (context) {
                        final trustedCountAsync = ref.watch(trustedContactsCountProvider);

                        final String statDisplay = trustedCountAsync.when(
                          data: (total) => "$total",
                          loading: () => "-",
                          error: (err, stack) => "0",
                        );

                        final String subtitleText = trustedCountAsync.when(
                          data: (total) {
                            if (total == 0) return "No contacts added yet";
                            if (total == 1) return "1 active contact added";
                            return "$total active contacts added";
                          },
                          loading: () => "Loading contacts...",
                          error: (err, stack) => "No contacts added yet",
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _buildStatBox(context, "$daysProtectedVal", "Days Protected"),
                                const SizedBox(width: 8),
                                _buildStatBox(context, "${homeState.logs.length}", "Locations Logged"),
                                const SizedBox(width: 8),
                                _buildStatBox(context, statDisplay, "Trusted Contacts"),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // SAFETY GROUP
                            _buildGroupHeader("SAFETY"),
                            _buildMenuItem(
                              context,
                              icon: Icons.people_outline_rounded,
                              title: "Trusted Contacts",
                              subtitle: subtitleText,
                              iconBg: const Color(0xFFEEF2FF),
                              iconColor: const Color(0xFF4F46E5),
                              onTap: () {
                                Navigator.of(context).push(_createRoute(const TrustedCircleScreen()));
                              },
                            ),
                          ],
                        );
                      },
                    ),
                    _buildMenuItem(
                      context,
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
                    _buildThemeToggleItem(context, ref),
                    _buildMenuItem(
                      context,
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
                      context,
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
                      context,
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
                      context,
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
                      context,
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
                    Text(
                      "SafeTrace v2.4.1 · Made with care for Nigeria 🇳🇬",
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textDarkSecondary : const Color(0xFF9CA3AF),
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

  Widget _buildThemeToggleItem(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final appIsDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: appIsDark ? const Color(0xFF1C1E2D) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: appIsDark ? const Color(0xFF282B40) : const Color(0xFFE5E7EB),
          width: 1.5,
        ),
      ),
      child: SwitchListTile(
        value: isDark,
        onChanged: (val) {
          ref.read(themeModeProvider.notifier).toggleTheme(val);
        },
        title: Text(
          "Dark Mode",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: appIsDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        subtitle: Text(
          "Switch between light and dark themes",
          style: TextStyle(
            fontSize: 12,
            color: appIsDark ? AppColors.textDarkSecondary : const Color(0xFF6B7280),
          ),
        ),
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.dark_mode_outlined,
            color: Color(0xFF4F46E5),
            size: 20,
          ),
        ),
        activeColor: const Color(0xFF4F46E5),
      ),
    );
  }

  Widget _buildStatBox(BuildContext context, String val, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1E2D) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF282B40) : const Color(0xFFE5E7EB),
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Text(
              val,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.textDarkSecondary : const Color(0xFF6B7280),
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

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconBg,
    required Color iconColor,
    Widget? badge,
    Widget? rightLabel,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1E2D) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF282B40) : const Color(0xFFE5E7EB),
          width: 1.5,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F2937) : iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: isDark ? AppColors.primary : iconColor, size: 20),
        ),
        title: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF111827),
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
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.textDarkSecondary : const Color(0xFF6B7280),
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

// ── Subscription-aware button (Active card when Plus, red pulsing when Free) ────────
class _SubscriptionButton extends ConsumerWidget {
  final VoidCallback onPressed;
  const _SubscriptionButton({required this.onPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docAsync = ref.watch(userDocumentStreamProvider);

    final data = docAsync.valueOrNull?.data();
    final bool subscriptionActive = data != null &&
        (data['subscription_active'] == true ||
            data['subscription_active'].toString().toLowerCase() == 'true');
    final String subscriptionTier = (data?['subscription_tier'] ?? 'free').toString().toLowerCase().trim();

    final bool isPlus = subscriptionActive && subscriptionTier == 'plus';

    debugPrint(
      '[PROFILE_BUTTON BUILD] -> '
      'raw subscription_active: ${data?['subscription_active']}, '
      'parsed subscriptionActive: $subscriptionActive, '
      'subscription_tier: "$subscriptionTier" '
      '=> isPlus: $isPlus',
    );

    if (isPlus) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(_createRoute(const ManageSubscriptionScreen()));
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E), // Dark navy #1A1A2E
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2E3347)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                // Gold star / verified icon on left
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFF59E0B),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // Text: SafeTrace Plus Active & Active — Free Plan
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'SafeTrace Plus Active',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Active — Free Plan',
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Settings icon on right
                IconButton(
                  icon: const Icon(
                    Icons.settings_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                  onPressed: () {
                    Navigator.of(context).push(_createRoute(const ManageSubscriptionScreen()));
                  },
                  tooltip: 'Manage Subscription',
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PulsingButton(onPressed: onPressed);
  }
}

class PulsingButton extends StatefulWidget {
  final VoidCallback onPressed;
  const PulsingButton({super.key, required this.onPressed});

  @override
  State<PulsingButton> createState() => _PulsingButtonState();
}

class _PulsingButtonState extends State<PulsingButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: child,
          ),
        );
      },
      child: SizedBox(
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
          onPressed: widget.onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.shield_rounded, size: 16, color: Colors.white),
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
    );
  }
}
