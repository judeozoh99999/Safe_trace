import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/custom_buttons.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/safetrace_app_bar.dart';
import '../../location/providers/home_provider.dart';
import '../../location/services/location_service.dart';
import '../services/ai_service.dart';
import 'package:geolocator/geolocator.dart';

class LogNotesScreen extends ConsumerStatefulWidget {
  const LogNotesScreen({super.key});

  @override
  ConsumerState<LogNotesScreen> createState() => _LogNotesScreenState();
}

class _LogNotesScreenState extends ConsumerState<LogNotesScreen> {
  final _noteController = TextEditingController();
  bool _isLoading = false;
  String _address = "Fetching current location...";
  Position? _currentPosition;
  bool _isFetchingLocation = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentLocation();
    });
  }

  Future<void> _loadCurrentLocation() async {
    if (!mounted) return;
    setState(() {
      _isFetchingLocation = true;
      _address = "Fetching current location...";
    });

    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos != null) {
        final addr = await LocationService.reverseGeocode(pos.latitude, pos.longitude);
        if (mounted) {
          setState(() {
            _currentPosition = pos;
            _address = addr;
            _isFetchingLocation = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _address = "Failed to fetch GPS coordinates. Ensure location is enabled.";
            _isFetchingLocation = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _address = "Error fetching location: $e";
          _isFetchingLocation = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locationText = _address;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      resizeToAvoidBottomInset: true,
      appBar: const SafeTraceAppBar(
        title: "Log Location",
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
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
                const SizedBox(height: 24),

                // Current Location card
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
                      _isFetchingLocation
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            )
                          : const Icon(Icons.my_location_rounded, color: AppColors.primary),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
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
                            Text(
                              locationText,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Notes Input label
                Text(
                  "YOUR NOTE",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),

                // Note input — flexible height to avoid overflow
                SafeTraceTextField(
                  hintText: "E.g. Waiting at the bus stop, boarding a red bus. Traffic is building up.",
                  controller: _noteController,
                  maxLines: 6,
                ),
                const SizedBox(height: 20),

                // Save CTA
                SafeTraceButton(
                  text: _isLoading ? "Logging location..." : "Log Location",
                  onPressed: _isLoading
                      ? null
                      : () async {
                          final noteText = _noteController.text.trim();
                          if (noteText.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Please enter a note before logging")),
                            );
                            return;
                          }

                          setState(() {
                            _isLoading = true;
                          });

                          // Local zero-cost safety advice mapping via AiService
                          final adviceList = AiService.analyzeSafetyNote(noteText);
                          final aiAdvice = adviceList.join("\n");

                          try {
                            await ref.read(homeProvider.notifier).addManualLog(
                              noteText,
                              aiAdvice,
                              lat: _currentPosition?.latitude,
                              lng: _currentPosition?.longitude,
                              address: _address,
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Location logged and analyzed by AI")),
                              );
                              Navigator.pop(context);
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                              setState(() {
                                _isLoading = false;
                              });
                            }
                          }
                        },
                ),
                // Space below button for keyboard clearance
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
