import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/safetrace_app_bar.dart';
import 'add_contact_request_screen.dart';
import 'contact_detail_screen.dart';

class TrustedCircleScreen extends ConsumerStatefulWidget {
  const TrustedCircleScreen({super.key});

  @override
  ConsumerState<TrustedCircleScreen> createState() => _TrustedCircleScreenState();
}

class _TrustedCircleScreenState extends ConsumerState<TrustedCircleScreen> {
  Future<void> _cancelRequest(String requestId) async {
    try {
      await FirebaseFirestore.instance.collection('trusted_circle_requests').doc(requestId).delete();
    } catch (e) {
      debugPrint("Failed to cancel request: $e");
    }
  }

  Future<void> _acceptRequest(String requestId) async {
    try {
      await FirebaseFirestore.instance.collection('trusted_circle_requests').doc(requestId).update({
        'status': 'accepted',
        'responded_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Failed to accept request: $e");
    }
  }

  Future<void> _declineRequest(String requestId) async {
    try {
      await FirebaseFirestore.instance.collection('trusted_circle_requests').doc(requestId).update({
        'status': 'declined',
        'responded_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Failed to decline request: $e");
    }
  }

  void _showRemoveConfirmationSheet(String requestId, String contactName) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 44, color: Color(0xFFF59E0B)),
            const SizedBox(height: 12),
            const Text(
              "Remove from Trusted Circle",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
            ),
            const SizedBox(height: 10),
            Text(
              "This contact will be removed in 3 days. They will be notified immediately and can see that removal is pending. You can cancel this within 3 days if you change your mind.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  foregroundColor: const Color(0xFFEF4444),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final scheduledFor = Timestamp.fromDate(DateTime.now().add(const Duration(hours: 72)));
                  try {
                    await FirebaseFirestore.instance.collection('trusted_circle_requests').doc(requestId).update({
                      'status': 'pending_deletion',
                      'deletion_initiated_by': FirebaseAuth.instance.currentUser?.uid,
                      'deletion_initiated_at': FieldValue.serverTimestamp(),
                      'deletion_scheduled_for': scheduledFor,
                      'deletion_cancelled': false,
                      'notified_of_deletion': false,
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Removal initiated. Contact will be removed in 3 days.")),
                      );
                    }
                  } catch (e) {
                    debugPrint("Failed to initiate removal: $e");
                  }
                },
                child: const Text("Confirm Removal", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel", style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelRemovalSheet(String requestId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline_rounded, size: 44, color: Color(0xFF10B981)),
            const SizedBox(height: 12),
            const Text(
              "Cancel Removal",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
            ),
            const SizedBox(height: 10),
            const Text(
              "This person will remain in your Trusted Circle.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await FirebaseFirestore.instance.collection('trusted_circle_requests').doc(requestId).update({
                      'status': 'accepted',
                      'deletion_cancelled': true,
                      'deletion_initiated_by': FieldValue.delete(),
                      'deletion_initiated_at': FieldValue.delete(),
                      'deletion_scheduled_for': FieldValue.delete(),
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Removal cancelled. Contact remains in your Trusted Circle.")),
                      );
                    }
                  } catch (e) {
                    debugPrint("Failed to cancel removal: $e");
                  }
                },
                child: const Text("Confirm Cancel", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Dismiss", style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF9FAFB),
        appBar: const SafeTraceAppBar(title: "Trusted Circle", showBackButton: true),
        body: const Center(child: Text("Please sign in to view your trusted circle.")),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : const Color(0xFF111827), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Trusted Circle",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary),
            tooltip: "Add Contact",
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddContactRequestScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('trusted_circle_requests').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final allDocs = snapshot.data?.docs ?? [];

            final activeCircle = <QueryDocumentSnapshot>[];
            final pendingSent = <QueryDocumentSnapshot>[];
            final incomingRequests = <QueryDocumentSnapshot>[];

            for (final doc in allDocs) {
              final data = doc.data() as Map<String, dynamic>;
              final reqUid = data['requester_uid'];
              final recUid = data['recipient_uid'];
              final status = data['status'];

              if (reqUid != currentUser.uid && recUid != currentUser.uid) continue;

              // Both accepted and pending_deletion connections remain in circle until Cloud Function purges them
              if (status == 'accepted' || status == 'pending_deletion') {
                activeCircle.add(doc);
              } else if (status == 'pending') {
                if (reqUid == currentUser.uid) {
                  pendingSent.add(doc);
                } else if (recUid == currentUser.uid) {
                  incomingRequests.add(doc);
                }
              }
            }

            return ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // ── SECTION 1: Active Circle (Includes Pending Deletion Items) ──
                Row(
                  children: [
                    Text(
                      "Active Circle",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "(${activeCircle.length})",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: isDark ? AppColors.textDarkSecondary : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (activeCircle.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A1D27) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? const Color(0xFF2E3347) : const Color(0xFFE5E7EB)),
                    ),
                    child: Center(
                      child: Text(
                        "No active contacts in your circle yet.",
                        style: TextStyle(
                          color: isDark ? AppColors.textDarkSecondary : const Color(0xFF9CA3AF),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                else
                  ...activeCircle.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final status = data['status'] ?? 'accepted';
                    final isRequester = data['requester_uid'] == currentUser.uid;
                    final contactUid = isRequester ? data['recipient_uid'] : data['requester_uid'];
                    final contactFirstName = isRequester ? (data['recipient_first_name'] ?? 'User') : (data['requester_first_name'] ?? 'User');
                    final contactLastName = isRequester ? (data['recipient_last_name'] ?? '') : (data['requester_last_name'] ?? '');
                    final fullName = "$contactFirstName $contactLastName".trim();
                    final phone = isRequester ? (data['recipient_phone'] ?? '') : (data['requester_phone'] ?? '');
                    final relationship = data['relationship'] ?? 'Friend';
                    final welfare = data['welfare_check_enabled'] ?? false;
                    final scheduledTs = data['deletion_scheduled_for'] as Timestamp?;
                    final initiatorUid = (data['deletion_initiated_by'] ?? '').toString();

                    final isPendingDeletion = status == 'pending_deletion';
                    final isInitiator = isPendingDeletion && (initiatorUid == currentUser.uid || (initiatorUid.isEmpty && isRequester));

                    final initials = fullName.isNotEmpty
                        ? fullName.split(' ').map((e) => e.isNotEmpty ? e[0].toUpperCase() : '').take(2).join()
                        : 'TC';

                    if (isPendingDeletion) {
                      if (isInitiator) {
                        // ── Initiator Pending Deletion Card ──
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2D261E) : const Color(0xFFFFFBF0),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? const Color(0xFFD97706) : const Color(0xFFFCD34D)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: const Color(0xFFF59E0B).withOpacity(0.2),
                                    child: Text(
                                      initials,
                                      style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                fullName,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: isDark ? Colors.white : const Color(0xFF111827),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFFF59E0B)),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "$relationship • $phone",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? AppColors.textDarkSecondary : const Color(0xFF6B7280),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Removal pending",
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                                        ),
                                        const SizedBox(height: 2),
                                        _CountdownTimerText(
                                          scheduledAt: scheduledTs?.toDate(),
                                          prefix: "Removal in ",
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF10B981),
                                      side: const BorderSide(color: Color(0xFF10B981)),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () => _showCancelRemovalSheet(doc.id),
                                    child: const Text("Cancel Removal", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      } else {
                        // ── Recipient Pending Deletion Card ──
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2D1E1E) : const Color(0xFFFFF0F0),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? const Color(0xFFDC2626) : const Color(0xFFFCA5A5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: const Color(0xFFEF4444).withOpacity(0.2),
                                    child: Text(
                                      initials,
                                      style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                fullName,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: isDark ? Colors.white : const Color(0xFF111827),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFEF4444)),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "$relationship • $phone",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? AppColors.textDarkSecondary : const Color(0xFF6B7280),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "You are being removed from this circle",
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                                  ),
                                  const SizedBox(height: 2),
                                  _CountdownTimerText(
                                    scheduledAt: scheduledTs?.toDate(),
                                    prefix: "Removal in ",
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF4F46E5),
                                    side: const BorderSide(color: Color(0xFF4F46E5)),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ContactDetailScreen(
                                          contactUid: contactUid,
                                          contactName: fullName,
                                          contactPhone: phone,
                                          relationship: relationship,
                                          welfareCheckEnabled: welfare,
                                          requestId: doc.id,
                                          isReadOnlyPendingDeletion: true,
                                          scheduledAt: scheduledTs?.toDate(),
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text("View Their Profile", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    }

                    // Normal Active Contact Card
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1D27) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? const Color(0xFF2E3347) : const Color(0xFFE5E7EB)),
                      ),
                      child: ListTile(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ContactDetailScreen(
                                contactUid: contactUid,
                                contactName: fullName,
                                contactPhone: phone,
                                relationship: relationship,
                                welfareCheckEnabled: welfare,
                                requestId: doc.id,
                              ),
                            ),
                          );
                        },
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.15),
                          child: Text(
                            initials,
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        title: Text(
                          fullName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            Text(
                              phone,
                              style: TextStyle(
                                color: isDark ? AppColors.textDarkSecondary : const Color(0xFF6B7280),
                                fontSize: 12,
                              ),
                            ),
                            if (welfare) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.health_and_safety, size: 14, color: Color(0xFF16A34A)),
                            ],
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFEF4444),
                                side: const BorderSide(color: Color(0xFFEF4444)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _showRemoveConfirmationSheet(doc.id, fullName),
                              child: const Text(
                                "Remove from Circle",
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: isDark ? AppColors.textDarkSecondary : const Color(0xFF9CA3AF),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                const SizedBox(height: 24),

                // ── SECTION 2: Pending Sent Requests ──
                Text(
                  "Pending Requests (${pendingSent.length})",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 12),

                if (pendingSent.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A1D27) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? const Color(0xFF2E3347) : const Color(0xFFE5E7EB)),
                    ),
                    child: Center(
                      child: Text(
                        "No pending sent requests.",
                        style: TextStyle(
                          color: isDark ? AppColors.textDarkSecondary : const Color(0xFF9CA3AF),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                else
                  ...pendingSent.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final recipientName = "${data['recipient_first_name'] ?? ''} ${data['recipient_last_name'] ?? ''}".trim();
                    final recipientPhone = data['recipient_phone'] ?? '';
                    final relationship = data['relationship'] ?? 'Friend';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1D27) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? const Color(0xFF2E3347) : const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      recipientName.isNotEmpty ? recipientName : recipientPhone,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isDark ? Colors.white : const Color(0xFF111827),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF7ED),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFFDBA74)),
                                      ),
                                      child: const Text(
                                        "Pending",
                                        style: TextStyle(
                                          color: Color(0xFFEA580C),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "$recipientPhone • $relationship",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.textDarkSecondary : const Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFEF4444),
                              side: BorderSide(color: isDark ? const Color(0xFF2E3347) : const Color(0xFFFCA5A5)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _cancelRequest(doc.id),
                            child: const Text(
                              "Cancel Request",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                const SizedBox(height: 24),

                // ── SECTION 3: Incoming Requests ──
                Text(
                  "Incoming Requests (${incomingRequests.length})",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 12),

                if (incomingRequests.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A1D27) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? const Color(0xFF2E3347) : const Color(0xFFE5E7EB)),
                    ),
                    child: Center(
                      child: Text(
                        "No incoming request invitations.",
                        style: TextStyle(
                          color: isDark ? AppColors.textDarkSecondary : const Color(0xFF9CA3AF),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                else
                  ...incomingRequests.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final requesterName = "${data['requester_first_name'] ?? ''} ${data['requester_last_name'] ?? ''}".trim();
                    final relationship = data['relationship'] ?? 'Friend';
                    final welfare = data['welfare_check_enabled'] ?? false;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1D27) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? const Color(0xFF2E3347) : const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.primary.withOpacity(0.15),
                                child: Text(
                                  requesterName.isNotEmpty ? requesterName[0].toUpperCase() : 'T',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      requesterName.isNotEmpty ? requesterName : "SafeTrace User",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isDark ? Colors.white : const Color(0xFF111827),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Wants to add you as $relationship ${welfare ? '(Welfare Check Enabled)' : ''}",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? AppColors.textDarkSecondary : const Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF16A34A),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 0,
                                  ),
                                  onPressed: () => _acceptRequest(doc.id),
                                  child: const Text("Accept", style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFEF4444),
                                    side: const BorderSide(color: Color(0xFFEF4444)),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => _declineRequest(doc.id),
                                  child: const Text("Decline", style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CountdownTimerText extends StatefulWidget {
  final DateTime? scheduledAt;
  final String prefix;
  final TextStyle style;

  const _CountdownTimerText({
    required this.scheduledAt,
    this.prefix = "",
    required this.style,
  });

  @override
  State<_CountdownTimerText> createState() => _CountdownTimerTextState();
}

class _CountdownTimerTextState extends State<_CountdownTimerText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatted() {
    if (widget.scheduledAt == null) return "${widget.prefix}3 days";
    final diff = widget.scheduledAt!.difference(DateTime.now());
    if (diff.isNegative) return "Removal imminent";
    final days = diff.inDays;
    final hours = diff.inHours.remainder(24);
    final minutes = diff.inMinutes.remainder(60);

    if (days >= 1) {
      return "${widget.prefix}$days days $hours hours";
    } else if (hours >= 1) {
      return "${widget.prefix}$hours hours $minutes minutes";
    } else if (minutes >= 1) {
      return "${widget.prefix}$minutes minutes";
    } else {
      return "Removal imminent";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatted(),
      style: widget.style,
    );
  }
}
