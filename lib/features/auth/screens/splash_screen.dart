import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();

    // Navigate after splash animation with resilient session resolution (Section 3)
    Future.delayed(const Duration(milliseconds: 1500), () async {
      if (!mounted) return;

      // 1. Synchronous check: If user already present in memory, go directly to home
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        if (mounted) GoRouter.of(context).go('/home');
        return;
      }

      // 2. Wait up to 3.5 more seconds (total ~5s) for Keystore restoration on aggressive Android ROMs
      try {
        user = await FirebaseAuth.instance
            .authStateChanges()
            .firstWhere((u) => u != null)
            .timeout(const Duration(milliseconds: 3500));
      } catch (_) {
        // Timeout reached: genuine unauthenticated state
        user = FirebaseAuth.instance.currentUser;
      }

      if (!mounted) return;
      if (user != null) {
        GoRouter.of(context).go('/home');
      } else {
        final prefs = await SharedPreferences.getInstance();
        final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
        if (mounted) {
          GoRouter.of(context).go(onboardingCompleted ? '/login' : '/onboarding');
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // SafeTrace Logo Icon
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.backgroundDark,
                  borderRadius: BorderRadius.circular(24),
                ),
                alignment: Alignment.center,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Shield Icon
                    const Icon(
                      Icons.shield_rounded,
                      color: AppColors.primary,
                      size: 56,
                    ),
                    // Inner Pin Icon
                    const Positioned(
                      top: 26,
                      child: Icon(
                        Icons.location_on_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // App Name Text
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    "Safe",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.backgroundDark,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    "Trace",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
