import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/custom_buttons.dart';
import '../providers/auth_provider.dart';
import 'account_verification_screen.dart';
import 'login_screen.dart';

class WelcomeBackScreen extends ConsumerStatefulWidget {
  final String? initialErrorMessage;
  const WelcomeBackScreen({super.key, this.initialErrorMessage});

  @override
  ConsumerState<WelcomeBackScreen> createState() => _WelcomeBackScreenState();
}

class _WelcomeBackScreenState extends ConsumerState<WelcomeBackScreen> {
  final _phoneController = TextEditingController();
  late final FocusNode _phoneFocusNode;
  String? _errorMessage;
  String? _globalError;

  @override
  void initState() {
    super.initState();
    _globalError = widget.initialErrorMessage;
    _phoneFocusNode = FocusNode()
      ..addListener(() {
        if (!_phoneFocusNode.hasFocus) {
          _validatePhone();
        }
      });
    
    // Autofill phone number from provider if already entered in LoginScreen
    final savedPhone = ref.read(authNotifierProvider).phoneNumber;
    if (savedPhone.isNotEmpty) {
      String local = savedPhone;
      if (local.startsWith('+234')) {
        local = local.substring(4);
      }
      _phoneController.text = local;
    }
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
    final authState = ref.watch(authNotifierProvider);

    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      if (next.error != null) {
        setState(() {
          _globalError = next.error;
        });
        ref.read(authNotifierProvider.notifier).clearError();
      }
      if (next.isCodeSent && !(previous?.isCodeSent ?? false)) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const AccountVerificationScreen(),
          ),
        );
      }
    });

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
                "Welcome Back",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Kindly provide your phone number to sign in.",
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF6B7280),
                  height: 1.45,
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
              
              if (_globalError != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _globalError!,
                        style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      if (_globalError!.contains("No account was found")) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                            );
                          },
                          icon: const Icon(Icons.person_add_rounded, color: Color(0xFFB91C1C), size: 16),
                          label: const Text("Create Account Instead", style: TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 48),

              // Redirect to Sign Up
              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(),
                      ),
                    );
                  },
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
                      children: [
                        TextSpan(text: "Don’t have an account? "),
                        TextSpan(
                          text: "Sign up",
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Sign in button
              SafeTraceButton(
                text: authState.isLoading ? "Verifying Phone..." : "Sign in",
                type: ButtonType.primary,
                icon: authState.isLoading ? null : Icons.arrow_forward_ios_rounded,
                onPressed: authState.isLoading
                    ? null
                    : () async {
                        _validatePhone();
                        if (_errorMessage == null) {
                          setState(() {
                            _globalError = null;
                          });
                          final phone = _formatNigerianPhoneNumber(_phoneController.text.trim());
                          ref.read(authNotifierProvider.notifier).setPhone(phone);
                          
                          // Check if phone number is registered
                          final notifier = ref.read(authNotifierProvider.notifier);
                          final email = await notifier.getEmailForPhone(phone);
                          if (email == null) {
                            setState(() {
                              _globalError = "No account was found with this phone number.";
                            });
                            return;
                          }
                          
                          // Trigger email OTP send
                          await notifier.sendEmailOtp(email);
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
