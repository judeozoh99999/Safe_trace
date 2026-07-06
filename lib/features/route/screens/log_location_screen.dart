import 'dart:io';
import 'package:flutter/material.dart';

class LogLocationScreen extends StatefulWidget {
  const LogLocationScreen({super.key});

  @override
  State<LogLocationScreen> createState() => _LogLocationScreenState();
}

class _LogLocationScreenState extends State<LogLocationScreen> {
  final TextEditingController _noteController = TextEditingController();
  bool _isSafe = true;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Widget _buildMarkerImage(String path, IconData fallbackIcon, Color fallbackColor, {double size = 32}) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(file, width: size, height: size);
      }
    } catch (_) {}
    return Icon(fallbackIcon, color: fallbackColor, size: size);
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
              "Log This Location",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
            ),
            SizedBox(height: 2),
            Text(
              "Victoria Island, Lagos · 2:41 PM",
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mock Map image representing Birmingham/Norwood
                    Container(
                      height: 220,
                      width: double.infinity,
                      color: const Color(0xFFE2E6EF),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Birmingham mockup style grid representation
                          Positioned.fill(
                            child: GridPaper(
                              color: Colors.blue.withOpacity(0.03),
                              divisions: 2,
                              subdivisions: 1,
                              child: Container(color: const Color(0xFFEFF3F8)),
                            ),
                          ),
                          // Simple mock streets
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 80,
                            child: Container(height: 24, color: Colors.white),
                          ),
                          Positioned(
                            top: 0,
                            bottom: 0,
                            left: 120,
                            child: Container(width: 24, color: Colors.white),
                          ),
                          // Location Pin Marker
                          _buildMarkerImage(
                            "D:\\app files\\Current Location Marker.png",
                            Icons.location_on,
                            const Color(0xFFEF4444),
                            size: 40,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Safety Note Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "SAFETY NOTE",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF6B7280),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Text input area
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                TextField(
                                  controller: _noteController,
                                  maxLines: 5,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF111827),
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: "Add a note about this location... What are you doing? How does it feel? Any concerns?",
                                    hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                                    border: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: const [
                                    Text(
                                      "0/280",
                                      style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                                    ),
                                    Row(
                                      children: [
                                        Icon(Icons.pin_drop_outlined, size: 14, color: Color(0xFF9CA3AF)),
                                        SizedBox(width: 4),
                                        Text(
                                          "V/I, Lagos",
                                          style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Safe/Unsafe toggle
                          Row(
                            children: [
                              // Safe button toggle
                              Expanded(
                                child: SizedBox(
                                  height: 46,
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: _isSafe ? const Color(0xFF4F46E5) : const Color(0xFFE5E7EB),
                                        width: 1.5,
                                      ),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      backgroundColor: _isSafe ? const Color(0xFFEEF2FF) : Colors.white,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isSafe = true;
                                      });
                                    },
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline_rounded,
                                          color: _isSafe ? const Color(0xFF4F46E5) : const Color(0xFF6B7280),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "Safe",
                                          style: TextStyle(
                                            color: _isSafe ? const Color(0xFF4F46E5) : const Color(0xFF6B7280),
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
                              // Unsafe button toggle
                              Expanded(
                                child: SizedBox(
                                  height: 46,
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: !_isSafe ? const Color(0xFFEF4444) : const Color(0xFFE5E7EB),
                                        width: 1.5,
                                      ),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      backgroundColor: !_isSafe ? const Color(0xFFFEE2E2) : Colors.white,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isSafe = false;
                                      });
                                    },
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          color: !_isSafe ? const Color(0xFFEF4444) : const Color(0xFF6B7280),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "Unsafe",
                                          style: TextStyle(
                                            color: !_isSafe ? const Color(0xFFEF4444) : const Color(0xFF6B7280),
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Fixed Bottom action button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE5E7EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Location logged successfully")),
                    );
                    Navigator.of(context).pop();
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.send_rounded, color: Color(0xFF9CA3AF), size: 18),
                      SizedBox(width: 8),
                      Text(
                        "Log This Location",
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
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
    );
  }
}
