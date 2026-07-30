import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../route/screens/route_intel_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = FirebaseAuth.instance.currentUser;

    // Standard static notifications list as fallbacks
    final List<Map<String, dynamic>> staticNotifications = [
      {
        "type": "nearby_alert",
        "title": "Nearby Alert Connection",
        "desc": "Akpovoke and Edesiri connected at 20:18\nAkpovoke was at Transcorp Hilton, Maitama, Abuja.\nEdesiri was at Ikpoba Hill, Benin City, Edo.",
        "time": "17h ago",
        "req_name": "Akpovoke",
        "rec_name": "Edesiri",
        "req_lat": "9.0765",
        "req_lng": "7.4925",
        "req_addr": "Transcorp Hilton, Maitama, Abuja",
        "rec_lat": "6.3350",
        "rec_lng": "5.6037",
        "rec_addr": "Ikpoba Hill, Benin City, Edo",
      },
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
      backgroundColor: isDark ? AppColors.cardDark : const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : const Color(0xFF111827), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Notifications",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF111827)),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: currentUser == null
              ? const Stream.empty()
              : FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser.uid)
                  .collection('notifications')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
          builder: (context, snapshot) {
            List<Map<String, dynamic>> displayNotifications = [];

            if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
              for (final doc in snapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final timestamp = data['timestamp'];
                String timeAgoStr = "Just now";
                if (timestamp != null && timestamp is Timestamp) {
                  final diff = DateTime.now().difference(timestamp.toDate());
                  if (diff.inMinutes < 60) {
                    timeAgoStr = "${diff.inMinutes}m ago";
                  } else if (diff.inHours < 24) {
                    timeAgoStr = "${diff.inHours}h ago";
                  } else {
                    timeAgoStr = "${diff.inDays}d ago";
                  }
                }
                displayNotifications.add({
                  "id": doc.id,
                  "type": data['type'] ?? 'safetrace',
                  "title": data['title'] ?? 'Notification',
                  "desc": data['message'] ?? data['desc'] ?? '',
                  "time": timeAgoStr,
                  "lat": data['lat']?.toString() ?? '',
                  "lng": data['lng']?.toString() ?? '',
                  "nearby_alert_event_id": data['nearby_alert_event_id'],
                });
              }
            }

            // Append static ones at the end
            for (int i = 0; i < staticNotifications.length; i++) {
              final staticNotif = Map<String, dynamic>.from(staticNotifications[i]);
              staticNotif["id"] = "static_$i";
              displayNotifications.add(staticNotif);
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16.0),
              itemCount: displayNotifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final notif = displayNotifications[index];
                final notifId = notif["id"]?.toString() ?? index.toString();
                Color bg;
                Color iconColor;
                IconData icon;

                switch (notif["type"]) {
                  case "danger":
                  case "distress":
                    bg = const Color(0xFFFEE2E2);
                    iconColor = const Color(0xFFEF4444);
                    icon = Icons.warning_amber_rounded;
                    break;
                  case "nearby_alert":
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

                final card = GestureDetector(
                  onTap: () async {
                    if (notif["type"] == "nearby_alert") {
                      final reqLat = double.tryParse(notif["req_lat"]?.toString() ?? "") ?? 9.0765;
                      final reqLng = double.tryParse(notif["req_lng"]?.toString() ?? "") ?? 7.4925;
                      final recLat = double.tryParse(notif["rec_lat"]?.toString() ?? "") ?? 6.3350;
                      final recLng = double.tryParse(notif["rec_lng"]?.toString() ?? "") ?? 5.6037;

                      final eventId = notif["nearby_alert_event_id"];
                      if (eventId != null && eventId.toString().isNotEmpty) {
                        try {
                          final doc = await FirebaseFirestore.instance.collection('nearby_alert_events').doc(eventId.toString()).get();
                          if (doc.exists) {
                            final data = doc.data() as Map<String, dynamic>;
                            final reqName = (data['requester_first_name'] ?? 'User A').toString();
                            final recName = (data['recipient_first_name'] ?? 'User B').toString();
                            final rLat = (data['requester_lat'] as num?)?.toDouble() ?? reqLat;
                            final rLng = (data['requester_lng'] as num?)?.toDouble() ?? reqLng;
                            final cLat = (data['recipient_lat'] as num?)?.toDouble() ?? recLat;
                            final cLng = (data['recipient_lng'] as num?)?.toDouble() ?? recLng;
                            final rAddr = (data['requester_address'] ?? '$rLat, $rLng').toString();
                            final cAddr = (data['recipient_address'] ?? '$cLat, $cLng').toString();
                            final connTs = data['connected_at'] as Timestamp?;

                            if (context.mounted) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => RouteIntelScreen(
                                    nearbyAlertEvent: true,
                                    requesterName: reqName,
                                    recipientName: recName,
                                    requesterLatLng: LatLng(rLat, rLng),
                                    recipientLatLng: LatLng(cLat, cLng),
                                    requesterAddress: rAddr,
                                    recipientAddress: cAddr,
                                    connectedAt: connTs?.toDate(),
                                  ),
                                ),
                              );
                            }
                            return;
                          }
                        } catch (e) {
                          debugPrint("Error fetching nearby_alert_events document: $e");
                        }
                      }

                      if (context.mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RouteIntelScreen(
                              nearbyAlertEvent: true,
                              requesterName: notif["req_name"]?.toString() ?? "Akpovoke",
                              recipientName: notif["rec_name"]?.toString() ?? "Edesiri",
                              requesterLatLng: LatLng(reqLat, reqLng),
                              recipientLatLng: LatLng(recLat, recLng),
                              requesterAddress: notif["req_addr"]?.toString() ?? "Transcorp Hilton, Maitama, Abuja",
                              recipientAddress: notif["rec_addr"]?.toString() ?? "Ikpoba Hill, Benin City, Edo",
                              connectedAt: DateTime.now(),
                            ),
                          ),
                        );
                      }
                      return;
                    }

                    final lat = double.tryParse(notif["lat"]?.toString() ?? "");
                    final lng = double.tryParse(notif["lng"]?.toString() ?? "");
                    final address = notif["desc"]?.toString() ?? notif["title"]?.toString() ?? "Location";

                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RouteIntelScreen(
                          initialDestLatLng: (lat != null && lng != null) ? LatLng(lat, lng) : null,
                          initialDestAddress: address,
                        ),
                      ),
                    );
                  },
                  child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: notif["type"] == "distress"
                          ? const Color(0xFFEF4444)
                          : (isDark ? AppColors.dividerDark : const Color(0xFFE5E7EB)),
                      width: notif["type"] == "distress" ? 1.5 : 1.0,
                    ),
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
                                Expanded(
                                  child: Text(
                                    notif["title"]!,
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF111827)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  notif["time"]!,
                                  style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              notif["desc"]!,
                              style: TextStyle(color: isDark ? AppColors.textDarkSecondary : const Color(0xFF4B5563), fontSize: 13, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );

                return Dismissible(
                  key: Key(notifId),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    if (currentUser != null && !notifId.startsWith("static_")) {
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(currentUser.uid)
                          .collection('notifications')
                          .doc(notifId)
                          .delete();
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Notification deleted")),
                    );
                  },
                  child: PulsingDistressBorder(
                    isDistress: notif["type"] == "distress",
                    child: card,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class PulsingDistressBorder extends StatefulWidget {
  final Widget child;
  final bool isDistress;

  const PulsingDistressBorder({
    super.key,
    required this.child,
    required this.isDistress,
  });

  @override
  State<PulsingDistressBorder> createState() => _PulsingDistressBorderState();
}

class _PulsingDistressBorderState extends State<PulsingDistressBorder> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isDistress) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isDistress) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final glowColor = const Color(0xFFEF4444).withOpacity(0.4 * (1 - _controller.value));
        final thickness = 0.5 + (_controller.value * 2.5);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: glowColor,
                blurRadius: 8 * _controller.value,
                spreadRadius: thickness,
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}
