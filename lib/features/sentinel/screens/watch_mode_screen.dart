import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/custom_buttons.dart';
import '../../../shared/widgets/safetrace_app_bar.dart';
import '../providers/sentinel_provider.dart';

class WatchModeScreen extends ConsumerStatefulWidget {
  const WatchModeScreen({super.key});

  @override
  ConsumerState<WatchModeScreen> createState() => _WatchModeScreenState();
}

class _WatchModeScreenState extends ConsumerState<WatchModeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sentinelState = ref.watch(sentinelProvider);
    const bool isDark = false;

    if (sentinelState.isActive) {
      _pulseController.repeat();
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: const SafeTraceAppBar(
        title: "Audio Sentinel",
        showBackButton: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              const Text(
                "Audio Watch Mode",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Opt-in background voice sentinel. SafeTrace processes microphone input locally using AI to detect distress signals.",
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Animated Pulsing Mic Button
              Center(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final pulseVal = _pulseController.value;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Wave 1
                        if (sentinelState.isActive)
                          Container(
                            width: 140 + (pulseVal * 60),
                            height: 140 + (pulseVal * 60),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withOpacity(0.15 * (1 - pulseVal)),
                            ),
                          ),
                        // Wave 2
                        if (sentinelState.isActive)
                          Container(
                            width: 110 + (pulseVal * 40),
                            height: 110 + (pulseVal * 40),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withOpacity(0.25 * (1 - pulseVal)),
                            ),
                          ),
                        // Inner Mic Button
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: sentinelState.isActive ? AppColors.primary : (isDark ? AppColors.cardDark : Colors.grey[300]),
                            shape: BoxShape.circle,
                            boxShadow: sentinelState.isActive ? AppShadows.glowPrimary : null,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            sentinelState.isActive ? Icons.mic_rounded : Icons.mic_off_rounded,
                            color: sentinelState.isActive ? Colors.white : Colors.grey[600],
                            size: 44,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Status Title
              Text(
                sentinelState.isActive ? "LISTENING ACTIVE" : "SENTINEL INACTIVE",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: sentinelState.isActive ? AppColors.success : const Color(0xFF6B7280),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),

              // Last Classification Display
              if (sentinelState.isActive) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Detected: ",
                      style: TextStyle(color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary),
                    ),
                    Text(
                      sentinelState.lastClassification,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    Text(
                      " (${(sentinelState.confidence * 100).toStringAsFixed(0)}%)",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  "Tap the button below to turn on Watch Mode",
                  style: TextStyle(fontSize: 13, color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary),
                ),
              ],
              const SizedBox(height: 32),

              // Realtime Audio classifications log panel
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : Colors.white,
                    borderRadius: AppBorderRadius.mdBorder,
                    border: Border.all(
                      color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "REAL-TIME LOGS (ON-DEVICE YAMNET)",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: sentinelState.history.isEmpty
                            ? Center(
                                child: Text(
                                  "No logs captured. Turn on watch mode to monitor audio.",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: sentinelState.history.length,
                                itemBuilder: (context, index) {
                                  final log = sentinelState.history[index];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Text(
                                      log,
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                        color: isDark ? Colors.green[400] : Colors.green[800],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Active CTA Button
              SafeTraceButton(
                text: sentinelState.isActive ? "Stop Watch Mode" : "Activate Watch Mode",
                type: sentinelState.isActive ? ButtonType.danger : ButtonType.primary,
                onPressed: () {
                  final wasActive = sentinelState.isActive;
                  ref.read(sentinelProvider.notifier).toggleActive();
                  if (wasActive) {
                    SystemSound.play(SystemSoundType.alert);
                    HapticFeedback.vibrate();
                  } else {
                    SystemSound.play(SystemSoundType.click);
                    HapticFeedback.heavyImpact();
                  }
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
