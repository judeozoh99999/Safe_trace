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

  Future<void> _initiate3DayDeletion(String requestId, String contactName) async {
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

    if (confirmed == true) {
      final scheduledFor = Timestamp.fromDate(DateTime.now().add(const Duration(days: 3)));
      try {
        await FirebaseFirestore.instance.collection('trusted_circle_requests').doc(requestId).update({
          'status': 'deletion_pending',
          'deletion_requested': true,
          'deletion_requested_by': FirebaseAuth.instance.currentUser?.uid,
          'deletion_requested_at': FieldValue.serverTimestamp(),
          'deletion_scheduled_for': scheduledFor,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Deletion requested. Contact will be deleted in 3 days.")),
          );
        }
      } catch (e) {
        debugPrint("Failed to request deletion: $e");
      }
    }
  }

  Future<void> _cancelDeletion(String requestId) async {
    try {
      await FirebaseFirestore.instance.collection('trusted_circle_requests').doc(requestId).update({
        'status': 'accepted',
        'deletion_requested': false,
        'deletion_requested_by': FieldValue.delete(),
        'deletion_requested_at': FieldValue.delete(),
        'deletion_scheduled_for': FieldValue.delete(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Deletion cancelled. Contact restored to Active Circle.")),
        );
      }
    } catch (e) {
      debugPrint("Failed to cancel deletion: $e");
    }
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

            // Filter into lists: Active, Pending Deletion, Pending Sent, Incoming Requests
            final activeCircle = <QueryDocumentSnapshot>[];
            final pendingDeletion = <QueryDocumentSnapshot>[];
            final pendingSent = <QueryDocumentSnapshot>[];
            final incomingRequests = <QueryDocumentSnapshot>[];

            final now = DateTime.now();

            for (final doc in allDocs) {
              final data = doc.data() as Map<String, dynamic>;
              final reqUid = data['requester_uid'];
              final recUid = data['recipient_uid'];
              final status = data['status'];

              if (reqUid != currentUser.uid && recUid != currentUser.uid) continue;

              // Auto purge check for 3-day deletion
              final Timestamp? scheduledTs = data['deletion_scheduled_for'] as Timestamp?;
              if (scheduledTs != null && scheduledTs.toDate().isBefore(now)) {
                FirebaseFirestore.instance.collection('trusted_circle_requests').doc(doc.id).delete();
                continue;
              }

              if (status == 'deletion_pending' || data['deletion_requested'] == true) {
                pendingDeletion.add(doc);
              } else if (status == 'accepted') {
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
                // ── SECTION 1: Active Circle ──
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
                    final isRequester = data['requester_uid'] == currentUser.uid;
                    final contactUid = isRequester ? data['recipient_uid'] : data['requester_uid'];
                    final contactFirstName = isRequester ? (data['recipient_first_name'] ?? 'User') : (data['requester_first_name'] ?? 'User');
                    final contactLastName = isRequester ? (data['recipient_last_name'] ?? '') : (data['requester_last_name'] ?? '');
                    final fullName = "$contactFirstName $contactLastName".trim();
                    final phone = isRequester ? (data['recipient_phone'] ?? '') : (data['requester_phone'] ?? '');
                    final relationship = data['relationship'] ?? 'Friend';
                    final welfare = data['welfare_check_enabled'] ?? false;

                    final initials = fullName.isNotEmpty
                        ? fullName.split(' ').map((e) => e.isNotEmpty ? e[0].toUpperCase() : '').take(2).join()
                        : 'TC';

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
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                              tooltip: "Delete Contact (3-day countdown)",
                              onPressed: () => _initiate3DayDeletion(doc.id, fullName),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: isDark ? AppColors.textDarkSecondary : const Color(0xFF9CA3AF),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                // ── SECTION 2: Pending 3-Day Deletions ──
                if (pendingDeletion.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, color: Color(0xFFEF4444), size: 18),
                      const SizedBox(width: 6),
                      Text(
                        "Pending 3-Day Deletions (${pendingDeletion.length})",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...pendingDeletion.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final isRequester = data['requester_uid'] == currentUser.uid;
                    final contactFirstName = isRequester ? (data['recipient_first_name'] ?? 'User') : (data['requester_first_name'] ?? 'User');
                    final contactLastName = isRequester ? (data['recipient_last_name'] ?? '') : (data['requester_last_name'] ?? '');
                    final fullName = "$contactFirstName $contactLastName".trim();
                    final scheduledTs = data['deletion_scheduled_for'] as Timestamp?;

                    return _DeletionCountdownCard(
                      requestId: doc.id,
                      contactName: fullName,
                      scheduledAt: scheduledTs?.toDate() ?? DateTime.now().add(const Duration(days: 3)),
                      onCancel: () => _cancelDeletion(doc.id),
                      isDark: isDark,
                    );
                  }),
                ],

                const SizedBox(height: 24),

                // ── SECTION 2: Pending Requests ──
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

class _DeletionCountdownCard extends StatefulWidget {
  final String requestId;
  final String contactName;
  final DateTime scheduledAt;
  final VoidCallback onCancel;
  final bool isDark;

  const _DeletionCountdownCard({
    required this.requestId,
    required this.contactName,
    required this.scheduledAt,
    required this.onCancel,
    required this.isDark,
  });

  @override
  State<_DeletionCountdownCard> createState() => _DeletionCountdownCardState();
}

class _DeletionCountdownCardState extends State<_DeletionCountdownCard> {
  Timer? _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
  }

  void _updateRemaining() {
    final now = DateTime.now();
    final diff = widget.scheduledAt.difference(now);
    if (mounted) {
      setState(() {
        _remaining = diff.isNegative ? Duration.zero : diff;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final days = d.inDays;
    final hours = d.inHours.remainder(24).toString().padLeft(2, '0');
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "${days}d ${hours}h ${minutes}m ${seconds}s";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF2A1B1B) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_remove_rounded, color: Color(0xFFEF4444), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.contactName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: widget.isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "Deleting Soon",
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Deletion in: ${_formatDuration(_remaining)}",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFDC2626),
                ),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4F46E5),
                  side: const BorderSide(color: Color(0xFF4F46E5)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: widget.onCancel,
                child: const Text(
                  "Cancel Deletion",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
