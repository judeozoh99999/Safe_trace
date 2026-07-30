import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
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
              color: const Color(0xFF1E1B4B), // Indigo Dark
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
                      const Text(
                        "Live GPS tracking",
                        style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

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
                        return _buildConnectionCard(activeConns[index], isDark);
                      },
                    ),
                ],
              ),
            ),
          ),

          // Bottom Add Connection button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              border: Border(top: BorderSide(color: isDark ? AppColors.dividerDark : const Color(0xFFE5E7EB))),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.primary : const Color(0xFF131522),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AddConnectionScreen()),
                  );
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Add Connection",
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<NearbyConnection> _getDisplayConnections(NearbyAlertState realState) {
    return realState.connections.where((c) => c.status != 'disconnected').toList();
  }

  Widget _buildStatusBanner(bool isSessionOn, List<NearbyConnection> activeConns, bool isDark) {
    if (!isSessionOn) {
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
            const Icon(Icons.visibility_off_rounded, color: Colors.grey),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("You are hidden", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  SizedBox(height: 2),
                  Text("Nearby Alert is inactive.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
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

    final activeCount = activeConns.where((c) => c.status == 'active' || c.status == 'expiring').length;
    if (activeCount > 0) {
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
            _PulsingIndicator(color: const Color(0xFF10B981)),
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: const Row(
        children: [
          Icon(Icons.radar_rounded, color: Color(0xFF2563EB)),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You are visible",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1E40AF)),
                ),
                SizedBox(height: 2),
                Text(
                  "No active connections yet.",
                  style: TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w500),
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
      if (c.status == 'active') active++;
      if (c.status == 'expiring') expiring++;
      if (c.status == 'pending') pending++;
    }

    return Row(
      children: [
        _buildStatBox(active.toString(), "Active", const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
        const SizedBox(width: 8),
        _buildStatBox(expiring.toString(), "Expiring", const Color(0xFFFFF3E0), const Color(0xFFE65100)),
        const SizedBox(width: 8),
        _buildStatBox(pending.toString(), "Pending", const Color(0xFFFFFDE7), const Color(0xFFF57F17)),
        const SizedBox(width: 8),
        _buildStatBox("${state.radius}m", "Radius", const Color(0xFFF3E5F5), const Color(0xFF7B1FA2)),
      ],
    );
  }

  Widget _buildStatBox(String val, String label, Color bg, Color textCol) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: textCol.withOpacity(0.12)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(
              val,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textCol),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: textCol.withOpacity(0.8), fontWeight: FontWeight.bold),
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
            "Taps Add Connection below to connect with people, venues, or responders within 20 metres.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionCard(NearbyConnection conn, bool isDark) {
    final names = conn.requesterUid == FirebaseAuth.instance.currentUser?.uid ? conn.recipientName.split(' ') : conn.requesterName.split(' ');
    final displayName = conn.requesterUid == FirebaseAuth.instance.currentUser?.uid ? conn.recipientName : conn.requesterName;
    final initials = names.map((n) => n.isNotEmpty ? n[0] : '').take(2).join().toUpperCase();

    // Map connection type icon
    IconData typeIcon = Icons.person_outline_rounded;
    if (conn.connectionType == 'Venue') typeIcon = Icons.storefront_rounded;
    if (conn.connectionType == 'Responder') typeIcon = Icons.local_police_rounded;

    // Status Badge colors
    Color statusColor = Colors.grey;
    Color statusBg = Colors.grey.withValues(alpha: 0.1);
    if (conn.status == 'active') {
      statusColor = const Color(0xFF10B981);
      statusBg = const Color(0xFFE8F5E9);
    } else if (conn.status == 'expiring') {
      statusColor = const Color(0xFFF59E0B);
      statusBg = const Color(0xFFFFF3E0);
    } else if (conn.status == 'expired') {
      statusColor = const Color(0xFFEF4444);
      statusBg = const Color(0xFFFEE2E2);
    } else if (conn.status == 'pending') {
      statusColor = const Color(0xFFF59E0B);
      statusBg = const Color(0xFFFFFEF0);
    }

    // Distance bar colors
    Color progressColor = const Color(0xFF10B981);
    if (conn.status == 'expiring') progressColor = const Color(0xFFF59E0B);
    if (conn.status == 'expired') progressColor = const Color(0xFFEF4444);

    final double distancePercent = (conn.lastDistanceMetres / 20.0).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.dividerDark : const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: isDark ? const Color(0xFF374151) : const Color(0xFFEEF2FF),
                child: Text(
                  initials.isEmpty ? 'U' : initials,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF4F46E5),
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
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
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
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  conn.status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                  ),
                ),
              )
            ],
          ),

          const SizedBox(height: 16),

          // Distance Row (Not shown for pending state)
          if (conn.status != 'pending') ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: distancePercent,
                backgroundColor: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
                color: progressColor,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  conn.status == 'expired'
                      ? "Connection lost (+${(conn.lastDistanceMetres - 20.0).toStringAsFixed(1)}m over limit)"
                      : "${conn.lastDistanceMetres.toStringAsFixed(1)}m out of 20m limit",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: conn.status == 'expired' ? const Color(0xFFEF4444) : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ] else ...[
            const Row(
              children: [
                Icon(Icons.hourglass_empty, size: 14, color: Colors.grey),
                SizedBox(width: 6),
                Text(
                  "Waiting for approval...",
                  style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: _buildCardActionButtons(conn),
          )
        ],
      ),
    );
  }

  List<Widget> _buildCardActionButtons(NearbyConnection conn) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isRequester = conn.requesterUid == currentUserId;

    if (conn.status == 'pending') {
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

    if (conn.status == 'expired') {
      return [
        TextButton(
          onPressed: () => ref.read(nearbyAlertProvider.notifier).declineConnectionRequest(conn.id),
          child: const Text("Dismiss", style: TextStyle(color: Colors.grey, fontSize: 12)),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => ref.read(nearbyAlertProvider.notifier).renewConnection(conn.id),
          child: const Text("Reconnect", style: TextStyle(fontSize: 12)),
        ),
      ];
    }

    // Active / Expiring
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
          backgroundColor: const Color(0xFF4F46E5),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () => ref.read(nearbyAlertProvider.notifier).renewConnection(conn.id),
        child: const Text("Renew", style: TextStyle(fontSize: 12)),
      ),
    ];
  }
}

// ─── Pulsing green dot indicator ─────────────────────────────────────────────

class _PulsingIndicator extends StatefulWidget {
  final Color color;
  const _PulsingIndicator({required this.color});

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
        final scale = 1.0 + (_pulseController.value * 0.8);
        final opacity = 1.0 - _pulseController.value;

        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: widget.color, width: 2),
                  ),
                ),
              ),
            ),
            Container(
              width: 10,
              height: 10,
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
