import 'dart:async';
import 'package:flutter/material.dart';

class PanicAlertScreen extends StatefulWidget {
  const PanicAlertScreen({super.key});

  @override
  State<PanicAlertScreen> createState() => _PanicAlertScreenState();
}

class _PanicAlertScreenState extends State<PanicAlertScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _cancelHoldController;
  late AnimationController _staggerController;

  bool _isHoldingCancel = false;
  bool _liveLocationActive = true;

  // Active status blinker
  bool _blinkStatus = true;
  Timer? _blinkTimer;

  // List of contacts showing in mockup
  final List<Map<String, dynamic>> _contacts = [
    {'initials': 'CO', 'color': const Color(0xFF7C3AED)}, // Purple
    {'initials': 'TA', 'color': const Color(0xFF10B981)}, // Green
    {'initials': 'NE', 'color': const Color(0xFF1E3A8A)}, // Navy
    {'initials': 'EO', 'color': const Color(0xFFD97706)}, // Orange
    {'initials': 'YM', 'color': const Color(0xFF06B6D4)}, // Cyan
  ];

  @override
  void initState() {
    super.initState();

    // 1. Repeating warning circle pulse (scale + glow)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // 2. Cancel hold button controller (5 seconds hold to cancel)
    _cancelHoldController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _cancelHoldController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _cancelPanic();
      }
    });

    // 3. Staggered contact entrance/checkmark pop animation
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _staggerController.forward();

    // Blinking timer for the active pill
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      setState(() {
        _blinkStatus = !_blinkStatus;
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _cancelHoldController.dispose();
    _staggerController.dispose();
    _blinkTimer?.cancel();
    super.dispose();
  }

  void _onHoldStart() {
    setState(() {
      _isHoldingCancel = true;
    });
    _cancelHoldController.forward();
  }

  void _onHoldEnd() {
    if (_cancelHoldController.status != AnimationStatus.completed) {
      setState(() {
        _isHoldingCancel = false;
      });
      _cancelHoldController.reverse();
    }
  }

  void _cancelPanic() {
    _cancelHoldController.reset();
    setState(() {
      _isHoldingCancel = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Panic alert resolved. Emergency contacts updated.")),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD32F2F), // Bright warning red matching image3
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              // 4. Subtle backdrop pulse scale
              final double bgPulse = 1.0 + (_pulseController.value * 0.03);

              return Transform.scale(
                scale: bgPulse,
                child: Column(
                  children: [
                    // Emergency Active Top Pill
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white30, width: 1),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Opacity(
                            opacity: _blinkStatus ? 1.0 : 0.25,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            "EMERGENCY ACTIVE",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(flex: 2),

                    // Central Warning Exclamation Circle
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Pulsing outer halo
                        Container(
                          width: 120 + (_pulseController.value * 24.0),
                          height: 120 + (_pulseController.value * 24.0),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12 * (1.0 - _pulseController.value)),
                            shape: BoxShape.circle,
                          ),
                        ),
                        // Inner circle
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.white,
                            size: 52,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // ALERT SENT Headings
                    const Text(
                      "ALERT SENT",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        "Your location has been sent to 5 contacts.\nHelp is on the way.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          height: 1.45,
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Staggered Contact Avatars Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_contacts.length, (index) {
                        final contact = _contacts[index];

                        // Stagger progress calculation
                        final double start = index * 0.15;
                        final double end = start + 0.3;
                        final double popVal = CurvedAnimation(
                          parent: _staggerController,
                          curve: Interval(start, end, curve: Curves.elasticOut),
                        ).value;

                        return Transform.scale(
                          scale: popVal,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0),
                            child: Stack(
                              alignment: Alignment.bottomCenter,
                              clipBehavior: Clip.none,
                              children: [
                                // Main Avatar Circle
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: contact['color'],
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    contact['initials'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                // Checkmark Badge overlay at the bottom
                                Positioned(
                                  bottom: -4,
                                  child: Transform.scale(
                                    scale: popVal > 0.8 ? 1.0 : 0.0,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF10B981), // Green
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(3),
                                      child: const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 10,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),

                    const Spacer(flex: 2),

                    // Actions Container
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Live Location Toggle Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.share, color: Colors.white, size: 20),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        "Live Location Sharing",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        "Contacts can track you in real-time",
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Switch.adaptive(
                                value: _liveLocationActive,
                                activeColor: const Color(0xFF10B981),
                                activeTrackColor: const Color(0xFF10B981).withOpacity(0.3),
                                onChanged: (value) {
                                  setState(() {
                                    _liveLocationActive = value;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(color: Colors.white24, height: 1),
                          const SizedBox(height: 12),

                          // Call Emergency (199) Outlined Button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white54, width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () {},
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.phone_in_talk, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    "Call Emergency (199)",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(flex: 2),

                    // Hold to Cancel panic button
                    GestureDetector(
                      onLongPressStart: (_) => _onHoldStart(),
                      onLongPressEnd: (_) => _onHoldEnd(),
                      child: Container(
                        height: 60,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF7A1B1C), // Deep dark red warning cancel
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Progress bar indicator
                            if (_isHoldingCancel)
                              Positioned.fill(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: AnimatedBuilder(
                                    animation: _cancelHoldController,
                                    builder: (context, child) {
                                      return FractionallySizedBox(
                                        widthFactor: _cancelHoldController.value,
                                        child: Container(
                                          color: Colors.white24,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            Text(
                              _isHoldingCancel
                                  ? "HOLDING TO CANCEL..."
                                  : "Hold 5s — False Alarm / Cancel",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
