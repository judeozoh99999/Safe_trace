import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'login_screen.dart';
import '../../home_shell.dart';

class WelcomeBackUserScreen extends StatefulWidget {
  const WelcomeBackUserScreen({super.key});

  @override
  State<WelcomeBackUserScreen> createState() => _WelcomeBackUserScreenState();
}

class _WelcomeBackUserScreenState extends State<WelcomeBackUserScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _bobbingController;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _bobbingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _bobbingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Entrance animations
    final double toastOffset = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.2, 0.9, curve: Curves.elasticOut),
    ).value; // from 0.0 to 1.0

    final double phoneScale = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
    ).value;

    return Scaffold(
      backgroundColor: Colors.white, // Light mode white background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: AnimatedBuilder(
            animation: Listenable.merge([_entranceController, _bobbingController]),
            builder: (context, child) {
              // Bobbing offset
              final double bob = sin(_bobbingController.value * 2 * pi) * 6.0;

              return Column(
                children: [
                  const Spacer(),

                  // Animated Phone & Notification Illustration
                  Center(
                    child: Transform.translate(
                      offset: Offset(0, bob),
                      child: SizedBox(
                        width: 240,
                        height: 240,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            // Smartphone outline container
                            Transform.scale(
                              scale: phoneScale,
                              child: Container(
                                width: 140,
                                height: 200,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6), // Light grey interior
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: const Color(0xFFE5E7EB), // Light grey outline
                                    width: 2.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                alignment: Alignment.topCenter,
                                padding: const EdgeInsets.only(top: 12),
                                child: Container(
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD1D5DB),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),

                            // Animated Notification Toast (Slide down + Fade in)
                            Positioned(
                              top: -20.0 + (60.0 * toastOffset), // slides down from -20 to 40
                              child: Opacity(
                                opacity: toastOffset.clamp(0.0, 1.0),
                                child: Container(
                                  width: 210,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.12),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      )
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      // App Icon in light theme
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF131522),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.shield_rounded,
                                          color: AppColors.primary,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      // Text contents
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Text(
                                              "SAFETRACE",
                                              style: TextStyle(
                                                color: Color(0xFF1F2937),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              "New device detected!",
                                              style: TextStyle(
                                                color: Color(0xFF4B5563),
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Title: Welcome back, Jude.
                  const Text(
                    "Welcome back, Jude.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF111827), // Dark navy text
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Descriptions
                  const Text(
                    "We noticed this may be a new device. We'll log you out of your other devices so SafeTrace can continue to work properly.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF4B5563), // Slate grey
                      fontSize: 15,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Your previous devices will no longer report location, alert history, and important safety features.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF6B7280), // Muted grey
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),

                  const Spacer(),

                  // Keep using this device action button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary, // Red capsule button
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => const HomeShell(),
                          ),
                          (route) => false,
                        );
                      },
                      child: const Text(
                        "Keep using this device",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Sign Out link
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => const LoginScreen(),
                        ),
                        (route) => false,
                      );
                    },
                    child: const Text(
                      "Sign out",
                      style: TextStyle(
                        color: Color(0xFF111827), // Dark text link
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
