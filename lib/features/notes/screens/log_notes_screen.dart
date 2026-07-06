import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/custom_buttons.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/safetrace_app_bar.dart';
import '../../location/providers/home_provider.dart';

class LogNotesScreen extends ConsumerWidget {
  const LogNotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final noteController = TextEditingController();

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: const SafeTraceAppBar(
        title: "Log Location",
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Write safety notes",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Save details about your environment. SafeTrace will analyze your note using AI to provide immediate safety advice.",
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),

              // Current Location mock card
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : Colors.white,
                  borderRadius: AppBorderRadius.mdBorder,
                  border: Border.all(
                    color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.my_location_rounded, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.md),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "CURRENT LOCATION",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          "Yaba, Lagos, Nigeria",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Notes Input Field
              const Text(
                "YOUR NOTE",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDarkSecondary,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SafeTraceTextField(
                  hintText: "E.g. Waiting at the bus stop, boarding a red bus. Traffic is building up.",
                  controller: noteController,
                  maxLines: 12,
                ),
              ),
              const SizedBox(height: 24),

              // Save CTA
              SafeTraceButton(
                text: "Log Pin & Analyze",
                onPressed: () {
                  final noteText = noteController.text.trim();
                  if (noteText.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Please enter a note before logging")),
                    );
                    return;
                  }

                  // Mock Claude AI safety advice mapping
                  String aiAdvice = "Ensure you stay in well-lit areas, keep your phone in your pocket, and look confident.";
                  if (noteText.toLowerCase().contains("traffic") || noteText.toLowerCase().contains("bus")) {
                    aiAdvice = "Keep details of the vehicle (license plate/color) memorized. Avoid sitting near exits. Stay alert during congestion.";
                  } else if (noteText.toLowerCase().contains("dark") || noteText.toLowerCase().contains("night") || noteText.toLowerCase().contains("late")) {
                    aiAdvice = "Avoid dark alleys completely. Share your live tracking link with a trusted contact. Keep your volume low if using headphones.";
                  }

                  ref.read(homeProvider.notifier).addLog("Yaba, Lagos", noteText, aiAdvice);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Location logged and analyzed by AI")),
                  );
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
