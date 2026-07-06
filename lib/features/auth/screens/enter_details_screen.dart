import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/custom_buttons.dart';
import 'verify_email_screen.dart';
import 'terms_of_service_screen.dart';
import 'privacy_policy_screen.dart';

class EnterDetailsScreen extends StatefulWidget {
  const EnterDetailsScreen({super.key});

  @override
  State<EnterDetailsScreen> createState() => _EnterDetailsScreenState();
}

class _EnterDetailsScreenState extends State<EnterDetailsScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF3F4F6),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.arrow_back,
                    color: Color(0xFF1F2937),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Logo & App Name
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF131522),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.shield_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "SafeTrace",
                    style: TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Headings
              const Text(
                "Enter your details",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "We'll send a verification code to confirm your number.",
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF6B7280),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 32),

              // Full Name field
              const Text(
                "FULL NAME",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF6B7280),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: "Full name",
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.normal),
                  fillColor: const Color(0xFFF9FAFB),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(height: 24),

              // Email Address field
              const Text(
                "EMAIL ADDRESS",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF6B7280),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: "Email address",
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.normal),
                  fillColor: const Color(0xFFF9FAFB),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(height: 32),

              // Terms Policy Text
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.45),
                  children: [
                    const TextSpan(text: "By continuing, you agree to SafeTrace's "),
                    TextSpan(
                      text: "Terms of Service",
                      style: const TextStyle(
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const TermsOfServiceScreen(),
                            ),
                          );
                        },
                    ),
                    const TextSpan(text: " and "),
                    TextSpan(
                      text: "Privacy Policy",
                      style: const TextStyle(
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PrivacyPolicyScreen(),
                            ),
                          );
                        },
                    ),
                    const TextSpan(text: "."),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // Create an Account Action Button
              SafeTraceButton(
                text: "Create an Account",
                type: ButtonType.primary,
                icon: Icons.arrow_forward_ios_rounded,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const VerifyEmailScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
