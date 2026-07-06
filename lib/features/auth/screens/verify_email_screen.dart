import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import 'place_alerts_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  int _secondsRemaining = 30;
  Timer? _timer;
  bool _canVerify = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    for (var controller in _controllers) {
      controller.addListener(_checkOtpCompleteness);
    }
  }

  void _startTimer() {
    _secondsRemaining = 30;
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

  @override
  void dispose() {
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
    // Format timer digits
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

              // Lock Icon in rounded container (Screen 4)
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
                  text: const TextSpan(
                    style: TextStyle(fontSize: 15, color: Color(0xFF6B7280), height: 1.45),
                    children: [
                      TextSpan(text: "Enter the 6-digit code sent to\n"),
                      TextSpan(
                        text: "yourgmail@gmail.com",
                        style: TextStyle(
                          color: Color(0xFF111827),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // OTP Input Boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return Container(
                    width: 44,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
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
              const SizedBox(height: 32),

              // Resend text / timer
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
              const SizedBox(height: 64),

              // Verify & Continue button (conditional styling)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canVerify ? const Color(0xFF131522) : const Color(0xFFE5E7EB),
                    foregroundColor: _canVerify ? Colors.white : const Color(0xFF9CA3AF),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _canVerify
                      ? () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const PlaceAlertsScreen(),
                            ),
                            (route) => false,
                          );
                        }
                      : null,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Verify & Continue",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: _canVerify ? Colors.white : const Color(0xFF9CA3AF),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
