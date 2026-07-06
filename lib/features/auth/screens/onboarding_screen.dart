import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/custom_buttons.dart';
import '../providers/onboarding_provider.dart';
import 'login_screen.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageIndex = ref.watch(onboardingIndexProvider);
    final pageController = PageController(initialPage: pageIndex);

    // Watch index changes from pageController
    void onPageChanged(int index) {
      ref.read(onboardingIndexProvider.notifier).state = index;
    }

    final isDarkBackground = false;
    final backgroundColor = isDarkBackground ? AppColors.backgroundDark : AppColors.backgroundLight;
    final titleColor = isDarkBackground ? AppColors.textDarkPrimary : AppColors.textLightPrimary;
    final subtitleColor = isDarkBackground ? AppColors.textDarkSecondary : AppColors.textLightSecondary;

    final systemStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDarkBackground ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDarkBackground ? Brightness.dark : Brightness.light,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemStyle,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Column(
          children: [
            // Top Bar (Skip Button)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    child: Text(
                      "Skip",
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Onboarding Slides (PageView)
            Expanded(
              child: PageView(
                controller: pageController,
                onPageChanged: onPageChanged,
                children: [
                  _buildSlide1(titleColor, subtitleColor),
                  _buildSlide2(titleColor, subtitleColor),
                  _buildSlide3(titleColor, subtitleColor),
                ],
              ),
            ),

            // Indicators & CTA Button
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xl,
              ),
              child: Column(
                children: [
                  // Page Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      final isActive = index == pageIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.primary
                              : (isDarkBackground ? const Color(0xFF2E334D) : const Color(0xFFD2D5DF)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 32),

                  // Dynamic CTA button
                  SafeTraceButton(
                    text: pageIndex == 0
                        ? "Get Started"
                        : (pageIndex == 1 ? "Continue" : "Set Up My Circle"),
                    type: pageIndex == 1 ? ButtonType.secondary : ButtonType.primary,
                    icon: Icons.arrow_forward_ios_rounded,
                    onPressed: () {
                      if (pageIndex < 2) {
                        pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),);
  }

  // Slide 1: Stay Safe Wherever Life Takes You
  Widget _buildSlide1(Color titleColor, Color subtitleColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Large central Pin illustration
          const Expanded(
            child: Center(
              child: AnimatedLocationIllustration(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Stay Safe Wherever Life Takes You",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: titleColor,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "AI-Augmented safety alerts, trusted contacts, and real-time community intelligence to help keep you safe wherever you go.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: subtitleColor,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // Slide 2: One tap. Five people alerted instantly (Light Mode)
  Widget _buildSlide2(Color titleColor, Color subtitleColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Concentric circles with SOS and avatars
          const Expanded(
            child: Center(
              child: AnimatedSOSIllustration(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "One tap. Five people alerted instantly.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: titleColor,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Your emergency circle receives your exact location the moment you need them.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: subtitleColor,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // Slide 3: Choose who keeps you safe (Dark Mode)
  Widget _buildSlide3(Color titleColor, Color subtitleColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Circular shield with radiating avatars
          const Expanded(
            child: Center(
              child: AnimatedChooseShieldIllustration(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Choose who keeps you safe.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: titleColor,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Add up to 5 people who receive your alerts instantly — family, friends, colleagues.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: subtitleColor,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }



  // Avatar with label below for page 3
  Widget _buildAvatarWithName(String letter, String name, Color avatarColor, Color textColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: avatarColor,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            letter,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: TextStyle(
            color: textColor.withOpacity(0.7),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ==========================================
// Animated SOS Onboarding Illustration Widget
// ==========================================

class AnimatedSOSIllustration extends StatefulWidget {
  const AnimatedSOSIllustration({super.key});

  @override
  State<AnimatedSOSIllustration> createState() => _AnimatedSOSIllustrationState();
}

class _AnimatedSOSIllustrationState extends State<AnimatedSOSIllustration>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _pulseController;

  final List<AvatarData> avatars = [
    // C: top-left
    AvatarData(
      letter: "C",
      color: AppColors.avatarPurple,
      angle: -140 * pi / 180,
      radius: 120.0,
      delayStart: 0.15,
      delayEnd: 0.45,
    ),
    // T: top-right
    AvatarData(
      letter: "T",
      color: AppColors.avatarGreen,
      angle: -40 * pi / 180,
      radius: 110.0,
      delayStart: 0.3,
      delayEnd: 0.6,
    ),
    // N: middle-right
    AvatarData(
      letter: "N",
      color: AppColors.avatarNavy,
      angle: 15 * pi / 180,
      radius: 120.0,
      delayStart: 0.45,
      delayEnd: 0.75,
    ),
    // E: bottom-right
    AvatarData(
      letter: "E",
      color: AppColors.avatarOrange,
      angle: 75 * pi / 180,
      radius: 105.0,
      delayStart: 0.6,
      delayEnd: 0.9,
    ),
    // Y: bottom-left
    AvatarData(
      letter: "Y",
      color: AppColors.avatarRed,
      angle: 145 * pi / 180,
      radius: 115.0,
      delayStart: 0.2,
      delayEnd: 0.5,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  List<Widget> _buildRipples() {
    final double pulseVal = _pulseController.value;
    return [
      Container(
        width: 90 + (pulseVal * 80),
        height: 90 + (pulseVal * 80),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.primary.withOpacity(0.25 * (1.0 - pulseVal)),
            width: 2.0,
          ),
        ),
      ),
      Container(
        width: 90 + (((pulseVal + 0.5) % 1.0) * 80),
        height: 90 + (((pulseVal + 0.5) % 1.0) * 80),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.primary.withOpacity(0.25 * (1.0 - ((pulseVal + 0.5) % 1.0))),
            width: 2.0,
          ),
        ),
      ),
    ];
  }

  Widget _buildCentralSOS() {
    final double scale = 1.0 + (sin(_pulseController.value * 2 * pi) * 0.04);
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.35),
              blurRadius: 20,
              spreadRadius: 4,
            )
          ],
        ),
        alignment: Alignment.center,
        child: const Text(
          "SOS",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAvatars(Offset center) {
    return List.generate(avatars.length, (index) {
      final avatar = avatars[index];
      
      final double progress = CurvedAnimation(
        parent: _entranceController,
        curve: Interval(
          avatar.delayStart,
          avatar.delayEnd,
          curve: Curves.elasticOut,
        ),
      ).value;

      if (progress == 0.0) return const SizedBox.shrink();

      final double phase = index * (2 * pi / avatars.length);
      final double floatOffset = sin((_pulseController.value * 2 * pi) + phase) * 4.0;

      final double currentRadius = avatar.radius + floatOffset;
      final double x = center.dx + currentRadius * cos(avatar.angle);
      final double y = center.dy + currentRadius * sin(avatar.angle);

      const double avatarSize = 44.0;

      return Positioned(
        left: x - avatarSize / 2,
        top: y - avatarSize / 2,
        child: Transform.scale(
          scale: progress,
          child: _buildAvatarBadge(avatar.letter, avatar.color),
        ),
      );
    });
  }

  Widget _buildAvatarBadge(String letter, Color color) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            letter,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text(
              "!",
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const double size = 280.0;
    const Offset center = Offset(size / 2, size / 2);

    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_entranceController, _pulseController]),
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: SOSIllustrationPainter(
                    center: center,
                    lineProgress: _entranceController.value,
                    pulseProgress: _pulseController.value,
                    avatars: avatars,
                  ),
                ),
              ),
              ..._buildRipples(),
              _buildCentralSOS(),
              ..._buildAvatars(center),
            ],
          );
        },
      ),
    );
  }
}

class AvatarData {
  final String letter;
  final Color color;
  final double angle;
  final double radius;
  final double delayStart;
  final double delayEnd;

  AvatarData({
    required this.letter,
    required this.color,
    required this.angle,
    required this.radius,
    required this.delayStart,
    required this.delayEnd,
  });
}

class SOSIllustrationPainter extends CustomPainter {
  final Offset center;
  final double lineProgress;
  final double pulseProgress;
  final List<AvatarData> avatars;

  SOSIllustrationPainter({
    required this.center,
    required this.lineProgress,
    required this.pulseProgress,
    required this.avatars,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final List<double> circleRadii = [55.0, 80.0, 105.0, 130.0];
    for (final radius in circleRadii) {
      _drawDashedCircle(canvas, center, radius, paint);
    }

    final dotPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.25)
      ..style = PaintingStyle.fill;

    for (final avatar in avatars) {
      final double startDist = 45.0;
      final double endDist = startDist + (avatar.radius - startDist) * lineProgress;
      
      for (double d = startDist; d <= endDist; d += 8.0) {
        final double x = center.dx + d * cos(avatar.angle);
        final double y = center.dy + d * sin(avatar.angle);
        canvas.drawCircle(Offset(x, y), 1.5, dotPaint);
      }
    }
  }

  void _drawDashedCircle(Canvas canvas, Offset center, double radius, Paint paint) {
    const double dashDegrees = 4.0;
    const double gapDegrees = 4.0;
    final double step = (dashDegrees + gapDegrees) * pi / 180;
    final double dashArc = dashDegrees * pi / 180;

    for (double theta = 0; theta < 2 * pi; theta += step) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        theta,
        dashArc,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SOSIllustrationPainter oldDelegate) {
    return oldDelegate.lineProgress != lineProgress ||
        oldDelegate.pulseProgress != pulseProgress;
  }
}

// ==========================================
// Animated Location Illustration for Page 1
// ==========================================

class AnimatedLocationIllustration extends StatefulWidget {
  const AnimatedLocationIllustration({super.key});

  @override
  State<AnimatedLocationIllustration> createState() => _AnimatedLocationIllustrationState();
}

class _AnimatedLocationIllustrationState extends State<AnimatedLocationIllustration>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounceAnimation;
  late Animation<double> _shadowScaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: 0.0, end: -20.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _shadowScaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildFileImage(String path, Widget fallback) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(file);
      }
    } catch (_) {}
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Shadow Image at the bottom
          Positioned(
            bottom: 20,
            child: AnimatedBuilder(
              animation: _shadowScaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _shadowScaleAnimation.value,
                  child: SizedBox(
                    width: 200,
                    height: 40,
                    child: _buildFileImage(
                      "D:\\app files\\icon\\location shadown.png",
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: const BorderRadius.all(Radius.elliptical(100, 20)),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Location Pin Image bouncing above
          AnimatedBuilder(
            animation: _bounceAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _bounceAnimation.value),
                child: SizedBox(
                  width: 160,
                  height: 160,
                  child: _buildFileImage(
                    "D:\\app files\\icon\\location icon.png",
                    const Icon(
                      Icons.location_on_rounded,
                      color: AppColors.primary,
                      size: 140,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ==========================================
// Animated Choose Shield Illustration for Page 3
// ==========================================

class AnimatedChooseShieldIllustration extends StatefulWidget {
  const AnimatedChooseShieldIllustration({super.key});

  @override
  State<AnimatedChooseShieldIllustration> createState() => _AnimatedChooseShieldIllustrationState();
}

class _AnimatedChooseShieldIllustrationState extends State<AnimatedChooseShieldIllustration>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _hoverController;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _hoverController.dispose();
    super.dispose();
  }

  Widget _buildAvatarWithName(String letter, String name, Color avatarColor, double angle, double distance, double delay) {
    final scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Interval(delay, delay + 0.4, curve: Curves.elasticOut),
    );

    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _hoverController]),
      builder: (context, child) {
        if (scaleAnimation.value == 0.0) return const SizedBox.shrink();

        final hoverOffset = sin((_hoverController.value * 2 * pi) + (angle * 3)) * 6.0;
        final currentDist = distance * scaleAnimation.value + hoverOffset;
        final x = currentDist * cos(angle);
        final y = currentDist * sin(angle);

        return Transform.translate(
          offset: Offset(x, y),
          child: Transform.scale(
            scale: scaleAnimation.value,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: avatarColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: avatarColor.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    letter,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final centerScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
    );

    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Radiating dashed circles in background
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _controller.value,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5, style: BorderStyle.solid),
                  ),
                ),
              );
            },
          ),

          // Central Shield
          AnimatedBuilder(
            animation: centerScale,
            builder: (context, child) {
              return Transform.scale(
                scale: centerScale.value,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: const BoxDecoration(
                    color: Color(0xFF242946),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.shield_rounded,
                      color: AppColors.backgroundDark,
                      size: 32,
                    ),
                  ),
                ),
              );
            },
          ),

          // 5 Avatars radiating
          _buildAvatarWithName("C", "Chioma", AppColors.avatarPurple, -pi / 2, 95.0, 0.25),
          _buildAvatarWithName("T", "Tunde", AppColors.avatarGreen, -pi / 6, 100.0, 0.35),
          _buildAvatarWithName("Y", "Yusuf", AppColors.avatarRed, -5 * pi / 6, 100.0, 0.3),
          _buildAvatarWithName("N", "Ngozi", AppColors.avatarNavy, 5 * pi / 6, 100.0, 0.45),
          _buildAvatarWithName("E", "Emeka", AppColors.avatarOrange, pi / 6, 100.0, 0.4),
        ],
      ),
    );
  }
}
