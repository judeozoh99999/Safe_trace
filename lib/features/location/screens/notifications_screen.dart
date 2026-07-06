import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> notifications = [
      {
        "type": "danger",
        "title": "Danger Alert",
        "desc": "High threat activity reported near Yaba, Lagos: Protest gathering. Avoid the area and keep clear.",
        "time": "15m ago",
      },
      {
        "type": "safetrace",
        "title": "Welcome to SafeTrace",
        "desc": "Welcome, Jude! Complete your profile and invite 5 trusted contacts to start your emergency safety network.",
        "time": "2h ago",
      },
      {
        "type": "proximity",
        "title": "Proximity Alert",
        "desc": "Chioma Obi is now online within 20 meters proximity. Proximity network status: Connected.",
        "time": "1d ago",
      },
      {
        "type": "checkin",
        "title": "Welfare Check Completed",
        "desc": "Emeka Okafor completed check-in logs at Transcorp Hilton, Abuja. Safety status: Safe.",
        "time": "2d ago",
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF111827), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Notifications",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
        ),
      ),
      body: SafeArea(
        child: notifications.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.notifications_none, size: 64, color: Color(0xFF9CA3AF)),
                    SizedBox(height: 12),
                    Text("No notifications yet", style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16.0),
                itemCount: notifications.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final notif = notifications[index];
                  Color bg;
                  Color iconColor;
                  IconData icon;

                  switch (notif["type"]) {
                    case "danger":
                      bg = const Color(0xFFFEE2E2);
                      iconColor = const Color(0xFFEF4444);
                      icon = Icons.warning_amber_rounded;
                      break;
                    case "proximity":
                      bg = const Color(0xFFEEF2FF);
                      iconColor = const Color(0xFF4F46E5);
                      icon = Icons.wifi_tethering_rounded;
                      break;
                    case "checkin":
                      bg = const Color(0xFFE8F5E9);
                      iconColor = const Color(0xFF2E7D32);
                      icon = Icons.check_circle_outline_rounded;
                      break;
                    default:
                      bg = const Color(0xFFF3F4F6);
                      iconColor = const Color(0xFF4B5563);
                      icon = Icons.chat_bubble_outline_rounded;
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                          padding: const EdgeInsets.all(10),
                          child: Icon(icon, color: iconColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    notif["title"]!,
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF111827)),
                                  ),
                                  Text(
                                    notif["time"]!,
                                    style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                notif["desc"]!,
                                style: const TextStyle(color: Color(0xFF4B5563), fontSize: 13, height: 1.4),
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
    );
  }
}
