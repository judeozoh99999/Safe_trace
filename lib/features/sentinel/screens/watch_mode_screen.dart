import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/speech_sentinel_service.dart';
import '../../../shared/widgets/custom_buttons.dart';
import '../../../shared/widgets/safetrace_app_bar.dart';
import '../../../core/providers/subscription_provider.dart';
import '../providers/sentinel_provider.dart';
import '../../wallet/screens/claim_plus_screen.dart';

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

  void _showSensitivityTooltip() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.primary),
            SizedBox(width: 8),
            Text("Sensitivity Levels", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("• Low (0.90 threshold): Requires highly explicit matches. Fewer false alarms."),
            SizedBox(height: 8),
            Text("• Medium (0.85 default): Recommended balance between speed and accuracy."),
            SizedBox(height: 8),
            Text("• High (0.75 threshold): Extremely sensitive. Fires alerts on lower confidence matches which may produce more false alarms."),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Got it"),
          ),
        ],
      ),
    );
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.timer_off_outlined, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text("Session Ended", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          "Your 3-minute session has ended. Upgrade to SafeTrace Plus for unlimited sessions with full speech threat detection.",
          style: TextStyle(fontSize: 14, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(sentinelProvider.notifier).dismissUpgradeModal();
              Navigator.pop(context);
            },
            child: const Text("Close", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              ref.read(sentinelProvider.notifier).dismissUpgradeModal();
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ClaimPlusScreen()),
              );
            },
            child: const Text("Unlock Now", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sentinelState = ref.watch(sentinelProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (sentinelState.isActive) {
      _pulseController.repeat();
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }

    if (sentinelState.showUpgradeModal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showUpgradeDialog();
      });
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1117) : AppColors.backgroundLight,
      appBar: const SafeTraceAppBar(
        title: "Audio Sentinel",
        showBackButton: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              Text(
                "Audio Watch Mode",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Real-time voice threat analysis & YAMNet danger sound classifier.",
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF9CA3AF) : AppColors.textLightSecondary,
                ),
                textAlign: TextAlign.center,
              ),

              // Basic Session Timer Countdown Display
              if (sentinelState.isActive && sentinelState.sessionTimeRemainingSeconds != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Text(
                    "Basic Session: ${sentinelState.sessionTimeRemainingSeconds}s remaining",
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Animated Pulsing Mic Button
              Center(
                child: GestureDetector(
                  onTap: () {
                    final wasActive = sentinelState.isActive;
                    ref.read(sentinelProvider.notifier).toggleActive();
                    if (wasActive) {
                      HapticFeedback.vibrate();
                    } else {
                      HapticFeedback.heavyImpact();
                    }
                  },
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final pulseVal = _pulseController.value;
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          if (sentinelState.isActive)
                            Container(
                              width: 120 + (pulseVal * 50),
                              height: 120 + (pulseVal * 50),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary.withOpacity(0.15 * (1 - pulseVal)),
                              ),
                            ),
                          if (sentinelState.isActive)
                            Container(
                              width: 95 + (pulseVal * 30),
                              height: 95 + (pulseVal * 30),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary.withOpacity(0.25 * (1 - pulseVal)),
                              ),
                            ),
                          Container(
                            width: 85,
                            height: 85,
                            decoration: BoxDecoration(
                              color: sentinelState.isActive
                                  ? AppColors.primary
                                  : (isDark ? const Color(0xFF1A1D27) : Colors.grey[300]),
                              shape: BoxShape.circle,
                              boxShadow: sentinelState.isActive ? AppShadows.glowPrimary : null,
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              sentinelState.isActive ? Icons.mic_rounded : Icons.mic_off_rounded,
                              color: sentinelState.isActive ? Colors.white : Colors.grey[600],
                              size: 38,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Status Title
              Text(
                sentinelState.isActive ? "LISTENING ACTIVE" : "SENTINEL INACTIVE",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: sentinelState.isActive ? AppColors.success : const Color(0xFF6B7280),
                  letterSpacing: 1.0,
                ),
              ),
              Builder(
                builder: (context) {
                  final subInfo = ref.watch(currentSubscriptionProvider);
                  if (subInfo.isFree && !sentinelState.isActive) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 6.0),
                      child: Text(
                        '3-minute sessions — Upgrade for unlimited',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(height: 12),

              // 5-Second False Alarm Overlay Banner
              if (sentinelState.countdownSeconds != null) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[900],
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.4),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "DISTRESS THREAT DETECTED!",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              "Sending FCM alert in ${sentinelState.countdownSeconds}s...",
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red[900],
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        onPressed: () {
                          ref.read(sentinelProvider.notifier).cancelFalseAlarm();
                        },
                        child: const Text("FALSE ALARM", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],

              // Sensitivity Slider & Language Controls
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2230) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Text("Sensitivity:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: _showSensitivityTooltip,
                          child: const Icon(Icons.info_outline, size: 14, color: AppColors.primary),
                        ),
                        const Spacer(),
                        Text(
                          sentinelState.sensitivityThreshold == 0.90
                              ? "Low (0.90)"
                              : (sentinelState.sensitivityThreshold == 0.75 ? "High (0.75)" : "Medium (0.85)"),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      ),
                      child: Slider(
                        value: sentinelState.sensitivityThreshold == 0.90
                            ? 0.0
                            : (sentinelState.sensitivityThreshold == 0.75 ? 1.0 : 0.5),
                        divisions: 2,
                        onChanged: (val) {
                          double th = 0.85;
                          if (val == 0.0) th = 0.90;
                          if (val == 1.0) th = 0.75;
                          ref.read(sentinelProvider.notifier).setSensitivity(th);
                        },
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Language:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        DropdownButton<AudioSentinelLanguageMode>(
                          value: sentinelState.languageMode,
                          isDense: true,
                          underline: const SizedBox(),
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black),
                          items: const [
                            DropdownMenuItem(
                              value: AudioSentinelLanguageMode.englishOnly,
                              child: Text("English Only"),
                            ),
                            DropdownMenuItem(
                              value: AudioSentinelLanguageMode.nigerianEnglishAndPidgin,
                              child: Text("Nigerian English & Pidgin"),
                            ),
                            DropdownMenuItem(
                              value: AudioSentinelLanguageMode.allSupportedLanguages,
                              child: Text("All Languages"),
                            ),
                          ],
                          onChanged: (mode) {
                            if (mode != null) {
                              ref.read(sentinelProvider.notifier).setLanguageMode(mode);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Realtime Log Card Panel
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF242838) : Colors.white,
                    borderRadius: AppBorderRadius.mdBorder,
                    border: Border.all(
                      color: isDark ? const Color(0xFF2E3347) : AppColors.dividerLight,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 5: Live transcription line at top of log card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F1117) : Colors.grey[900],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          sentinelState.liveTranscription.isNotEmpty
                              ? "Live Speech: ${sentinelState.liveTranscription}"
                              : "Live Speech: (listening for words...)",
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "REAL-TIME SENTINEL LOGS",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          Row(
                            children: [
                              _buildLegendDot(const Color(0xFF38BDF8), "Speech"),
                              const SizedBox(width: 8),
                              _buildLegendDot(const Color(0xFFF97316), "Sound"),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: sentinelState.history.isEmpty
                            ? Center(
                                child: Text(
                                  "No logs captured. Activate watch mode to monitor audio.",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? const Color(0xFF9CA3AF) : AppColors.textLightSecondary,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: sentinelState.history.length,
                                itemBuilder: (context, index) {
                                  final entry = sentinelState.history[index];

                                  // Format:
                                  // Speech -> Teal/Blue Color(0xFF38BDF8)
                                  // Sound -> Orange Color(0xFFF97316)
                                  // False Alarm -> Grey lineThrough
                                  Color entryColor = entry.type == 'speech'
                                      ? const Color(0xFF38BDF8)
                                      : const Color(0xFFF97316);

                                  if (entry.isFalseAlarm) {
                                    entryColor = const Color(0xFF9CA3AF);
                                  }

                                  return Container(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: entryColor.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: entryColor.withOpacity(0.3)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "[${entry.timestamp}]",
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 11,
                                            color: isDark ? Colors.grey[400] : Colors.grey[700],
                                          ),
                                        ),
                                        Text(
                                          "Transcribed: \"${entry.transcription}\"",
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 11,
                                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                                            decoration: entry.isFalseAlarm ? TextDecoration.lineThrough : null,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "Detected: ${entry.matchedPhrase} (${(entry.confidence * 100).toStringAsFixed(0)}%) [${entry.threatCategory}]${entry.isFalseAlarm ? ' (False Alarm)' : ''}",
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: entryColor,
                                            decoration: entry.isFalseAlarm ? TextDecoration.lineThrough : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Active CTA Button
              SafeTraceButton(
                text: sentinelState.isActive ? "Stop Watch Mode" : "Activate Watch Mode",
                type: sentinelState.isActive ? ButtonType.danger : ButtonType.primary,
                onPressed: () {
                  final wasActive = sentinelState.isActive;
                  ref.read(sentinelProvider.notifier).toggleActive();
                  if (wasActive) {
                    HapticFeedback.vibrate();
                  } else {
                    HapticFeedback.heavyImpact();
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
