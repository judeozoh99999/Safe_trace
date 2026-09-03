import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import 'place_alerts_screen.dart';
import 'login_screen.dart';

class _ShakeCurve extends Curve {
  @override
  double transformInternal(double t) {
    return math.sin(t * math.pi * 6);
  }
}

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  int _secondsRemaining = 59;
  Timer? _timer;
  bool _canVerify = false;
  String? _localError;
  int _attemptCount = 0;
  bool _isSessionInvalidated = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 12.0)
        .chain(CurveTween(curve: _ShakeCurve()))
        .animate(_shakeController);

    _startTimer();
    for (var controller in _controllers) {
      controller.addListener(_checkOtpCompleteness);
    }
  }

  void _startTimer() {
    setState(() {
      _secondsRemaining = 59;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  void _checkOtpCompleteness() {
    bool isComplete = _controllers.every((c) => c.text.isNotEmpty);
    if (isComplete != _canVerify) {
      setState(() {
        _canVerify = isComplete;
      });
    }
  }

  void _onWrongOtp(String errorMessage) {
    // 1. Heavy Impact Haptic Feedback
    HapticFeedback.heavyImpact();

    // 2. 300ms Shake animation
    _shakeController.forward(from: 0.0);

    // 3. Clear all 6 input boxes
    for (var c in _controllers) {
      c.clear();
    }

    _attemptCount++;

    if (_attemptCount >= 5) {
      // 5 attempts failed: Invalidate session
      setState(() {
        _isSessionInvalidated = true;
        _canVerify = false;
        _localError = "Too many incorrect attempts. Your code has been invalidated. Request a new one.";
      });
    } else {
      setState(() {
        _canVerify = false;
        _localError = errorMessage;
      });

      // 5. Move focus back to the 1st input box
      _focusNodes[0].requestFocus();
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _timer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      if (next.error != null) {
        if (next.error == "TOO_MANY_ATTEMPTS") {
          setState(() {
            _isSessionInvalidated = true;
            _canVerify = false;
            _localError = "Too many incorrect attempts. Your code has been invalidated. Request a new one.";
          });
        } else if (next.error == "EMAIL_ALREADY_IN_USE") {
          setState(() {
            _localError = "An account with this email address already exists. Please try another one.";
          });
        } else {
          _onWrongOtp(next.error!);
        }
        ref.read(authNotifierProvider.notifier).clearError();
      }
      if (next.isAuthenticated && !(previous?.isAuthenticated ?? false)) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const PlaceAlertsScreen(),
          ),
          (route) => false,
        );
      }
    });

    final String timerString = "00:${_secondsRemaining.toString().padLeft(2, '0')}";

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
              const SizedBox(height: 32),

              // Lock Icon
              Center(
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: const Color(0xFF242946),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.lock_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Headings
              const Center(
                child: Text(
                  "Verify your Email",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(fontSize: 15, color: Color(0xFF6B7280), height: 1.45),
                    children: [
                      const TextSpan(text: "Enter the 6-digit code sent to\n"),
                      TextSpan(
                        text: authState.otpSentEmail.isEmpty ? "your email address" : authState.otpSentEmail,
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (authState.lastGeneratedOtp.isNotEmpty) ...[
                const SizedBox(height: 16),
                Center(
                  child: InkWell(
                    onTap: () {
                      final otp = authState.lastGeneratedOtp;
                      for (int i = 0; i < otp.length && i < 6; i++) {
                        _controllers[i].text = otp[i];
                      }
                      _focusNodes[5].requestFocus();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.touch_app_rounded, size: 16, color: Color(0xFF2563EB)),
                          const SizedBox(width: 6),
                          Text(
                            "Test Code: ${authState.lastGeneratedOtp} (Tap to autofill)",
                            style: const TextStyle(
                              color: Color(0xFF1D4ED8),
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),

              // OTP Input Boxes / Session Invalidated View
              if (!_isSessionInvalidated) ...[
                AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(_shakeAnimation.value, 0),
                      child: child,
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (index) {
                      return Container(
                        width: 44,
                        height: 54,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _localError != null ? Colors.red : const Color(0xFFE5E7EB),
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: TextField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          onChanged: (value) {
                            if (value.length == 1 && index < 5) {
                              _focusNodes[index + 1].requestFocus();
                            } else if (value.isEmpty && index > 0) {
                              _focusNodes[index - 1].requestFocus();
                            }
                          },
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                          maxLength: 1,
                          decoration: const InputDecoration(
                            counterText: "",
                            border: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
              
              if (_localError != null) ...[
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    _localError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ],

              // 3-Attempt Warning Message
              if (_attemptCount >= 3 && _attemptCount < 5 && !_isSessionInvalidated) ...[
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    "You have entered the wrong code 3 times. After one more wrong attempt, this session will expire.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Resend text / timer or Large Center Resend Code Button
              if (_isSessionInvalidated) ...[
                Center(
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _isSessionInvalidated = false;
                          _attemptCount = 0;
                          _localError = null;
                        });
                        _startTimer();
                        ref.read(authNotifierProvider.notifier).sendEmailOtp(authState.otpSentEmail);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("New verification code sent successfully!")),
                        );
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      label: const Text("Resend Code", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ] else ...[
                Center(
                  child: _secondsRemaining > 0
                      ? RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
                            children: [
                              const TextSpan(text: "Resend code in "),
                              TextSpan(
                                text: timerString,
                                style: const TextStyle(
                                  color: Color(0xFF111827),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )
                      : GestureDetector(
                          onTap: () {
                            _startTimer();
                            setState(() {
                              _localError = null;
                              _attemptCount = 0;
                            });
                            ref.read(authNotifierProvider.notifier).sendEmailOtp(authState.otpSentEmail);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Code resent successfully!")),
                            );
                          },
                          child: const Text(
                            "Resend code",
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
              ],

              const SizedBox(height: 48),

              // Verify & Continue button (hidden if session is invalidated)
              if (!_isSessionInvalidated) ...[
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _canVerify && !authState.isLoading ? const Color(0xFF131522) : const Color(0xFFE5E7EB),
                      foregroundColor: _canVerify && !authState.isLoading ? Colors.white : const Color(0xFF9CA3AF),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _canVerify && !authState.isLoading
                        ? () async {
                            setState(() {
                              _localError = null;
                            });
                            final code = _controllers.map((c) => c.text).join();
                            final success = await ref.read(authNotifierProvider.notifier).verifyEmailOtp(code);
                            if (success) {
                              await ref.read(authNotifierProvider.notifier).createAndSyncNewUser();
                            } else {
                              _onWrongOtp("Incorrect code. Please check your email and try again.");
                            }
                          }
                        : null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          authState.isLoading ? "Verifying..." : "Verify & Continue",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: _canVerify && !authState.isLoading ? Colors.white : const Color(0xFF9CA3AF),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
