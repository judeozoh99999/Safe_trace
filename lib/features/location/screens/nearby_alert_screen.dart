import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'add_connection_screen.dart';
import '../providers/nearby_alert_provider.dart';
import '../../../core/theme/app_colors.dart';

class NearbyAlertScreen extends ConsumerStatefulWidget {
  const NearbyAlertScreen({super.key});

  @override
  ConsumerState<NearbyAlertScreen> createState() => _NearbyAlertScreenState();
}

class _NearbyAlertScreenState extends ConsumerState<NearbyAlertScreen> {
  StreamSubscription<QuerySnapshot>? _incomingRequestsSub;
  final Set<String> _notifiedRequestIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(nearbyAlertProvider.notifier).initializeNearbyAlert();
      _listenForIncomingRequests();
    });
  }

  @override
  void dispose() {
    _incomingRequestsSub?.cancel();
    super.dispose();
  }

  void _listenForIncomingRequests() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _incomingRequestsSub = FirebaseFirestore.instance
        .collection('nearby_connections')
        .where('recipient_uid', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      for (final doc in snap.docs) {
        final data = doc.data();
        final docId = doc.id;
        if (!_notifiedRequestIds.contains(docId)) {
          _notifiedRequestIds.add(docId);
          _showIncomingRequestBanner(
            connectionId: docId,
            requesterName: data['requester_name'] ?? 'Someone',
            connectionType: data['connection_type'] ?? 'Personal',
          );
        }
      }
    });
  }

  void _showIncomingRequestBanner({
    required String connectionId,
    required String requesterName,
    required String connectionType,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 50,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1B4B),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFF4F46E5),
                      child: Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Connection Request",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "$requesterName wants to connect as $connectionType.",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () async {
                        entry.remove();
                        await ref.read(nearbyAlertProvider.notifier).declineConnectionRequest(connectionId);
                      },
                      child: const Text(
                        "Decline",
                        style: TextStyle(color: Color(0xFFFCA5A5), fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        entry.remove();
                        await ref.read(nearbyAlertProvider.notifier).approveConnectionRequest(connectionId);
                      },
                      child: const Text("Approve"),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    final asyncVal = ref.watch(nearbyAlertProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : const Color(0xFF111827), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Nearby Alert",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF111827)),
            ),
            const SizedBox(height: 2),
            Text(
              "20m proximity safety network",
              style: TextStyle(fontSize: 12, color: isDark ? AppColors.textDarkSecondary : const Color(0xFF6B7280), fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      body: asyncVal.when(
        data: (state) => _buildContent(state, isDark),
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
        error: (e, st) => Center(child: Text("Error: $e")),
      ),
    );
  }

  Widget _buildContent(NearbyAlertState state, bool isDark) {
    final bool isSessionOn = state.isSessionActive;
    final List<NearbyConnection> activeConns = _getDisplayConnections(state);

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Banner
                  _buildStatusBanner(isSessionOn, activeConns, isDark),
                  const SizedBox(height: 16),

                  // Stat Boxes
                  _buildStatsRow(state, activeConns, isDark),
                  const SizedBox(height: 24),

                  // Connections Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Connections (${activeConns.length})",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      const Row(
                        children: [
                          _PulsingIndicator(color: Color(0xFF10B981), size: 12),
                          SizedBox(width: 6),
                          Text(
                            "Live GPS tracking",
                            style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
                  const SizedBox(height: 16),

                  // Connection list
                  if (activeConns.isEmpty)
                    _buildEmptyConnectionsPlaceholder(isDark)
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: activeConns.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final card = _buildConnectionCard(activeConns[index], isDark);
                        return card
                            .animate()
                            .fadeIn(delay: (100 * index).ms, duration: 400.ms)
                            .slideY(begin: 0.15, end: 0, delay: (100 * index).ms, duration: 400.ms, curve: Curves.easeOut);
                      },
                    ),
                ],
              ),
            ),
          ),

          // Bottom Add Connection button
          _buildAddConnectionButton(activeConns.length, isDark),
        ],
      ),
    );
  }

  List<NearbyConnection> _getDisplayConnections(NearbyAlertState realState) {
    return realState.connections.where((c) => c.status != 'disconnected').toList();
  }

  Widget _buildStatusBanner(bool isSessionOn, List<NearbyConnection> activeConns, bool isDark) {
    final activeCount = activeConns.where((c) => c.status == 'active' || c.status == 'expiring' || c.status == 'accepted').length;

    if (!isSessionOn || activeCount == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                color: Color(0xFF9CA3AF),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Your proximity network is offline",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    !isSessionOn ? "Nearby Alert is inactive." : "No active connections nearby.",
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
            if (!isSessionOn)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => ref.read(nearbyAlertProvider.notifier).startSession(),
                child: const Text("Activate"),
              ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC8E6C9)),
      ),
      child: Row(
        children: [
          const _PulsingIndicator(color: Color(0xFF2D9B5A), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Active · $activeCount connection${activeCount > 1 ? 's' : ''}",
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1B5E20)),
                ),
                const SizedBox(height: 2),
                const Text(
                  "Your proximity network is live",
                  style: TextStyle(fontSize: 12, color: Color(0xFF2E7D32), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(NearbyAlertState state, List<NearbyConnection> activeConns, bool isDark) {
    int active = 0;
    int expiring = 0;
    int pending = 0;

    for (final c in activeConns) {
      if (c.status == 'active' || c.status == 'accepted') active++;
      if (c.status == 'expiring') expiring++;
      if (c.status == 'pending') pending++;
    }

    return Row(
      children: [
        // Active Box
        _buildStatCard(
          val: active.toString(),
          label: "Active",
          bg: const Color(0xFFE8F5E9),
          textCol: const Color(0xFF2D9B5A),
          topRightWidget: const _PulsingIndicator(color: Color(0xFF2D9B5A), size: 12),
        ),
        const SizedBox(width: 8),

        // Expiring Box
        _buildStatCard(
          val: expiring.toString(),
          label: "Expiring",
          bg: const Color(0xFFFFF8E1),
          textCol: const Color(0xFFF59E0B),
          topRightWidget: const Icon(Icons.timer_outlined, size: 14, color: Color(0xFFF59E0B)),
          hasGlowBorder: expiring > 0,
        ),
        const SizedBox(width: 8),

        // Pending Box
        _buildStatCard(
          val: pending.toString(),
          label: "Pending",
          bg: const Color(0xFFE3F2FD),
          textCol: const Color(0xFF2C3E6B),
          topRightWidget: const _RotatingHourglass(color: Color(0xFF2C3E6B), size: 14),
        ),
        const SizedBox(width: 8),

        // Radius Box
        _buildStatCard(
          val: "${state.radius}m",
          label: "Radius",
          bg: const Color(0xFFF3E5F5),
          textCol: const Color(0xFF7B2D8B),
          topRightWidget: const Icon(Icons.radar_rounded, size: 14, color: Color(0xFF7B2D8B)),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String val,
    required String label,
    required Color bg,
    required Color textCol,
    required Widget topRightWidget,
    bool hasGlowBorder = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: hasGlowBorder
              ? Border.all(color: const Color(0xFFF59E0B), width: 1.5)
              : Border.all(color: textCol.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: hasGlowBorder ? const Color(0x40F59E0B) : Colors.black.withValues(alpha: 0.05),
              blurRadius: hasGlowBorder ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 14),
                Text(
                  val,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textCol),
                ),
                topRightWidget,
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: textCol.withValues(alpha: 0.85), fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyConnectionsPlaceholder(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.dividerDark : const Color(0xFFE5E7EB)),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.radar_rounded, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            "No connections added yet",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 6),
          Text(
            "Tap Add Connection below to connect with people, venues, or responders within 20 metres.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionCard(NearbyConnection conn, bool isDark) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final displayName = conn.requesterUid == currentUserId ? conn.recipientName : conn.requesterName;
    final names = displayName.split(' ');
    final initials = names.map((n) => n.isNotEmpty ? n[0] : '').take(2).join().toUpperCase();

    // Map connection type icon
    IconData typeIcon = Icons.person_outline_rounded;
    if (conn.connectionType == 'Venue') typeIcon = Icons.storefront_rounded;
    if (conn.connectionType == 'Responder') typeIcon = Icons.local_police_rounded;

    final status = (conn.status == 'accepted') ? 'active' : conn.status;

    // Distinct Card Styling per State
    Color cardBg = isDark ? AppColors.cardDark : Colors.white;
    Color leftStripeColor = const Color(0xFF2D9B5A);
    Color statusBadgeBg = const Color(0xFFE8F5E9);
    Color statusBadgeText = const Color(0xFF2D9B5A);
    Color avatarBg = const Color(0xFFE8F5E9);
    Color avatarText = const Color(0xFF1B5E20);
    Color progressColor = const Color(0xFF2D9B5A);
    Widget? statusBadgeIcon;
    bool isOutlinedBadge = false;

    if (status == 'active') {
      cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
      leftStripeColor = const Color(0xFF2D9B5A);
      statusBadgeBg = const Color(0xFF2D9B5A);
      statusBadgeText = Colors.white;
      avatarBg = const Color(0xFFE8F5E9);
      avatarText = const Color(0xFF1B5E20);
      progressColor = const Color(0xFF2D9B5A);
      statusBadgeIcon = const _PulsingIndicator(color: Colors.white, size: 8);
    } else if (status == 'expiring') {
      cardBg = isDark ? const Color(0xFF2D261E) : const Color(0xFFFFFBF0);
      leftStripeColor = const Color(0xFFF59E0B);
      statusBadgeBg = const Color(0xFFF59E0B);
      statusBadgeText = Colors.white;
      avatarBg = const Color(0xFFFFF3CD);
      avatarText = const Color(0xFFB45309);
      progressColor = const Color(0xFFF59E0B);
      statusBadgeIcon = const _ShakingIcon(color: Colors.white, size: 12);
    } else if (status == 'pending') {
      cardBg = isDark ? const Color(0xFF1E2238) : const Color(0xFFF0F4FF);
      leftStripeColor = const Color(0xFF2C3E6B);
      statusBadgeBg = Colors.transparent;
      statusBadgeText = const Color(0xFF2C3E6B);
      isOutlinedBadge = true;
      avatarBg = const Color(0xFFE8EAF6);
      avatarText = const Color(0xFF2C3E6B);
      statusBadgeIcon = const _RotatingHourglass(color: Color(0xFF2C3E6B), size: 12);
    } else if (status == 'expired') {
      cardBg = isDark ? const Color(0xFF2D1E1E) : const Color(0xFFFFF0F0);
      leftStripeColor = const Color(0xFFE63946);
      statusBadgeBg = const Color(0xFFE63946);
      statusBadgeText = Colors.white;
      avatarBg = const Color(0xFFFEE2E2);
      avatarText = const Color(0xFF991B1B);
      progressColor = const Color(0xFFE63946);
    }

    final double distancePercent = status == 'expired' ? 1.0 : (conn.lastDistanceMetres / 20.0).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left status stripe
              Container(
                width: 5,
                color: leftStripeColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: avatarBg,
                            child: Text(
                              initials.isEmpty ? 'U' : initials,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: avatarText,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: isDark ? Colors.white : const Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(typeIcon, size: 12, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      conn.connectionType,
                                      style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                                if (status == 'pending') ...[
                                  const SizedBox(height: 2),
                                  const Text(
                                    "Waiting for approval",
                                    style: TextStyle(fontSize: 12, color: Color(0xFF2C3E6B), fontStyle: FontStyle.italic, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isOutlinedBadge ? Colors.transparent : statusBadgeBg,
                              borderRadius: BorderRadius.circular(12),
                              border: isOutlinedBadge ? Border.all(color: statusBadgeText, width: 1.5) : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (statusBadgeIcon != null) ...[
                                  statusBadgeIcon,
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    color: statusBadgeText,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF), size: 20),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Distance Row (Not shown for pending state)
                      if (status != 'pending') ...[
                        if (status == 'expiring') ...[
                          const Text(
                            "approaching limit",
                            style: TextStyle(fontSize: 12, color: Color(0xFFF59E0B), fontStyle: FontStyle.italic, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                        ],
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOut,
                            tween: Tween<double>(begin: 0, end: distancePercent),
                            builder: (context, value, child) {
                              return LinearProgressIndicator(
                                value: value,
                                backgroundColor: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
                                color: progressColor,
                                minHeight: 6,
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              status == 'expired'
                                  ? "Connection lost (+${(conn.lastDistanceMetres - 20.0).toStringAsFixed(1)}m over limit)"
                                  : "${conn.lastDistanceMetres.toStringAsFixed(1)}m out of 20m limit",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: status == 'expired' ? FontWeight.bold : FontWeight.w500,
                                color: status == 'expired' ? const Color(0xFFE63946) : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        if (status == 'expired') ...[
                          const SizedBox(height: 2),
                          const Text(
                            "Connection lost",
                            style: TextStyle(fontSize: 12, color: Color(0xFFE63946), fontWeight: FontWeight.bold),
                          ),
                        ],
                        const SizedBox(height: 12),
                      ],

                      // Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: _buildCardActionButtons(conn, status),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCardActionButtons(NearbyConnection conn, String status) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isRequester = conn.requesterUid == currentUserId;

    if (status == 'pending') {
      if (isRequester) {
        return [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFEF4444)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => ref.read(nearbyAlertProvider.notifier).cancelConnectionRequest(conn.id),
            child: const Text("Cancel Request", style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
          ),
        ];
      } else {
        return [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.grey),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => ref.read(nearbyAlertProvider.notifier).declineConnectionRequest(conn.id),
            child: const Text("Decline", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => ref.read(nearbyAlertProvider.notifier).approveConnectionRequest(conn.id),
            child: const Text("Approve", style: TextStyle(fontSize: 12)),
          ),
        ];
      }
    }

    if (status == 'expired') {
      return [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.grey),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => ref.read(nearbyAlertProvider.notifier).declineConnectionRequest(conn.id),
          child: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF111827),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => ref.read(nearbyAlertProvider.notifier).renewConnection(conn.id),
          child: const Text("Reconnect", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ];
    }

    // Active / Expiring
    final isExpiring = status == 'expiring';
    return [
      OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.grey),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () => ref.read(nearbyAlertProvider.notifier).disconnectConnection(conn.id),
        child: const Text("Disconnect", style: TextStyle(color: Colors.grey, fontSize: 12)),
      ),
      const SizedBox(width: 8),
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isExpiring ? const Color(0xFFF59E0B) : const Color(0xFFEB444E),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () => ref.read(nearbyAlertProvider.notifier).renewConnection(conn.id),
        child: const Text("Renew", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    ];
  }

  Widget _buildAddConnectionButton(int totalConnections, bool isDark) {
    final bool isLimitReached = totalConnections >= 5;

    Widget btnContent = SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isLimitReached ? const Color(0xFF9CA3AF) : const Color(0xFFEB444E),
          disabledBackgroundColor: const Color(0xFF9CA3AF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        onPressed: isLimitReached
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddConnectionScreen()),
                );
              },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isLimitReached ? Icons.block_rounded : Icons.add, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              isLimitReached ? "Connection limit reached" : "Add Connection",
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );

    if (totalConnections == 0 && !isLimitReached) {
      btnContent = btnContent
          .animate(onPlay: (c) => c.repeat(reverse: false, period: 5.seconds))
          .shimmer(duration: 1.seconds, delay: 4.seconds);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        border: Border(top: BorderSide(color: isDark ? AppColors.dividerDark : const Color(0xFFE5E7EB))),
      ),
      child: btnContent,
    );
  }
}

// ─── Pulsing green dot indicator ─────────────────────────────────────────────

class _PulsingIndicator extends StatefulWidget {
  final Color color;
  final double size;
  const _PulsingIndicator({required this.color, this.size = 20});

  @override
  State<_PulsingIndicator> createState() => _PulsingIndicatorState();
}

class _PulsingIndicatorState extends State<_PulsingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + (_pulseController.value * 1.5);
        final opacity = 1.0 - _pulseController.value;

        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: widget.color, width: 2),
                  ),
                ),
              ),
            ),
            Container(
              width: widget.size * 0.5,
              height: widget.size * 0.5,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Shaking Icon Animation ──────────────────────────────────────────────────

class _ShakingIcon extends StatefulWidget {
  final Color color;
  final double size;
  const _ShakingIcon({required this.color, this.size = 14});

  @override
  State<_ShakingIcon> createState() => _ShakingIconState();
}

class _ShakingIconState extends State<_ShakingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        double angle = 0.0;
        final val = _shakeController.value;
        // Wiggle for 300ms (0 to 0.1 of 3s)
        if (val < 0.1) {
          final subVal = val / 0.1;
          angle = (subVal < 0.5) ? (subVal * 0.175) : ((1.0 - subVal) * 0.175); // approx +-5 degrees
        }
        return Transform.rotate(
          angle: angle,
          child: Icon(Icons.warning_amber_rounded, size: widget.size, color: widget.color),
        );
      },
    );
  }
}

// ─── Rotating Hourglass Animation ──────────────────────────────────────────

class _RotatingHourglass extends StatefulWidget {
  final Color color;
  final double size;
  const _RotatingHourglass({required this.color, this.size = 14});

  @override
  State<_RotatingHourglass> createState() => _RotatingHourglassState();
}

class _RotatingHourglassState extends State<_RotatingHourglass>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotateController;

  @override
  void initState() {
    super.initState();
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rotateController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotateController.value * 3.14159, // 180 degrees continuous
          child: Icon(Icons.hourglass_empty_rounded, size: widget.size, color: widget.color),
        );
      },
    );
  }
}
