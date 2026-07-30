import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../contacts/screens/contacts_setup_screen.dart';

class AudioSentinelScreen extends StatelessWidget {
  const AudioSentinelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Section (Header text)
            Padding(
              padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 24.0, bottom: 8.0),
              child: const Text(
                "Audio-Based\nEmergency Detection",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                  height: 1.25,
                ),
              ),
            ),

            // Image Card Section
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Glassmorphic Microphone Vector Illustration
                      const GlassmorphicMicrophone(),
                      const SizedBox(height: 32),

                      // Feature Red Subheading
                      const Text(
                        "Audio Sentinel Feature",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary, // Coral Red matching mockup
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Description
                      const Text(
                        "Audio Sentinel listens for signs of distress when enabled and instantly notifies your trusted contacts.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF6B7280),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Continue Button at the bottom
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF131522), // Navy button
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: Colors.black26,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const ContactsSetupScreen(),
                      ),
                      (route) => false,
                    );
                  },
                  child: const Text(
                    "Continue",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GlassmorphicMicrophone extends StatelessWidget {
  const GlassmorphicMicrophone({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
      ),
      child: Center(
        child: SizedBox(
          width: 200,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 3D Microphone Body (Glass dome)
              Positioned(
                top: 20,
                child: Container(
                  width: 90,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(45),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.95),
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withOpacity(0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    // Inner Soundwave/Voice waves
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildWaveBar(14, 0.4),
                        const SizedBox(width: 4),
                        _buildWaveBar(24, 0.7),
                        const SizedBox(width: 4),
                        _buildWaveBar(36, 1.0),
                        const SizedBox(width: 4),
                        _buildWaveBar(24, 0.7),
                        const SizedBox(width: 4),
                        _buildWaveBar(14, 0.4),
                      ],
                    ),
                  ),
                ),
              ),

              // Stand Base (Chrome U-shape ring holding the dome)
              Positioned(
                top: 90,
                child: Container(
                  width: 120,
                  height: 70,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(60),
                      bottomRight: Radius.circular(60),
                    ),
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300, width: 6),
                      left: BorderSide(color: Colors.grey.shade300, width: 6),
                      right: BorderSide(color: Colors.grey.shade300, width: 6),
                    ),
                  ),
                ),
              ),

              // Stand Stem
              Positioned(
                top: 160,
                child: Container(
                  width: 8,
                  height: 24,
                  color: Colors.grey.shade300,
                ),
              ),

              // Stand Base circle
              Positioned(
                top: 180,
                child: Container(
                  width: 70,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaveBar(double height, double opacity) {
    return Container(
      width: 4,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF60A5FA).withOpacity(opacity),
            const Color(0xFF818CF8).withOpacity(opacity),
          ],
        ),
      ),
    );
  }
}
