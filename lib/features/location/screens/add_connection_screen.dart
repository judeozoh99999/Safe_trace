import 'package:flutter/material.dart';

enum ConnectionType { personal, venue, responder }

class AddConnectionScreen extends StatefulWidget {
  const AddConnectionScreen({super.key});

  @override
  State<AddConnectionScreen> createState() => _AddConnectionScreenState();
}

class _AddConnectionScreenState extends State<AddConnectionScreen> {
  bool _isEnterIdTab = true;
  bool _requestSent = false;
  final TextEditingController _idController = TextEditingController(text: "JN-4892-X7");
  ConnectionType _selectedType = ConnectionType.personal;

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF111827), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Add Connection",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
            ),
            SizedBox(height: 2),
            Text(
              "Enter an ID or scan a QR code",
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Enter ID Tab Button
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isEnterIdTab ? const Color(0xFF131522) : const Color(0xFFF3F4F6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        setState(() {
                          _isEnterIdTab = true;
                        });
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.numbers,
                            color: _isEnterIdTab ? Colors.white : const Color(0xFF6B7280),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Enter ID",
                            style: TextStyle(
                              color: _isEnterIdTab ? Colors.white : const Color(0xFF6B7280),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Scan QR Tab Button
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: !_isEnterIdTab ? const Color(0xFF131522) : const Color(0xFFF3F4F6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        setState(() {
                          _isEnterIdTab = false;
                        });
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_scanner_rounded,
                            color: !_isEnterIdTab ? Colors.white : const Color(0xFF6B7280),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Scan QR",
                            style: TextStyle(
                              color: !_isEnterIdTab ? Colors.white : const Color(0xFF6B7280),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: _requestSent ? _buildRequestSentBody() : _buildActiveTabBody(),
      ),
    );
  }

  Widget _buildActiveTabBody() {
    if (_isEnterIdTab) {
      return _buildEnterIdBody();
    } else {
      return _buildScanQrBody();
    }
  }

  // --- TAB 1: ENTER ID VIEW ---
  Widget _buildEnterIdBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Your ID Card
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF131522), // Dark Navy
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Row(
                      children: [
                        Icon(Icons.shield_outlined, color: Colors.white70, size: 16),
                        SizedBox(width: 6),
                        Text(
                          "YOUR NEARBY ALERT ID",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Icon(Icons.copy_rounded, color: Colors.white70, size: 18),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  "JN-4892-X7",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Share this with others so they can connect with you",
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Title Header
          const Text(
            "Connect with someone",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Enter the Nearby Alert ID of a person, venue, or emergency responder.",
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),

          // Nearby Alert ID Text Field Label
          const Text(
            "NEARBY ALERT ID",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6B7280),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),

          // ID Field
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.numbers, color: Color(0xFF9CA3AF), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _idController,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "After sending, the other party must approve before the connection becomes active.",
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 24),

          // Connection Type Header
          const Text(
            "CONNECTION TYPE",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6B7280),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),

          // Selector Cards Row
          Row(
            children: [
              _buildTypeBox(ConnectionType.personal, Icons.person, "Personal", "Friends & family"),
              const SizedBox(width: 8),
              _buildTypeBox(ConnectionType.venue, Icons.apartment_rounded, "Venue", "Hotels, malls"),
              const SizedBox(width: 8),
              _buildTypeBox(ConnectionType.responder, Icons.local_taxi_rounded, "Responder", "Emergency services"),
            ],
          ),
          const SizedBox(height: 36),

          // Action button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF131522),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () {
                setState(() {
                  _requestSent = true;
                });
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    "Send Connection Request",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBox(ConnectionType type, IconData icon, String label, String sub) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = type;
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF3F4F6) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? const Color(0xFF131522) : const Color(0xFFE5E7EB),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF9CA3AF),
                size: 24,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: const TextStyle(
                  fontSize: 9,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- TAB 2: SCAN QR VIEW (Scan QR Screen.png) ---
  Widget _buildScanQrBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Simulated QR Viewport
          Container(
            height: 280,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF0C0E1A),
              borderRadius: BorderRadius.circular(24),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Corner Red Frames
                  Positioned(
                    top: 20,
                    left: 20,
                    child: _buildCornerFrame(top: true, left: true),
                  ),
                  Positioned(
                    top: 20,
                    right: 20,
                    child: _buildCornerFrame(top: true, left: false),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: _buildCornerFrame(top: false, left: true),
                  ),
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: _buildCornerFrame(top: false, left: false),
                  ),

                  // Animated Scanning Laser line
                  const ScanningLaserLine(),

                  // Bottom help text inside viewport
                  const Positioned(
                    bottom: 32,
                    child: Text(
                      "Point at a Nearby Alert QR code",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            "Scan the Nearby Alert QR code displayed by a venue, responder, or contact to connect instantly.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 20),

          const Text(
            "Or show your QR code",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),

          // User's QR Code Card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Rendered vector/mock QR Code pattern
                Container(
                  width: 140,
                  height: 140,
                  color: Colors.white,
                  child: CustomPaint(
                    painter: QrCodeMockPainter(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "JN-4892-X7",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF6B7280),
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCornerFrame({required bool top, required bool left}) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        border: Border(
          top: top ? const BorderSide(color: Color(0xFFEF4444), width: 3) : BorderSide.none,
          bottom: !top ? const BorderSide(color: Color(0xFFEF4444), width: 3) : BorderSide.none,
          left: left ? const BorderSide(color: Color(0xFFEF4444), width: 3) : BorderSide.none,
          right: !left ? const BorderSide(color: Color(0xFFEF4444), width: 3) : BorderSide.none,
        ),
      ),
    );
  }

  // --- TAB 3: REQUEST SENT SUCCESS VIEW (Request Sent Screen.png) ---
  Widget _buildRequestSentBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Green plane airplane circle
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFC8E6C9), width: 1.5),
            ),
            padding: const EdgeInsets.all(24),
            child: const Icon(
              Icons.send_rounded,
              color: Color(0xFF2E7D32),
              size: 40,
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            "Request Sent!",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),

          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14, height: 1.45),
              children: [
                TextSpan(text: "Your connection request has been sent to "),
                TextSpan(
                  text: "JN-4892-X7",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                ),
                TextSpan(text: ". They must approve it before the connection becomes active."),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Yellow Info Banner
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFEF3C7)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.access_time, color: Color(0xFFD97706), size: 16),
                        SizedBox(width: 8),
                        Text(
                          "Pending Approval",
                          style: TextStyle(
                            color: Color(0xFF92400E),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        "PENDING",
                        style: TextStyle(
                          color: Color(0xFFD97706),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                RichText(
                  text: const TextSpan(
                    style: TextStyle(color: Color(0xFF92400E), fontSize: 12, height: 1.4),
                    children: [
                      TextSpan(text: "Waiting for the other party to accept. You'll receive a notification once approved. Connection expires in "),
                      TextSpan(
                        text: "24 hours",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: " if not approved."),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF131522),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      "View Dashboard",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      setState(() {
                        _requestSent = false;
                      });
                    },
                    child: const Text(
                      "Add More",
                      style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==========================================
// Animated Scanning Laser line
// ==========================================
class ScanningLaserLine extends StatefulWidget {
  const ScanningLaserLine({super.key});

  @override
  State<ScanningLaserLine> createState() => _ScanningLaserLineState();
}

class _ScanningLaserLineState extends State<ScanningLaserLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Align(
          alignment: Alignment(0, -1.0 + (_animation.value * 2.0)),
          child: Container(
            height: 3,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEF4444).withOpacity(0.8),
                  blurRadius: 8,
                  spreadRadius: 2,
                )
              ],
            ),
          ),
        );
      },
    );
  }
}

// ==========================================
// Mock QR Code Painter
// ==========================================
class QrCodeMockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF111827)
      ..style = PaintingStyle.fill;

    // Draw the three large corner tracking squares
    _drawTrackingSquare(canvas, Offset.zero, size.width * 0.3, paint);
    _drawTrackingSquare(canvas, Offset(size.width * 0.7, 0), size.width * 0.3, paint);
    _drawTrackingSquare(canvas, Offset(0, size.height * 0.7), size.width * 0.3, paint);

    // Draw mock intermediate small random blocks for QR pattern
    final double block = size.width / 14;
    for (int row = 0; row < 14; row++) {
      for (int col = 0; col < 14; col++) {
        // Skip corner tracking square areas
        if (row < 5 && col < 5) continue;
        if (row < 5 && col >= 9) continue;
        if (row >= 9 && col < 5) continue;

        // Draw pseudo-random noise
        if ((row * 7 + col * 3) % 5 == 0 || (row * 3 + col * 11) % 4 == 0) {
          canvas.drawRect(
            Rect.fromLTWH(col * block, row * block, block, block),
            paint,
          );
        }
      }
    }
  }

  void _drawTrackingSquare(Canvas canvas, Offset offset, double size, Paint paint) {
    final double block = size / 7;
    // Outer square
    canvas.drawRect(Rect.fromLTWH(offset.dx, offset.dy, size, size), paint);
    // Inner white space
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(offset.dx + block, offset.dy + block, size - block * 2, size - block * 2),
      whitePaint,
    );
    // Inner center square
    canvas.drawRect(
      Rect.fromLTWH(offset.dx + block * 2, offset.dy + block * 2, size - block * 4, size - block * 4),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
