import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../panic/screens/panic_alert_screen.dart';
import '../../notes/screens/log_notes_screen.dart';
import 'nearby_alert_screen.dart';
import 'notifications_screen.dart';
import '../../home_shell.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _rippleController;
  late AnimationController _panicHoldController;
  bool _isHoldingPanic = false;


  @override
  void initState() {
    super.initState();
    // 1. Repeating concentric ripple controller for the panic button
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    // 2. Panic button hold progress controller (2 seconds hold)
    _panicHoldController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _panicHoldController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _triggerPanic();
      }
    });
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _panicHoldController.dispose();
    super.dispose();
  }

  void _onPanicStart() {
    setState(() {
      _isHoldingPanic = true;
    });
    _panicHoldController.forward();
  }

  void _onPanicEnd() {
    if (_panicHoldController.status != AnimationStatus.completed) {
      setState(() {
        _isHoldingPanic = false;
      });
      _panicHoldController.reverse();
    }
  }

  void _triggerPanic() {
    _panicHoldController.reset();
    setState(() {
      _isHoldingPanic = false;
    });
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PanicAlertScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), // Very clean off-white background
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  // User Avatar "JN"
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFF131522), // Dark Navy
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      "JN",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Greetings
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "Good evening",
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Jude 👋",
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF111827),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status Pill "Safe"
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFC8E6C9), width: 1),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.circle, size: 8, color: Color(0xFF2E7D32)),
                        SizedBox(width: 6),
                        Text(
                          "Safe",
                          style: TextStyle(
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Share icon (red button)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD32F2F),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.share, color: Colors.white, size: 18),
                      onPressed: () {},
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                      );
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: const Icon(Icons.notifications_none, color: Color(0xFF111827), size: 20),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const Text(
              "EMERGENCY PANIC",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Color(0xFF9CA3AF),
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // 2. Large Central Panic Button with Looping Ripples
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 320,
                  height: 320,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Concentric Looping Ripple Outlines
                      AnimatedBuilder(
                        animation: _rippleController,
                        builder: (context, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: List.generate(3, (index) {
                              // Stagger the start times of the ripples
                              final double progress = (_rippleController.value + (index / 3.0)) % 1.0;
                              final double scale = 1.0 + (progress * 1.5);
                              final double opacity = (1.0 - progress) * 0.45;

                              return Transform.scale(
                                scale: scale,
                                child: Opacity(
                                  opacity: opacity,
                                  child: Container(
                                    width: 130,
                                    height: 130,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFFEB444E).withOpacity(0.4),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          );
                        },
                      ),

                      // SOS HOLD BUTTON
                      GestureDetector(
                        onLongPressStart: (_) => _onPanicStart(),
                        onLongPressEnd: (_) => _onPanicEnd(),
                        child: AnimatedBuilder(
                          animation: _panicHoldController,
                          builder: (context, child) {
                            final double scale = 1.0 + (_panicHoldController.value * 0.15);

                            return Transform.scale(
                              scale: scale,
                              child: Container(
                                width: 144,
                                height: 144,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEB444E), // Coral red
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFEB444E).withOpacity(0.45),
                                      blurRadius: 24,
                                      offset: const Offset(0, 10),
                                    )
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Holding Progress Overlay Ring
                                    if (_isHoldingPanic)
                                      SizedBox(
                                        width: 134,
                                        height: 134,
                                        child: CircularProgressIndicator(
                                          value: _panicHoldController.value,
                                          strokeWidth: 5,
                                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                          backgroundColor: Colors.white24,
                                        ),
                                      ),
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Icon(
                                          Icons.shield_outlined,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                        SizedBox(height: 6),
                                        Text(
                                          "HOLD TO ALERT\nCONTACTS",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                            height: 1.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
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
            ),

            const Text(
              "Hold for 2 seconds to send emergency alert",
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),

            // 3. Grid actions & Recent Activity Section
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    // Grid Cards Row
                    Row(
                      children: [
                        // Log My Location Card
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const LogNotesScreen()),
                              );
                            },
                            child: Container(
                              height: 125,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF2FF),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.all(6),
                                    child: const Icon(Icons.location_on_outlined, color: Color(0xFF4F46E5), size: 20),
                                  ),
                                  const Spacer(),
                                  const Text(
                                    "Log My Location",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    "Add a safety note",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Nearby Alert Card
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const NearbyAlertScreen()),
                              );
                            },
                            child: Container(
                              height: 125,
                              decoration: BoxDecoration(
                                color: const Color(0xFF131522), // Dark Navy matching mockup
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  )
                                ],
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.all(6),
                                    child: const Icon(Icons.radar, color: Colors.white, size: 20),
                                  ),
                                  const Spacer(),
                                  const Text(
                                    "Nearby Alert",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                      "Connect with your nearby contact",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white60,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Plan a Safe Route Card
                    GestureDetector(
                      onTap: () {
                        ref.read(homeShellIndexProvider.notifier).state = 1;
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1F2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.all(8),
                              child: const Icon(Icons.navigation_outlined, color: Color(0xFFF43F5E), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    "Plan a Safe Route",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    "AI-Augmented route intelligence",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Recent Activity
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          "Recent Activity",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                          ),
                        ),
                        Text(
                          "See all",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Recent Activity List Items
                    _buildActivityItem(
                      "Victoria Island, Lagos",
                      "Arrived at client meeting safely.",
                      "2h ago",
                    ),
                    _buildActivityItem(
                      "Lekki Phase 1, Lagos",
                      "Heading to work, traffic on Lekki-Epe.",
                      "5h ago",
                    ),
                    _buildActivityItem(
                      "Oniru Estate, V/I",
                      "Left home, all clear.",
                      "8h ago",
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(String title, String subtitle, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFEEF2FF),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(8),
            child: const Icon(Icons.location_on, color: Color(0xFF4F46E5), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF9CA3AF),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
