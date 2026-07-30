import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/custom_buttons.dart';
import '../providers/auth_provider.dart';
import 'verify_email_screen.dart';
import 'terms_of_service_screen.dart';
import 'privacy_policy_screen.dart';

class EnterDetailsScreen extends ConsumerStatefulWidget {
  const EnterDetailsScreen({super.key});

  @override
  ConsumerState<EnterDetailsScreen> createState() => _EnterDetailsScreenState();
}

class _EnterDetailsScreenState extends ConsumerState<EnterDetailsScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  
  late final FocusNode _firstNameFocusNode;
  late final FocusNode _lastNameFocusNode;
  late final FocusNode _emailFocusNode;

  String? _firstNameError;
  String? _lastNameError;
  String? _emailError;
  String? _globalError;

  @override
  void initState() {
    super.initState();
    _firstNameFocusNode = FocusNode()
      ..addListener(() {
        if (!_firstNameFocusNode.hasFocus) {
          _validateFirstNameField();
        }
      });
    _lastNameFocusNode = FocusNode()
      ..addListener(() {
        if (!_lastNameFocusNode.hasFocus) {
          _validateLastNameField();
        }
      });
    _emailFocusNode = FocusNode()
      ..addListener(() {
        if (!_emailFocusNode.hasFocus) {
          _validateEmailField();
        }
      });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    
    _firstNameFocusNode.dispose();
    _lastNameFocusNode.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  bool _isValidName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length < 2) return false;
    final reg = RegExp(r"^[a-zA-Z'\-]+$");
    return reg.hasMatch(trimmed);
  }

  bool _validateEmail(String email) {
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return regex.hasMatch(email);
  }

  void _validateFirstNameField() {
    setState(() {
      final name = _firstNameController.text.trim();
      if (name.isEmpty) {
        _firstNameError = "First name is required";
      } else if (!_isValidName(name)) {
        _firstNameError = "Please enter a valid first name (min 2 letters, no spaces)";
      } else {
        _firstNameError = null;
      }
    });
  }

  void _validateLastNameField() {
    setState(() {
      final name = _lastNameController.text.trim();
      if (name.isEmpty) {
        _lastNameError = "Last name is required";
      } else if (!_isValidName(name)) {
        _lastNameError = "Please enter a valid last name (min 2 letters, no spaces)";
      } else {
        _lastNameError = null;
      }
    });
  }

  void _validateEmailField() {
    setState(() {
      final email = _emailController.text.trim();
      if (email.isEmpty) {
        _emailError = "Email address is required";
      } else if (!_validateEmail(email)) {
        _emailError = "Please enter a valid email address";
      } else {
        _emailError = null;
      }
    });
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
            builder: (_) => const VerifyEmailScreen(),
          ),
        );
      }
    });

    final bool isFormValid = _firstNameController.text.trim().isNotEmpty &&
        _lastNameController.text.trim().isNotEmpty &&
        _emailController.text.trim().isNotEmpty &&
        _firstNameError == null &&
        _lastNameError == null &&
        _emailError == null;

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
                "Enter Your Details",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Provide your details below to create your account.",
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF6B7280),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 32),

              // First Name field
              const Text(
                "FIRST NAME",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF6B7280),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _firstNameController,
                focusNode: _firstNameFocusNode,
                style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: "Enter your first name",
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.normal),
                  fillColor: const Color(0xFFF9FAFB),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _firstNameError != null ? Colors.red : const Color(0xFFE5E7EB),
                      width: 1.5,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _firstNameError != null ? Colors.red : const Color(0xFFE5E7EB),
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _firstNameError != null ? Colors.red : AppColors.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              if (_firstNameError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _firstNameError!,
                  style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
              const SizedBox(height: 24),

              // Last Name field
              const Text(
                "LAST NAME",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF6B7280),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _lastNameController,
                focusNode: _lastNameFocusNode,
                style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: "Enter your last name",
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.normal),
                  fillColor: const Color(0xFFF9FAFB),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _lastNameError != null ? Colors.red : const Color(0xFFE5E7EB),
                      width: 1.5,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _lastNameError != null ? Colors.red : const Color(0xFFE5E7EB),
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _lastNameError != null ? Colors.red : AppColors.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              if (_lastNameError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _lastNameError!,
                  style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
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
                focusNode: _emailFocusNode,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: "Email address",
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.normal),
                  fillColor: const Color(0xFFF9FAFB),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _emailError != null ? Colors.red : const Color(0xFFE5E7EB),
                      width: 1.5,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _emailError != null ? Colors.red : const Color(0xFFE5E7EB),
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _emailError != null ? Colors.red : AppColors.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              if (_emailError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _emailError!,
                  style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
              
              if (_globalError != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFB91C1C), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _globalError!,
                          style: const TextStyle(
                            color: Color(0xFFB91C1C),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 40),

              // Terms of Service Link
              Center(
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.45),
                    children: [
                      const TextSpan(text: "By continuing, you agree to our\n"),
                      TextSpan(
                        text: "Terms of Service",
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
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
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
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
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Create an Account Action Button
              SafeTraceButton(
                text: authState.isLoading ? "Sending Code..." : "Create an Account",
                type: ButtonType.primary,
                icon: authState.isLoading ? null : Icons.arrow_forward_ios_rounded,
                onPressed: isFormValid && !authState.isLoading
                    ? () async {
                        _validateFirstNameField();
                        _validateLastNameField();
                        _validateEmailField();
                        if (_firstNameError == null && _lastNameError == null && _emailError == null) {
                          final firstName = _firstNameController.text.trim();
                          final lastName = _lastNameController.text.trim();
                          final email = _emailController.text.trim();
                          
                          setState(() {
                            _globalError = null;
                          });

                          // Confirm phone number doesn't exist
                          final notifier = ref.read(authNotifierProvider.notifier);
                          final phone = ref.read(authNotifierProvider).phoneNumber;
                          
                          final exists = await notifier.checkPhoneExists(phone);
                          if (exists) {
                            setState(() {
                              _globalError = "An account with this phone number already exists.";
                            });
                            return;
                          }

                          notifier.setDetails(firstName, lastName, email);
                          notifier.sendEmailOtp(email);
                        }
                      }
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
