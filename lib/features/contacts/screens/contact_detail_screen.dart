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

  String _formatFullDate(Timestamp? timestamp) {
    if (timestamp == null) return "Unknown Date";
    final dt = timestamp.toDate();
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final day = dt.day;
    final month = months[dt.month - 1];
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return "$day $month $year at $hour:$minute";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final initials = contactName.trim().isNotEmpty
        ? (contactName.trim().split(' ').map((e) => e.isNotEmpty ? e[0].toUpperCase() : '').take(2).join())
        : 'TC';
    final contactFirstName = contactName.trim().split(' ').first;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF9FAFB),
      appBar: SafeTraceAppBar(
        title: contactName,
        showBackButton: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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

              // ── SECTION 1: Nearby Alert Connections Section ──
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('nearby_alert_events')
                    .where('requester_uid', isEqualTo: currentUid)
                    .where('recipient_uid', isEqualTo: contactUid)
                    .snapshots(),
                builder: (context, reqSnap) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('nearby_alert_events')
                        .where('requester_uid', isEqualTo: contactUid)
                        .where('recipient_uid', isEqualTo: currentUid)
                        .snapshots(),
                    builder: (context, recSnap) {
                      final reqDocs = reqSnap.data?.docs ?? [];
                      final recDocs = recSnap.data?.docs ?? [];

                      // Deduplicate by doc ID
                      final Map<String, QueryDocumentSnapshot> docMap = {};
                      for (final doc in [...reqDocs, ...recDocs]) {
                        docMap[doc.id] = doc;
                      }
                      final sharedEvents = docMap.values.toList();

                      // If 0 shared connection events -> hide section entirely!
                      if (sharedEvents.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      // Sort by connected_at descending
                      sharedEvents.sort((a, b) {
                        final dataA = a.data() as Map<String, dynamic>;
                        final dataB = b.data() as Map<String, dynamic>;
                        final tsA = dataA['connected_at'] as Timestamp?;
                        final tsB = dataB['connected_at'] as Timestamp?;
                        if (tsA == null && tsB == null) return 0;
                        if (tsA == null) return 1;
                        if (tsB == null) return -1;
                        return tsB.compareTo(tsA);
                      });

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6C3FC4),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Nearby Alert Connections",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : const Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "(${sharedEvents.length})",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF6C3FC4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: sharedEvents.length,
                            itemBuilder: (context, index) {
                              final eventData = sharedEvents[index].data() as Map<String, dynamic>;
                              return _buildConnectionEventCard(
                                context: context,
                                eventData: eventData,
                                currentUid: currentUid,
                                contactFirstName: contactFirstName,
                                isDark: isDark,
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                      );
                    },
                  );
                },
              ),

              // ── SECTION 2: Recent Logged Locations Section Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Text(
                  "Recent Logged Locations",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
              ),

              // Real-Time Location History List
              StreamBuilder<QuerySnapshot>(
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
                        return const Padding(
                          padding: EdgeInsets.all(30.0),
                          child: Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
                        );
                      }

                      final locDocs = locSnapshot.data?.docs ?? [];
                      final histDocs = histSnapshot.data?.docs ?? [];
                      final Map<String, QueryDocumentSnapshot> docMap = {};
                      for (final doc in [...locDocs, ...histDocs]) {
                        docMap[doc.id] = doc;
                      }
                      final allDocs = docMap.values.toList();

                      if (allDocs.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Center(
                            child: Text(
                              "This contact has not logged any locations yet.",
                              style: TextStyle(
                                color: isDark ? AppColors.textDarkSecondary : const Color(0xFF9CA3AF),
                                fontSize: 14,
                              ),
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
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        itemCount: allDocs.length,
                        itemBuilder: (context, index) {
                          final data = allDocs[index].data() as Map<String, dynamic>;
                          final address = data['address'] ?? data['locationName'] ?? 'Logged Location';
                          final note = data['note'] ?? '';
                          final timestamp = (data['created_at'] ?? data['timestamp'] ?? data['added_at']) as Timestamp?;
                          final rawLat = double.tryParse((data['latitude'] ?? data['lat'] ?? 0.0).toString()) ?? 0.0;
                          final rawLng = double.tryParse((data['longitude'] ?? data['lng'] ?? 0.0).toString()) ?? 0.0;

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
                                child: Icon(
                                  isNearbyAlert ? Icons.people_alt_rounded : Icons.location_on,
                                  color: isNearbyAlert ? const Color(0xFF6C3FC4) : const Color(0xFF4F46E5),
                                  size: 20,
                                ),
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
                                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    isNearbyAlert ? "Connected via Nearby Alert" : (note.isNotEmpty ? note : ''),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontStyle: isNearbyAlert ? FontStyle.italic : FontStyle.normal,
                                      color: isNearbyAlert ? const Color(0xFF6C3FC4) : (isDark ? AppColors.textDarkSecondary : const Color(0xFF4B5563)),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatRelativeTime(timestamp),
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                                  ),
                                ],
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => RouteIntelScreen(
                                      initialDestLatLng: LatLng(rawLat, rawLng),
                                      initialDestAddress: address,
                                      isNearbyAlertHistoricalView: isNearbyAlert,
                                      historicalCardTitle: isNearbyAlert ? "$contactFirstName's location at connection time" : null,
                                      connectedAt: timestamp?.toDate(),
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
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionEventCard({
    required BuildContext context,
    required Map<String, dynamic> eventData,
    required String currentUid,
    required String contactFirstName,
    required bool isDark,
  }) {
    final status = (eventData['status'] ?? 'accepted').toString();
    final isAccepted = status == 'accepted';
    final ts = eventData['connected_at'] as Timestamp?;
    final dateStr = _formatFullDate(ts);

    final reqUid = (eventData['requester_uid'] ?? '').toString();
    final isRequesterCurrent = reqUid == currentUid;

    final reqName = (eventData['requester_first_name'] ?? 'User').toString();
    final recName = (eventData['recipient_first_name'] ?? 'Contact').toString();
    final reqAddr = (eventData['requester_address'] ?? 'Location A').toString();
    final recAddr = (eventData['recipient_address'] ?? 'Location B').toString();

    final reqLat = double.tryParse((eventData['requester_lat'] ?? eventData['lat'] ?? 0.0).toString()) ?? 0.0;
    final reqLng = double.tryParse((eventData['requester_lng'] ?? eventData['lng'] ?? 0.0).toString()) ?? 0.0;
    final recLat = double.tryParse((eventData['recipient_lat'] ?? eventData['lat'] ?? 0.0).toString()) ?? 0.0;
    final recLng = double.tryParse((eventData['recipient_lng'] ?? eventData['lng'] ?? 0.0).toString()) ?? 0.0;

    final currentUserAddr = isRequesterCurrent ? reqAddr : recAddr;
    final currentLat = isRequesterCurrent ? reqLat : recLat;
    final currentLng = isRequesterCurrent ? reqLng : recLng;

    final contactAddr = isRequesterCurrent ? recAddr : reqAddr;
    final contactLat = isRequesterCurrent ? recLat : reqLat;
    final contactLng = isRequesterCurrent ? recLng : reqLng;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D27) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF2E3347) : const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.wifi_tethering_rounded, color: Color(0xFF6C3FC4), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isAccepted ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isAccepted ? "Accepted" : "Declined",
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 12),

          // Row 1: Current User's Location (Independently Tappable)
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RouteIntelScreen(
                    initialDestLatLng: LatLng(currentLat, currentLng),
                    initialDestAddress: currentUserAddr,
                    isNearbyAlertHistoricalView: true,
                    historicalCardTitle: "Your location at connection time",
                    connectedAt: ts?.toDate(),
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 12,
                    backgroundColor: Color(0xFFE8F5E9),
                    child: Text(
                      "YOU",
                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFF2D9B5A)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF374151)),
                        children: [
                          const TextSpan(text: "You were at ", style: TextStyle(fontWeight: FontWeight.w600)),
                          TextSpan(text: currentUserAddr, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Row 2: Contact's Location (Independently Tappable)
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RouteIntelScreen(
                    initialDestLatLng: LatLng(contactLat, contactLng),
                    initialDestAddress: contactAddr,
                    isNearbyAlertHistoricalView: true,
                    historicalCardTitle: "$contactFirstName's location at connection time",
                    connectedAt: ts?.toDate(),
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: const Color(0xFFE3F2FD),
                    child: Text(
                      contactFirstName.isNotEmpty ? contactFirstName[0].toUpperCase() : 'C',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF2C3E6B)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF374151)),
                        children: [
                          TextSpan(text: "$contactFirstName was at ", style: const TextStyle(fontWeight: FontWeight.w600)),
                          TextSpan(text: contactAddr, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Bottom Action: View Both on Map
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF6C3FC4)),
                foregroundColor: const Color(0xFF6C3FC4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RouteIntelScreen(
                      isNearbyAlertHistoricalView: true,
                      isDualMarker: true,
                      requesterLatLng: LatLng(reqLat, reqLng),
                      recipientLatLng: LatLng(recLat, recLng),
                      requesterName: isRequesterCurrent ? "You" : reqName,
                      recipientName: isRequesterCurrent ? recName : "You",
                      requesterAddress: reqAddr,
                      recipientAddress: recAddr,
                      historicalCardTitle: "Nearby Alert Connection Locations",
                      connectedAt: ts?.toDate(),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.map_rounded, size: 16),
              label: const Text(
                "View Both on Map",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
