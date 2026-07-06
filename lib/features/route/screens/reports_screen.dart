import 'package:flutter/material.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

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
              "Reports",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
            ),
            SizedBox(height: 2),
            Text(
              "5 reports near you",
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // 1. Robbery at Wuse 2, Abuja
            _buildReportCard(
              tag: "ROBBERY",
              tagBg: const Color(0xFFFEE2E2),
              tagColor: const Color(0xFFEF4444),
              title: "Wuse 2, Abuja",
              distance: "0.4 km",
              description: "Two men on a motorcycle snatched a phone near the Wuse 2 market. Multiple witnesses. Police have been notified.",
              time: "45min ago",
              location: "Aminu Kano Crescent",
              statusIcon: Icons.warning_amber_rounded,
              statusIconColor: const Color(0xFFEF4444),
              borderColor: const Color(0xFFFCA5A5),
              roadOverlayBg: const Color(0xFFFFECEC),
              iconDotColor: const Color(0xFFEF4444),
            ),

            // 2. Checkpoint at Lekki Phase 1
            _buildReportCard(
              tag: "CHECKPOINT",
              tagBg: const Color(0xFFFEF3C7),
              tagColor: const Color(0xFFD97706),
              title: "Lekki Phase 1",
              distance: "1.2 km",
              description: "Police checkpoint at Lekki Phase 1 junction. Vehicles are being stopped for routine document checks. Expect delays.",
              time: "1h ago",
              location: "Admiralty Way",
              statusIcon: Icons.local_police_outlined,
              statusIconColor: const Color(0xFFD97706),
              borderColor: const Color(0xFFFDE68A),
              roadOverlayBg: const Color(0xFFFFFBEB),
              iconDotColor: const Color(0xFFD97706),
            ),

            // 3. Traffic at Ajah Roundabout
            _buildReportCard(
              tag: "TRAFFIC",
              tagBg: const Color(0xFFDBEAFE),
              tagColor: const Color(0xFF2563EB),
              title: "Ajah Roundabout",
              distance: "2.8 km",
              description: "Severe traffic congestion from Ajah roundabout to Sangotedo. Road flooded in sections due to recent rain. Use Monastery Road as alternate.",
              time: "1h 30min ago",
              location: "Lekki-Epe Expressway",
              statusIcon: Icons.traffic_outlined,
              statusIconColor: const Color(0xFF2563EB),
              borderColor: const Color(0xFFBFDBFE),
              roadOverlayBg: const Color(0xFFEFF6FF),
              iconDotColor: const Color(0xFF2563EB),
            ),

            // 4. Flooding at Maryland, Lagos
            _buildReportCard(
              tag: "FLOODING",
              tagBg: const Color(0xFFE0F2FE),
              tagColor: const Color(0xFF0284C7),
              title: "Maryland, Lagos",
              distance: "4.5 km",
              description: "Major flooding on Ikorodu Road between Maryland and Ojota. Cars stalling. Avoid unless absolutely necessary.",
              time: "2h ago",
              location: "Ikorodu Road",
              statusIcon: Icons.water_outlined,
              statusIconColor: const Color(0xFF0284C7),
              borderColor: const Color(0xFFBAE6FD),
              roadOverlayBg: const Color(0xFFF0F9FF),
              iconDotColor: const Color(0xFF0284C7),
            ),

            // 5. Robbery at Maitama, Abuja
            _buildReportCard(
              tag: "ROBBERY",
              tagBg: const Color(0xFFFEE2E2),
              tagColor: const Color(0xFFEF4444),
              title: "Maitama, Abuja",
              distance: "6.1 km",
              description: "Attempted carjacking reported near Transcorp Hilton. Perpetrators fled. Area is now clear but remain vigilant.",
              time: "3h ago",
              location: "Constitution Avenue",
              statusIcon: Icons.warning_amber_rounded,
              statusIconColor: const Color(0xFFEF4444),
              borderColor: const Color(0xFFFCA5A5),
              roadOverlayBg: const Color(0xFFFFECEC),
              iconDotColor: const Color(0xFFEF4444),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard({
    required String tag,
    required Color tagBg,
    required Color tagColor,
    required String title,
    required String distance,
    required String description,
    required String time,
    required String location,
    required IconData statusIcon,
    required Color statusIconColor,
    required Color borderColor,
    required Color roadOverlayBg,
    required Color iconDotColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Graphic Road Layout representation
          Container(
            height: 90,
            color: roadOverlayBg,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Horizontal and vertical streets representing map layout
                Positioned(
                  left: 20,
                  right: 20,
                  top: 30,
                  bottom: 30,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.symmetric(
                        horizontal: BorderSide(color: tagColor.withOpacity(0.12), width: 1.5),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 70,
                  right: 70,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.symmetric(
                        vertical: BorderSide(color: tagColor.withOpacity(0.12), width: 1.5),
                      ),
                    ),
                  ),
                ),
                // Center warning dot on the street cross-intersection
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: iconDotColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    "!",
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                // Left category badge
                Positioned(
                  left: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: tagColor.withOpacity(0.2)),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(color: tagColor, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                  ),
                ),
                // Right alert/type icon
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Icon(statusIcon, color: statusIconColor, size: 18),
                  ),
                ),
              ],
            ),
          ),

          // Details padding
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, color: Color(0xFF9CA3AF), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          distance,
                          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4B5563),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, color: Color(0xFF9CA3AF), size: 13),
                    const SizedBox(width: 4),
                    Text(
                      time,
                      style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 6),
                    const Text("·", style: TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        location,
                        style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
