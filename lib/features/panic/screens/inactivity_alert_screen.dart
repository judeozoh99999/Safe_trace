import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/custom_buttons.dart';
import 'panic_alert_screen.dart';

class InactivityAlertScreen extends StatefulWidget {
  const InactivityAlertScreen({super.key});

  @override
  State<InactivityAlertScreen> createState() => _InactivityAlertScreenState();
}

class _InactivityAlertScreenState extends State<InactivityAlertScreen> {
  int _secondsRemaining = 300; // 5 minutes countdown
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _timer?.cancel();
        _triggerAutoPanic();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _triggerAutoPanic() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const PanicAlertScreen()),
    );
  }

  String _formatTime() {
    final minutes = (_secondsRemaining / 60).floor().toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  size: 56,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                "Safety Check-In",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                "You have been inactive for over 24 hours. SafeTrace is checking in to confirm you are safe. If you do not respond before the timer expires, we will automatically alert your emergency circle.",
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Countdown Timer Display
              Text(
                _formatTime(),
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: _secondsRemaining < 60 ? AppColors.error : AppColors.warning,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "TIME REMAINING UNTIL AUTO-ALERT",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDarkSecondary,
                  letterSpacing: 1.0,
                ),
              ),

              const SizedBox(height: 64),

              // CTA buttons
              SafeTraceButton(
                text: "I am Safe - Dismiss",
                onPressed: () {
                  _timer?.cancel();
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),
              SafeTraceButton(
                text: "Trigger SOS Now",
                type: ButtonType.danger,
                onPressed: () {
                  _timer?.cancel();
                  _triggerAutoPanic();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
