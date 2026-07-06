import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'log_location_screen.dart';
import '../../home_shell.dart';

class RouteIntelScreen extends ConsumerStatefulWidget {
  const RouteIntelScreen({super.key});

  @override
  ConsumerState<RouteIntelScreen> createState() => _RouteIntelScreenState();
}

class _RouteIntelScreenState extends ConsumerState<RouteIntelScreen> {
  int _activeTab = 0; // 0 = Route, 1 = Live Map, 2 = History
  String _activeHistoryFilter = "All"; // All, Today, Yesterday
  bool _showUserNotes = true; // Toggle user notes display when shield marker is clicked

  final TextEditingController _startController = TextEditingController(text: "Victoria Island, Lagos");
  final TextEditingController _destController = TextEditingController(text: "Delta");

  @override
  void dispose() {
    _startController.dispose();
    _destController.dispose();
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

  Widget _buildMapImage() {
    const String path = r"C:\Users\USER\.gemini\antigravity\brain\97394126-4d75-47a7-aef4-1265e239f7ae\media__1783245489550.png";
    try {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
        );
      }
    } catch (_) {}
    // Fallback: GridPaper mock background
    return Stack(
      children: [
        Positioned.fill(
          child: GridPaper(
            color: Colors.blue.withOpacity(0.02),
            divisions: 2,
            subdivisions: 1,
            child: Container(),
          ),
        ),
        Positioned(
          left: 80,
          right: 80,
          top: 0,
          bottom: 0,
          child: Container(width: 24, color: Colors.white),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 180,
          child: Container(height: 24, color: Colors.white),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF111827), size: 20),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: const Text(
          "Route Intelligence",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEEF2FF),
                foregroundColor: const Color(0xFF4F46E5),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: () {
                ref.read(homeShellIndexProvider.notifier).state = 2;
              },
              child: Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, size: 16),
                  SizedBox(width: 6),
                  Text("Reports", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTabButton(0, Icons.alt_route_rounded, "Route"),
                _buildTabButton(1, Icons.map_outlined, "Live Map"),
                _buildTabButton(2, Icons.history_rounded, "History"),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildTabButton(int index, IconData icon, String label) {
    final isSelected = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeTab = index;
          });
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? const Color(0xFFEF4444) : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? const Color(0xFFEF4444) : const Color(0xFF6B7280),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  color: isSelected ? const Color(0xFFEF4444) : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_activeTab) {
      case 0:
        return _buildRouteTab();
      case 1:
        return _buildLiveMapTab();
      case 2:
        return _buildHistoryTab();
      default:
        return const SizedBox();
    }
  }

  // --- TAB 1: ROUTE TAB ---
  Widget _buildRouteTab() {
    return Column(
      children: [
        // Map Container representing Birmingham streets
        Expanded(
          flex: 4,
          child: Container(
            color: const Color(0xFFEFF3F8),
            child: Stack(
              children: [
                Positioned.fill(
                  child: _buildMapImage(),
                ),

                // Map Markers
                // 1. Red location Pin Marker (Victoria Island)
                Positioned(
                  left: 140,
                  top: 100,
                  child: _buildMarkerImage(
                    "D:\\app files\\Current Location Marker.png",
                    Icons.location_on,
                    const Color(0xFFEF4444),
                    size: 36,
                  ),
                ),

                // 2. Clickable Shield Icon Marker (situated at Delta)
                Positioned(
                  left: 160,
                  top: 160,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _showUserNotes = !_showUserNotes;
                      });
                    },
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
                      ),
                      padding: const EdgeInsets.all(4),
                      child: _buildMarkerImage(
                        "D:\\app files\\Near Pin Marker.png",
                        Icons.shield,
                        const Color(0xFFEF4444),
                        size: 32,
                      ),
                    ),
                  ),
                ),

                // Destination Search fields overlay
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        // Start point field
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: const [
                              Icon(Icons.circle, size: 8, color: Color(0xFF10B981)),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "Start: Victoria Island, Lagos",
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Destination field
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF9CA3AF)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: _destController,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                                        ),
                                      ),
                                    ),
                                    const Icon(Icons.close_rounded, size: 16, color: Color(0xFF9CA3AF)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Search Button
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.search, color: Colors.white, size: 18),
                                onPressed: () {},
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Clear button overlay
                Positioned(
                  left: 12,
                  top: 136,
                  child: SizedBox(
                    height: 32,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onPressed: () {},
                      child: Row(
                        children: const [
                          Icon(Icons.close, size: 14, color: Color(0xFF111827)),
                          SizedBox(width: 4),
                          Text("Clear", style: TextStyle(color: Color(0xFF111827), fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),

                // Zoom controls floating buttons on map
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Column(
                    children: [
                      // Zoom In
                      _buildZoomButton(Icons.add, () {}),
                      const SizedBox(height: 6),
                      // Zoom Out
                      _buildZoomButton(Icons.remove, () {}),
                      const SizedBox(height: 12),
                      // Spotlight center zoom controls
                      GestureDetector(
                        onTap: () {},
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                          ),
                          padding: const EdgeInsets.all(8),
                          child: _buildMarkerImage(
                            "D:\\app files\\Spotlight Marker.png",
                            Icons.my_location_rounded,
                            const Color(0xFF6B7280),
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Route details & notes listing
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [


                // Destination title & estimated time
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "Victoria Island -> Delta",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Lekki-Epe Expressway · 142 km",
                          style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          "1h 24m",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(4)),
                          child: const Text(
                            "Safe Route",
                            style: TextStyle(color: Color(0xFF2E7D32), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Statistics row
                Row(
                  children: [
                    _buildRouteStat("142 km", "Distance"),
                    const SizedBox(width: 8),
                    _buildRouteStat("1h 24m", "With Traffic"),
                    const SizedBox(width: 8),
                    _buildRouteStat("₦3,200", "Fuel Est."),
                  ],
                ),
                const SizedBox(height: 20),

                // Toggled USER NOTES container (opens when clicking the shield icon marker)
                if (_showUserNotes) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2030), // Dark background matching screenshot
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Row(
                              children: [
                                Icon(Icons.shield_outlined, color: Colors.white, size: 16),
                                SizedBox(width: 8),
                                Text(
                                  "USER NOTES",
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                ),
                              ],
                            ),
                            Icon(Icons.copy_rounded, color: Colors.white70, size: 16),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Route to Delta looks clear. No community safety incidents flagged in the past 4 hours. Safe to proceed.",
                          style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Community Safety Notes Title
                const Text(
                  "Community Safety Notes",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
                ),
                const SizedBox(height: 12),

                // Community notes list
                _buildCommunitySafetyNote(
                  title: "Lekki Phase 1 Gate",
                  tag: "CHECKPOINT",
                  tagColor: const Color(0xFFD97706),
                  tagBg: const Color(0xFFFEF3C7),
                  desc: "Police checkpoint — routine document checks. Minor delays.",
                  time: "45m ago",
                  icon: Icons.local_police_outlined,
                ),
                _buildCommunitySafetyNote(
                  title: "Ajah Roundabout",
                  tag: "TRAFFIC",
                  tagColor: const Color(0xFF2563EB),
                  tagBg: const Color(0xFFDBEAFE),
                  desc: "Severe traffic congestion from Ajah roundabout to Sangotedo. Consider alternatives.",
                  time: "1h ago",
                  icon: Icons.traffic_outlined,
                ),
                _buildCommunitySafetyNote(
                  title: "Wuse 2, Aminu Kano",
                  tag: "ROBBERY",
                  tagColor: const Color(0xFFEF4444),
                  tagBg: const Color(0xFFFEE2E2),
                  desc: "Armed robbery reported. Perpetrators fled. Area now clear.",
                  time: "2h ago",
                  icon: Icons.warning_amber_rounded,
                ),
                const SizedBox(height: 16),

                // Start Navigation Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF131522),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () {},
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.navigation_outlined, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          "Start Navigation",
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildZoomButton(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: IconButton(
        icon: Icon(icon, color: const Color(0xFF6B7280), size: 20),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildRouteStat(String val, String label) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Text(val, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunitySafetyNote({
    required String title,
    required String tag,
    required Color tagColor,
    required Color tagBg,
    required String desc,
    required String time,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: tagColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(4)),
                      child: Text(tag, style: TextStyle(color: tagColor, fontSize: 8, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563), height: 1.35)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(time, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10, fontWeight: FontWeight.w500)),
                    const Icon(Icons.close, color: Color(0xFF9CA3AF), size: 14),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: LIVE MAP TAB ---
  Widget _buildLiveMapTab() {
    return Column(
      children: [
        // Live Map canvas
        Expanded(
          child: Container(
            color: const Color(0xFFEFF3F8),
            child: Stack(
              children: [
                Positioned.fill(
                  child: _buildMapImage(),
                ),

                // Location marker (Victoria Island, Lagos)
                Center(
                  child: _buildMarkerImage(
                    "D:\\app files\\Current Location Marker.png",
                    Icons.location_on,
                    const Color(0xFFEF4444),
                    size: 44,
                  ),
                ),

                // Zoom controls overlay
                Positioned(
                  right: 12,
                  bottom: 110,
                  child: Column(
                    children: [
                      _buildZoomButton(Icons.add, () {}),
                      const SizedBox(height: 6),
                      _buildZoomButton(Icons.remove, () {}),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () {},
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                          ),
                          padding: const EdgeInsets.all(8),
                          child: _buildMarkerImage(
                            "D:\\app files\\Spotlight Marker.png",
                            Icons.my_location_rounded,
                            const Color(0xFF6B7280),
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Floating location card at bottom
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Location preview thumbnail/avatar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 44,
                                height: 44,
                                color: const Color(0xFFE5E7EB),
                                child: const Icon(Icons.meeting_room_outlined, color: Color(0xFF9CA3AF)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    "Victoria Island, Lagos",
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    "12 Adeola Odeku St, V/I",
                                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            // Logged status with dot
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text("Logged 2:41 PM", style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                                const SizedBox(height: 2),
                                Row(
                                  children: const [
                                    Icon(Icons.circle, size: 6, color: Color(0xFF10B981)),
                                    SizedBox(width: 4),
                                    Text("Live", style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Action Buttons Row
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF131522),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                  onPressed: () {},
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.share_outlined, color: Colors.white, size: 16),
                                        SizedBox(width: 6),
                                        Text("Share Location", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEF4444),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const LogLocationScreen()),
                                    );
                                  },
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.location_on, color: Colors.white, size: 16),
                                        SizedBox(width: 6),
                                        Text("Log This Location", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- TAB 3: HISTORY TAB ---
  Widget _buildHistoryTab() {
    // Mock location history items list
    final List<Map<String, String>> historyItems = [
      {
        "title": "Victoria Island",
        "sub": "12 Adeola Odeku St",
        "note": "Arrived at client meeting",
        "time": "2:41 PM",
        "day": "Today",
        "expiry": "7d",
      },
      {
        "title": "Lekki Phase 1",
        "sub": "Admiralty Way",
        "note": "Heading to work, traffic on Lekki-Epe",
        "time": "11:20 AM",
        "day": "Today",
        "expiry": "7d",
      },
      {
        "title": "Oniru Estate, V/I",
        "sub": "Chief Yesufu Abiodun Way",
        "note": "Left home, all clear.",
        "time": "8:05 AM",
        "day": "Today",
        "expiry": "7d",
      },
      {
        "title": "Wuse 2, Abuja",
        "sub": "Aminu Kano Crescent",
        "note": "Arrived at client pitch. Area clean",
        "time": "6:30 PM",
        "day": "Yesterday",
        "expiry": "6d",
      },
      {
        "title": "Maitama, Abuja",
        "sub": "Adetokunbo Ademola Cresc.",
        "note": "Meeting ended. Departing",
        "time": "3:15 PM",
        "day": "Yesterday",
        "expiry": "6d",
      },
      {
        "title": "Ikeja, Lagos",
        "sub": "Allen Avenue",
        "note": "Airport drop-off. All good.",
        "time": "9:00 AM",
        "day": "Mon, Jun 30",
        "expiry": "4d",
      },
    ];

    // Filter list
    final filtered = historyItems.where((item) {
      if (_activeHistoryFilter == "Today") return item["day"] == "Today";
      if (_activeHistoryFilter == "Yesterday") return item["day"] == "Yesterday";
      return true;
    }).toList();

    return Column(
      children: [
        // Filter pills bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _buildHistoryFilterPill("All"),
              const SizedBox(width: 8),
              _buildHistoryFilterPill("Today"),
              const SizedBox(width: 8),
              _buildHistoryFilterPill("Yesterday"),
              const Spacer(),
              Text(
                "${filtered.length} logs",
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),

        // Grid Table Headers
        Container(
          color: const Color(0xFF1F2937),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: const [
              Expanded(
                flex: 4,
                child: Text("LOCATION", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ),
              Expanded(
                flex: 3,
                child: Text("TIME", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ),
              Expanded(
                flex: 2,
                child: Text("EXPIRES", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ),
            ],
          ),
        ),

        // History logs
        Expanded(
          child: ListView.separated(
            itemCount: filtered.length,
            separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE5E7EB)),
            itemBuilder: (context, index) {
              final log = filtered[index];
              return Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Location info
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            log["title"]!,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            log["sub"]!,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            log["note"]!,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Time elapsed
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            log["time"]!,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            log["day"]!,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Expiration info
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              log["expiry"]!,
                              style: const TextStyle(color: Color(0xFF4F46E5), fontSize: 10, fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: const [
                              Icon(Icons.check_circle_outline_rounded, size: 12, color: Color(0xFF10B981)),
                              SizedBox(width: 4),
                              Text("Safe", style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Bottom logs warning banner
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDBEAFE)),
          ),
          child: Row(
            children: const [
              Icon(Icons.access_time_rounded, color: Color(0xFF2563EB), size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Location logs are automatically deleted after 7 days.",
                  style: TextStyle(color: Color(0xFF1E3A8A), fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryFilterPill(String filter) {
    final isSelected = _activeHistoryFilter == filter;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeHistoryFilter = filter;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF131522) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF131522) : const Color(0xFFE5E7EB),
            width: 1.2,
          ),
        ),
        child: Text(
          filter,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}
