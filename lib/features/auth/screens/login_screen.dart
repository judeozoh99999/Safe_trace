import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/custom_buttons.dart';
import '../providers/auth_provider.dart';
import 'welcome_back_screen.dart';
import 'enter_details_screen.dart';
import 'terms_of_service_screen.dart';
import 'privacy_policy_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final String? initialErrorMessage;
  const LoginScreen({super.key, this.initialErrorMessage});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  late final FocusNode _phoneFocusNode;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _errorMessage = widget.initialErrorMessage;
    _phoneFocusNode = FocusNode();
    _phoneFocusNode.addListener(() {
      if (!_phoneFocusNode.hasFocus) {
        _validatePhone();
      }
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  bool _isValidNigerianNumber(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    String local = cleaned;
    if (local.startsWith('234')) {
      local = local.substring(3);
    } else if (local.startsWith('0')) {
      local = local.substring(1);
    }
    if (local.length != 10) return false;
    final firstDigit = local[0];
    return firstDigit == '7' || firstDigit == '8' || firstDigit == '9';
  }

  void _validatePhone() {
    final text = _phoneController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _errorMessage = "Please enter your phone number";
      });
    } else if (!_isValidNigerianNumber(text)) {
      setState(() {
        _errorMessage = "Please enter a valid Nigerian mobile number (e.g., 803 123 4567)";
      });
    } else {
      setState(() {
        _errorMessage = null;
      });
    }
  }

  String _formatNigerianPhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('234')) {
      return '+$cleaned';
    }
    if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }
    return '+234$cleaned';
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
                "Verify your phone number",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 32),

              // Phone Number Input field
              const Text(
                "PHONE NUMBER",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF6B7280),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _errorMessage != null ? Colors.red : const Color(0xFFE5E7EB),
                    width: 1.5,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("🇳🇬", style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        const Text(
                          "+234",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 1,
                          height: 24,
                          color: const Color(0xFFD1D5DB),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        focusNode: _phoneFocusNode,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF111827),
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: const InputDecoration(
                          hintText: "000 000 0000",
                          hintStyle: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontWeight: FontWeight.normal,
                          ),
                          border: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],

              const SizedBox(height: 24),

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

              // Create Account Action Button
              SafeTraceButton(
                text: "Create Account",
                type: ButtonType.primary,
                icon: Icons.arrow_forward_ios_rounded,
                onPressed: () {
                  _validatePhone();
                  if (_errorMessage == null) {
                    final formattedPhone = _formatNigerianPhoneNumber(_phoneController.text.trim());
                    ref.read(authNotifierProvider.notifier).setPhone(formattedPhone);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const EnterDetailsScreen(),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 16),

              // Sign In Action Button
              SafeTraceButton(
                text: "Sign In",
                type: ButtonType.secondary,
                icon: Icons.login_rounded,
                onPressed: () {
                  final text = _phoneController.text.trim();
                  if (text.isNotEmpty && _isValidNigerianNumber(text)) {
                    final formattedPhone = _formatNigerianPhoneNumber(text);
                    ref.read(authNotifierProvider.notifier).setPhone(formattedPhone);
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const WelcomeBackScreen(),
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
