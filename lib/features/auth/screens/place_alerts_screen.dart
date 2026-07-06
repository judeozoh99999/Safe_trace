import 'package:flutter/material.dart';
import 'audio_sentinel_screen.dart';

class PlaceAlertsScreen extends StatefulWidget {
  const PlaceAlertsScreen({super.key});

  @override
  State<PlaceAlertsScreen> createState() => _PlaceAlertsScreenState();
}

class _PlaceAlertsScreenState extends State<PlaceAlertsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Calculate position along quadratic bezier curve P0 -> P1 -> P2
  Offset _getBezierPosition(double t, Offset p0, Offset p1, Offset p2) {
    final double u = 1.0 - t;
    final double tt = t * t;
    final double uu = u * u;

    final double x = uu * p0.dx + 2 * u * t * p1.dx + tt * p2.dx;
    final double y = uu * p0.dy + 2 * u * t * p1.dy + tt * p2.dy;

    return Offset(x, y);
  }

  @override
  Widget build(BuildContext context) {
    const double containerWidth = 320.0;
    const double containerHeight = 380.0;

    // Standard coordinate mapping inside container
    final Offset homePos = Offset(containerWidth * 0.3, containerHeight * 0.55);
    final Offset controlPos = Offset(containerWidth * 0.52, containerHeight * 0.45);
    final Offset destPos = Offset(containerWidth * 0.71, containerHeight * 0.425);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Section (Headers)
            Padding(
              padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 24.0, bottom: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Place Alerts keep you informed",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    "Get notifications when Circle members come and go",
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF6B7280),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // Map Illustration Section
            Expanded(
              child: Center(
                child: Container(
                  width: containerWidth,
                  height: containerHeight,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2EFE9), // light beige map background
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 16,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        final double rawVal = _controller.value;
                        
                        // 1. Map motion timeline
                        // 0.0 -> 0.1: stays at home
                        // 0.1 -> 0.7: drives to destination
                        // 0.7 -> 0.9: stays at destination
                        // 0.9 -> 1.0: resets back to home (fade transition)
                        double driveProgress = 0.0;
                        double opacity = 1.0;
                        if (rawVal > 0.1 && rawVal <= 0.7) {
                          driveProgress = (rawVal - 0.1) / 0.6;
                        } else if (rawVal > 0.7 && rawVal <= 0.9) {
                          driveProgress = 1.0;
                        } else if (rawVal > 0.9) {
                          driveProgress = 1.0;
                          opacity = 1.0 - ((rawVal - 0.9) / 0.1);
                        }

                        // 2. Notification slide down timeline
                        // Slides in between t = 0.15 and t = 0.3
                        double toastSlide = -80.0;
                        double toastOpacity = 0.0;
                        if (rawVal > 0.15 && rawVal <= 0.3) {
                          final double p = (rawVal - 0.15) / 0.15;
                          toastSlide = -80.0 + (96.0 * p); // slides down to top: 16
                          toastOpacity = p;
                        } else if (rawVal > 0.3 && rawVal <= 0.9) {
                          toastSlide = 16.0;
                          toastOpacity = 1.0;
                        } else if (rawVal > 0.9) {
                          toastSlide = 16.0;
                          toastOpacity = 1.0 - ((rawVal - 0.9) / 0.1);
                        }

                        // 3. Geofence pulse waves
                        final double pulseVal = (rawVal * 3) % 1.0;
                        final double pulseRadius1 = 80.0 + (pulseVal * 50.0);
                        final double pulseRadius2 = 50.0 + (((pulseVal + 0.5) % 1.0) * 50.0);

                        // Emeka marker position calculation
                        final Offset emekaOffset = _getBezierPosition(
                          driveProgress,
                          homePos,
                          controlPos,
                          destPos,
                        );

                        return Stack(
                          children: [
                            // Map Roads Grid
                            Positioned.fill(
                              child: CustomPaint(
                                painter: MapGridPainter(),
                              ),
                            ),

                            // Route Line
                            Positioned.fill(
                              child: CustomPaint(
                                painter: RouteLinePainter(),
                              ),
                            ),

                            // Home Geofence Pulsing Rings
                            Align(
                              alignment: const Alignment(-0.4, 0.1),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Ring 1
                                  Container(
                                    width: pulseRadius1,
                                    height: pulseRadius1,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF1D3557).withOpacity(0.05 * (1.0 - pulseVal)),
                                      border: Border.all(
                                        color: const Color(0xFF1D3557).withOpacity(0.12 * (1.0 - pulseVal)),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                  // Ring 2
                                  Container(
                                    width: pulseRadius2,
                                    height: pulseRadius2,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF1D3557).withOpacity(0.06 * (1.0 - ((pulseVal + 0.5) % 1.0))),
                                      border: Border.all(
                                        color: const Color(0xFF1D3557).withOpacity(0.15 * (1.0 - ((pulseVal + 0.5) % 1.0))),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Home Marker Icon
                            Align(
                              alignment: const Alignment(-0.4, 0.1),
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    )
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.home_rounded,
                                  color: Color(0xFF1D3557),
                                  size: 28,
                                ),
                              ),
                            ),

                            // Animating Emeka Avatar Marker along curve
                            Positioned(
                              left: emekaOffset.dx - 26,
                              top: emekaOffset.dy - 26,
                              child: Opacity(
                                opacity: opacity,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFE68A00),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black12,
                                            blurRadius: 8,
                                            offset: Offset(0, 3),
                                          )
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: const Text(
                                        "EO",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    // Moving Car badge
                                    Positioned(
                                      top: -6,
                                      right: -6,
                                      child: Container(
                                        width: 22,
                                        height: 22,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF4A90E2),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black12,
                                              blurRadius: 4,
                                            )
                                          ],
                                        ),
                                        alignment: Alignment.center,
                                        child: const Text(
                                          "🚗",
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Animated Alert Notification Card
                            Positioned(
                              top: toastSlide,
                              left: 16,
                              right: 16,
                              child: Opacity(
                                opacity: toastOpacity,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      )
                                    ],
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  child: Row(
                                    children: [
                                      // Profile image with pin
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFE68A00),
                                              shape: BoxShape.circle,
                                            ),
                                            alignment: Alignment.center,
                                            child: const Text(
                                              "EO",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            bottom: -2,
                                            right: -2,
                                            child: Container(
                                              width: 14,
                                              height: 14,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF1D3557),
                                                shape: BoxShape.circle,
                                              ),
                                              alignment: Alignment.center,
                                              child: const Icon(
                                                Icons.location_on,
                                                color: Colors.white,
                                                size: 9,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 12),
                                      // Message
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Text(
                                              "Emeka",
                                              style: TextStyle(
                                                color: Color(0xFF111827),
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              "Left Home",
                                              style: TextStyle(
                                                color: Color(0xFF6B7280),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Time stamp
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(
                                            Icons.access_time_filled,
                                            size: 13,
                                            color: Color(0xFF9CA3AF),
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            "now",
                                            style: TextStyle(
                                              color: Color(0xFF9CA3AF),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
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
                    backgroundColor: const Color(0xFF131522),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: Colors.black26,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AudioSentinelScreen(),
                      ),
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

class MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 24.0
      ..style = PaintingStyle.stroke;

    final parkPaint = Paint()
      ..color = const Color(0xFFE2F0D9)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(210, 80, 50, 40),
        const Radius.circular(8),
      ),
      parkPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(110, 270, 70, 50),
        const Radius.circular(8),
      ),
      parkPaint,
    );

    canvas.drawLine(Offset(size.width * 0.15, 0), Offset(size.width * 0.15, size.height), roadPaint);
    canvas.drawLine(Offset(size.width * 0.45, 0), Offset(size.width * 0.45, size.height), roadPaint);
    canvas.drawLine(Offset(size.width * 0.8, 0), Offset(size.width * 0.8, size.height), roadPaint);

    canvas.drawLine(Offset(0, size.height * 0.2), Offset(size.width, size.height * 0.2), roadPaint);
    canvas.drawLine(Offset(0, size.height * 0.5), Offset(size.width, size.height * 0.5), roadPaint);
    canvas.drawLine(Offset(0, size.height * 0.85), Offset(size.width, size.height * 0.85), roadPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RouteLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final routePaint = Paint()
      ..color = const Color(0xFF1D3557)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(size.width * 0.3, size.height * 0.55);
    path.quadraticBezierTo(
      size.width * 0.52,
      size.height * 0.45,
      size.width * 0.71,
      size.height * 0.425,
    );

    canvas.drawPath(path, routePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
