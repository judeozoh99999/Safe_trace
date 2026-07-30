import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/safetrace_app_bar.dart';
import '../../route/screens/route_intel_screen.dart';

class ContactDetailScreen extends StatelessWidget {
  final String contactUid;
  final String contactName;
  final String contactPhone;
  final String relationship;
  final bool welfareCheckEnabled;
  final String? requestId;

  const ContactDetailScreen({
    super.key,
    required this.contactUid,
    required this.contactName,
    required this.contactPhone,
    required this.relationship,
    required this.welfareCheckEnabled,
    this.requestId,
  });

  String _formatRelativeTime(Timestamp? timestamp) {
    if (timestamp == null) return "Recently";
    final date = timestamp.toDate();
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return "${diff.inDays}d ago";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initials = contactName.trim().isNotEmpty
        ? (contactName.trim().split(' ').map((e) => e.isNotEmpty ? e[0].toUpperCase() : '').take(2).join())
        : 'TC';

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF9FAFB),
      appBar: SafeTraceAppBar(
        title: contactName,
        showBackButton: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Profile Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1D27) : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF2E3347) : const Color(0xFFE5E7EB),
                  ),
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.primary.withOpacity(0.15),
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    contactName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    contactPhone,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppColors.textDarkSecondary : const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          relationship,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: welfareCheckEnabled
                              ? const Color(0xFFDCFCE7)
                              : (isDark ? const Color(0xFF2E3347) : const Color(0xFFF3F4F6)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              welfareCheckEnabled ? Icons.health_and_safety : Icons.security_outlined,
                              size: 14,
                              color: welfareCheckEnabled ? const Color(0xFF16A34A) : const Color(0xFF6B7280),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              welfareCheckEnabled ? "Welfare Check Active" : "Welfare Check Off",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: welfareCheckEnabled ? const Color(0xFF15803D) : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (requestId != null) ...[
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text("Delete Contact (3-Day Countdown)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text("Delete Trusted Contact?"),
                            content: Text(
                              "Are you sure you want to delete $contactName from your Trusted Circle?\n\n"
                              "Note: Deletion will take 3 days (72 hours) to complete. You can cancel deletion at any time during the countdown.",
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text("Cancel"),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEF4444),
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text("Request Deletion"),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true && requestId != null) {
                          final scheduledFor = Timestamp.fromDate(DateTime.now().add(const Duration(days: 3)));
                          try {
                            await FirebaseFirestore.instance.collection('trusted_circle_requests').doc(requestId).update({
                              'status': 'deletion_pending',
                              'deletion_requested': true,
                              'deletion_requested_by': FirebaseAuth.instance.currentUser?.uid,
                              'deletion_requested_at': FieldValue.serverTimestamp(),
                              'deletion_scheduled_for': scheduledFor,
                            });
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Deletion requested. Contact will be deleted in 3 days.")),
                              );
                              Navigator.pop(context);
                            }
                          } catch (e) {
                            debugPrint("Failed to request deletion: $e");
                          }
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),

            // Location History Section Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: Row(
                children: [
                  Text(
                    "Recent Logged Locations",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),

            // Real-Time Location History List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(contactUid)
                    .collection('locations')
                    .snapshots(),
                builder: (context, locSnapshot) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(contactUid)
                        .collection('location_history')
                        .snapshots(),
                    builder: (context, histSnapshot) {
                      if (locSnapshot.connectionState == ConnectionState.waiting &&
                          histSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final locDocs = locSnapshot.data?.docs ?? [];
                      final histDocs = histSnapshot.data?.docs ?? [];
                      final allDocs = [...locDocs, ...histDocs];

                      if (allDocs.isEmpty) {
                        return Center(
                          child: Text(
                            "This contact has not logged any locations yet.",
                            style: TextStyle(
                              color: isDark ? AppColors.textDarkSecondary : const Color(0xFF9CA3AF),
                              fontSize: 14,
                            ),
                          ),
                        );
                      }

                      // Sort combined docs by timestamp descending
                      allDocs.sort((a, b) {
                        final dataA = a.data() as Map<String, dynamic>;
                        final dataB = b.data() as Map<String, dynamic>;
                        final tsA = (dataA['created_at'] ?? dataA['timestamp'] ?? dataA['added_at']) as Timestamp?;
                        final tsB = (dataB['created_at'] ?? dataB['timestamp'] ?? dataB['added_at']) as Timestamp?;
                        if (tsA == null && tsB == null) return 0;
                        if (tsA == null) return 1;
                        if (tsB == null) return -1;
                        return tsB.compareTo(tsA);
                      });

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: allDocs.length,
                        itemBuilder: (context, index) {
                          final data = allDocs[index].data() as Map<String, dynamic>;
                          final address = data['address'] ?? data['locationName'] ?? 'Logged Location';
                          final note = data['note'] ?? '';
                          final timestamp = (data['created_at'] ?? data['timestamp'] ?? data['added_at']) as Timestamp?;
                          final lat = (data['latitude'] ?? data['lat'] ?? 0.0) as double;
                          final lng = (data['longitude'] ?? data['lng'] ?? 0.0) as double;

                          final isNearbyAlert = data['source'] == 'nearby_alert' || data['tag_label'] == 'Nearby Alert';

                          return Card(
                            elevation: 0,
                            color: isDark ? const Color(0xFF1A1D27) : Colors.white,
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isDark ? const Color(0xFF2E3347) : const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: isNearbyAlert ? const Color(0xFF6C3FC4).withOpacity(0.15) : const Color(0xFFEEF2FF),
                                child: Icon(Icons.location_on, color: isNearbyAlert ? const Color(0xFF6C3FC4) : const Color(0xFF4F46E5), size: 20),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      address,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isDark ? Colors.white : const Color(0xFF111827),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isNearbyAlert) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6C3FC4),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        "Nearby Alert",
                                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (note.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      note,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? AppColors.textDarkSecondary : const Color(0xFF4B5563),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatRelativeTime(timestamp),
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                                  ),
                                ],
                              ),
                              trailing: const Icon(Icons.directions, color: AppColors.primary),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => RouteIntelScreen(
                                      initialDestLatLng: LatLng(lat, lng),
                                      initialDestAddress: address,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),

            // ── SECTION: Nearby Alert Activity ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                "Nearby Alert Activity",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
            ),
            SizedBox(
              height: 140,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('nearby_alert_events')
                    .where('visible_to', arrayContains: FirebaseAuth.instance.currentUser?.uid ?? '')
                    .snapshots(),
                builder: (context, eventSnap) {
                  if (!eventSnap.hasData || eventSnap.data!.docs.isEmpty) {
                    return Center(
                      child: Text(
                        "No Nearby Alert events involving this contact.",
                        style: TextStyle(fontSize: 12, color: isDark ? AppColors.textDarkSecondary : const Color(0xFF9CA3AF)),
                      ),
                    );
                  }

                  final events = eventSnap.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final req = data['requester_uid'];
                    final rec = data['recipient_uid'];
                    return req == contactUid || rec == contactUid;
                  }).toList();

                  if (events.isEmpty) {
                    return Center(
                      child: Text(
                        "No Nearby Alert events involving this contact.",
                        style: TextStyle(fontSize: 12, color: isDark ? AppColors.textDarkSecondary : const Color(0xFF9CA3AF)),
                      ),
                    );
                  }

                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final data = events[index].data() as Map<String, dynamic>;
                      final status = data['status'] ?? 'accepted';
                      final reqName = data['requester_first_name'] ?? 'Requester';
                      final recName = data['recipient_first_name'] ?? 'Recipient';
                      final reqAddr = data['requester_address'] ?? 'Location A';
                      final recAddr = data['recipient_address'] ?? 'Location B';
                      final ts = data['connected_at'] as Timestamp?;
                      final timeStr = _formatRelativeTime(ts);
                      final isAccepted = status == 'accepted';

                      return GestureDetector(
                        onTap: () {
                          if (isAccepted) {
                            final rawLat = double.tryParse((data['requester_lat'] ?? data['lat'] ?? '0.0').toString()) ?? 0.0;
                            final rawLng = double.tryParse((data['requester_lng'] ?? data['lng'] ?? '0.0').toString()) ?? 0.0;
                            final destLatLng = (rawLat != 0.0 && rawLng != 0.0) ? LatLng(rawLat, rawLng) : null;
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RouteIntelScreen(
                                  initialDestLatLng: destLatLng,
                                  initialDestAddress: reqAddr,
                                ),
                              ),
                            );
                          }
                        },
                        child: Container(
                          width: 240,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1A1D27) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF2E3347) : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      "$reqName & $recName",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: isDark ? Colors.white : const Color(0xFF111827),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isAccepted ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isAccepted ? "Accepted" : "Declined",
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                "Connected: $timeStr",
                                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                              ),
                              Text(
                                "Req: $reqAddr",
                                style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
