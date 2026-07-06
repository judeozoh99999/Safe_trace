import 'package:flutter/material.dart';
import 'add_connection_screen.dart';

enum NearbyState { active, expiring, empty, emergency }

class NearbyAlertScreen extends StatefulWidget {
  const NearbyAlertScreen({super.key});

  @override
  State<NearbyAlertScreen> createState() => _NearbyAlertScreenState();
}

class _NearbyAlertScreenState extends State<NearbyAlertScreen> {
  NearbyState _currentState = NearbyState.active;

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
              "Nearby Alert",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
            ),
            SizedBox(height: 2),
            Text(
              "20m proximity safety network",
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF111827)),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: const Color(0xFFF5F3FF),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text(
                  "PREVIEW:",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF6B21A8)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: NearbyState.values.map((state) {
                        final isSelected = _currentState == state;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _currentState = state;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF6B21A8) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF6B21A8) : const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Text(
                              state.name.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: isSelected ? Colors.white : const Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // State Banner Card
                    _buildStateHeaderBanner(),
                    const SizedBox(height: 16),

                    if (_currentState != NearbyState.empty) ...[
                      // Stats Row
                      _buildStatsRow(),
                      const SizedBox(height: 24),

                      // Connections Title
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text(
                            "Connections (4)",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
                          ),
                          Text(
                            "Live GPS tracking",
                            style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Connections List
                      _buildConnectionsList(),
                      const SizedBox(height: 16),

                      // Bottom Info Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFDBEAFE)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF2563EB)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Connections auto-disconnect when either party exits the 20m radius. Both parties can reconnect at any time.",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1E3A8A),
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Empty State View
                      _buildEmptyStateView(),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Fixed Bottom Add Connection Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF131522), // Dark Navy
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AddConnectionScreen()),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.add, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "Add Connection",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStateHeaderBanner() {
    switch (_currentState) {
      case NearbyState.active:
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
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xFF2E7D32),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "Active · 2 connections",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1B5E20)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Your proximity network is live",
                      style: TextStyle(fontSize: 12, color: Color(0xFF2E7D32), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

      case NearbyState.expiring:
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFE0B2)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE65100),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "Expiring Soon - Moving away",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFFE65100)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "1 connection approaching 20m limit",
                          style: TextStyle(fontSize: 12, color: Color(0xFFEF6C00), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFB74D).withOpacity(0.5)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100), size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Move closer to maintain your connection within the 20m radius.",
                        style: TextStyle(fontSize: 12, color: Color(0xFFE65100), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

      case NearbyState.empty:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xFF9CA3AF),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "Inactive · No active connections",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF374151)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Add connections to activate",
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

      case NearbyState.emergency:
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFCA5A5)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "Emergency - Alert sent to network",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFFB91C1C)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Trusted contacts and Nearby Alert notified",
                          style: TextStyle(fontSize: 12, color: Color(0xFFEF4444), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5).withOpacity(0.5)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Emergency Alert Sent to Trusted Contacts and Nearby Alert Network.",
                        style: TextStyle(fontSize: 12, color: Color(0xFFB91C1C), fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildStatsRow() {
    int active = _currentState == NearbyState.expiring ? 1 : 2;
    int expiring = _currentState == NearbyState.expiring ? 1 : 0;
    return Row(
      children: [
        _buildStatBox(active.toString(), "Active", const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
        const SizedBox(width: 8),
        _buildStatBox(expiring.toString(), "Expiring", const Color(0xFFFFF3E0), const Color(0xFFE65100)),
        const SizedBox(width: 8),
        _buildStatBox("1", "Pending", const Color(0xFFFFFDE7), const Color(0xFFF57F17)),
        const SizedBox(width: 8),
        _buildStatBox("20m", "Radius", const Color(0xFFF3E5F5), const Color(0xFF7B1FA2)),
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: textCol,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: textCol.withOpacity(0.8),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionsList() {
    return Column(
      children: [
        // 1. Transcorp Hilton Abuja
        _buildConnectionCard(
          initials: "TH",
          title: "Transcorp Hilton Abuja",
          category: "Hotel",
          distanceText: "8m / 20m limit",
          distancePercent: 0.4,
          isHotel: true,
          statusLabel: "Active",
          statusColor: const Color(0xFF2E7D32),
          statusBg: const Color(0xFFE8F5E9),
          actions: [
            _buildOutlineButton(
              icon: Icons.sync,
              label: "Renew",
              color: const Color(0xFF10B981),
            ),
            const SizedBox(width: 8),
            _buildOutlineButton(
              icon: Icons.close,
              label: "Disconnect",
              color: const Color(0xFFEF4444),
            ),
          ],
        ),

        // 2. Chioma Obi
        if (_currentState == NearbyState.expiring)
          _buildConnectionCard(
            initials: "CO",
            title: "Chioma Obi",
            category: "Personal",
            distanceText: "15m / 20m limit",
            distancePercent: 0.75,
            isHotel: false,
            statusLabel: "Expiring Soon",
            statusColor: const Color(0xFFE65100),
            statusBg: const Color(0xFFFFF3E0),
            warningMsg: "Moving away from the 20m radius. Connection will auto-disconnect if you move further.",
            actions: [
              _buildOutlineButton(
                icon: Icons.back_hand_outlined,
                label: "Hold Connection",
                color: const Color(0xFFFF9800),
              ),
              const SizedBox(width: 8),
              _buildOutlineButton(
                icon: Icons.close,
                label: "Disconnect",
                color: const Color(0xFFEF4444),
              ),
            ],
          )
        else
          _buildConnectionCard(
            initials: "CO",
            title: "Chioma Obi",
            category: "Personal",
            distanceText: _currentState == NearbyState.emergency ? "8m / 20m limit" : "5m / 20m limit",
            distancePercent: _currentState == NearbyState.emergency ? 0.4 : 0.25,
            isHotel: false,
            statusLabel: "Active",
            statusColor: const Color(0xFF2E7D32),
            statusBg: const Color(0xFFE8F5E9),
            actions: [
              _buildOutlineButton(
                icon: Icons.sync,
                label: "Renew",
                color: const Color(0xFF10B981),
              ),
              const SizedBox(width: 8),
              _buildOutlineButton(
                icon: Icons.close,
                label: "Disconnect",
                color: const Color(0xFFEF4444),
              ),
            ],
          ),

        // 3. Wuse General Hospital (Pending)
        _buildConnectionCard(
          initials: "WH",
          title: "Wuse General Hospital",
          category: "Medical",
          isHotel: true,
          statusLabel: "Pending",
          statusColor: const Color(0xFFF57F17),
          statusBg: const Color(0xFFFFFDE7),
          helperMsg: "Waiting for Wuse to approve.",
          actions: [
            _buildOutlineButton(
              icon: Icons.close,
              label: "Cancel Request",
              color: const Color(0xFFEF4444),
            ),
          ],
        ),

        // 4. Lagos State Security Trust Fund (Expired)
        _buildConnectionCard(
          initials: "LS",
          title: "Lagos State Security Trust Fund",
          category: "Emergency Responder",
          distanceText: "25m / 20m limit",
          distancePercent: 1.0,
          isHotel: false,
          statusLabel: "Expired",
          statusColor: const Color(0xFF6B7280),
          statusBg: const Color(0xFFF3F4F6),
          helperMsg: "Connection lost — 25m away. Renew to re-establish.",
          actions: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF131522),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  onPressed: () {},
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.sync, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text("Reconnect", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF9CA3AF), size: 18),
                onPressed: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConnectionCard({
    required String initials,
    required String title,
    required String category,
    String? distanceText,
    double? distancePercent,
    required bool isHotel,
    required String statusLabel,
    required Color statusColor,
    required Color statusBg,
    String? warningMsg,
    String? helperMsg,
    required List<Widget> actions,
  }) {
    final hasWarning = warningMsg != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasWarning
              ? const Color(0xFFFFB74D)
              : (statusLabel == "Pending"
                  ? const Color(0xFFFDE047)
                  : const Color(0xFFE5E7EB)),
          width: hasWarning ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Initials Circle
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: initials == "TH"
                          ? const Color(0xFF1E3A8A)
                          : (initials == "CO"
                              ? const Color(0xFF8B5CF6)
                              : (initials == "WH"
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFE5E7EB))),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: initials == "LS" ? const Color(0xFF6B7280) : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isHotel)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.verified, color: Color(0xFF10B981), size: 14),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          category == "Hotel"
                              ? Icons.apartment_rounded
                              : (category == "Personal"
                                  ? Icons.person_outline
                                  : (category == "Medical"
                                      ? Icons.local_hospital_outlined
                                      : Icons.shield_outlined)),
                          size: 14,
                          color: const Color(0xFF9CA3AF),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          category,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Status Pill
              Container(
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 6, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (distanceText != null && distancePercent != null) ...[
            const SizedBox(height: 16),
            // Distance indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.navigation_outlined, size: 12, color: Color(0xFF6B7280)),
                    SizedBox(width: 4),
                    Text("Distance", style: TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
                  ],
                ),
                Text(
                  distanceText,
                  style: TextStyle(
                    fontSize: 11,
                    color: distancePercent > 0.8 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: distancePercent,
                backgroundColor: const Color(0xFFF3F4F6),
                valueColor: AlwaysStoppedAnimation<Color>(
                  distancePercent > 0.8 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                ),
                minHeight: 6,
              ),
            ),
          ],

          if (warningMsg != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100), size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      warningMsg,
                      style: const TextStyle(fontSize: 11, color: Color(0xFFE65100), fontWeight: FontWeight.bold, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (helperMsg != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  statusLabel == "Pending" ? Icons.access_time_rounded : Icons.info_outline_rounded,
                  size: 14,
                  color: statusLabel == "Pending" ? const Color(0xFFF57F17) : const Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    helperMsg,
                    style: TextStyle(
                      fontSize: 12,
                      color: statusLabel == "Pending" ? const Color(0xFFE65100) : const Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 12),

          // Actions
          Row(children: actions),
        ],
      ),
    );
  }

  Widget _buildOutlineButton({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withOpacity(0.3), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 10),
          backgroundColor: color.withOpacity(0.04),
        ),
        onPressed: () {},
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStateView() {
    return Column(
      children: [
        const SizedBox(height: 48),
        Center(
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFDBEAFE), width: 2),
            ),
            child: const Icon(Icons.radar_rounded, color: Color(0xFF2563EB), size: 48),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          "No Nearby Connections",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            "Connect with venues, trusted people, and emergency responders near you.",
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.45),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.location_on_outlined, color: Color(0xFF2563EB), size: 16),
              SizedBox(width: 8),
              Text(
                "Connections auto-disconnect when either party\nmoves beyond 20 metres.",
                style: TextStyle(fontSize: 11, color: Color(0xFF1E3A8A), fontWeight: FontWeight.w600, height: 1.3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: 220,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF131522),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddConnectionScreen()),
              );
            },
            child: const Text(
              "+ Add First Connection",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ),
        const SizedBox(height: 48),
      ],
    );
  }
}
