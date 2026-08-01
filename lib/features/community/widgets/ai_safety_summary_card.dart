import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/community_safety_summary.dart';
import '../providers/community_summary_provider.dart';

class AiSafetySummaryCard extends ConsumerWidget {
  final LatLng location;

  const AiSafetySummaryCard({
    super.key,
    required this.location,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final param = SummaryLocationParam(location: location);
    final summaryAsync = ref.watch(communitySafetySummaryProvider(param));

    return summaryAsync.when(
      data: (summary) {
        if (summary == null || summary.noteCount == 0) {
          return const SizedBox.shrink();
        }
        return _buildCardContent(context, ref, summary, param);
      },
      loading: () => _buildSkeletonLoader(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildCardContent(
    BuildContext context,
    WidgetRef ref,
    CommunitySafetySummary summary,
    SummaryLocationParam param,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Header Row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF8B5CF6),
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text(
                  "AI Safety Summary",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Color(0xFF9CA3AF),
                    size: 16,
                  ),
                  tooltip: "Refresh Summary",
                  onPressed: () {
                    // Force refresh bypass cache
                    final refreshParam = SummaryLocationParam(
                      location: location,
                      bypassCache: true,
                    );
                    ref.refresh(communitySafetySummaryProvider(refreshParam));
                  },
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.shield_outlined,
                  color: Color(0xFF9CA3AF),
                  size: 14,
                ),
                const SizedBox(width: 4),
                const Text(
                  "Powered by Gemini",
                  style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          // ── 2. Divider Line ──
          const Divider(
            color: Color(0xFF2A2A42),
            height: 1,
            thickness: 1,
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 3. Safety Level Badge Pill (Centered) ──
                Center(
                  child: _buildSafetyLevelPill(summary.safetyLevel),
                ),
                const SizedBox(height: 14),

                // ── 4. Summary Text ──
                Text(
                  summary.summary,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),

                // ── 5. Key Concerns Section ──
                if (summary.keyConcerns.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    "Key Concerns",
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...summary.keyConcerns.map((concern) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 6, right: 8),
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF59E0B),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                concern,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ],
            ),
          ),

          // ── 6. Footer Row ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF0F1117),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  color: Color(0xFF9CA3AF),
                  size: 13,
                ),
                const SizedBox(width: 6),
                Text(
                  "Based on ${summary.noteCount} notes — Updated ${_formatTimeAgo(summary.generatedAt)}",
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyLevelPill(String level) {
    Color bg;
    IconData icon;
    String text = level.toUpperCase();

    switch (level.toLowerCase()) {
      case 'safe':
        bg = const Color(0xFF2D9B5A);
        icon = Icons.check_circle_rounded;
        break;
      case 'moderate':
        bg = const Color(0xFFF59E0B);
        icon = Icons.info_rounded;
        break;
      case 'caution':
        bg = const Color(0xFFEA580C);
        icon = Icons.warning_amber_rounded;
        break;
      case 'danger':
        bg = const Color(0xFFE63946);
        icon = Icons.error_rounded;
        break;
      default:
        bg = const Color(0xFF6B7280);
        icon = Icons.info_rounded;
        text = 'UNKNOWN';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 15,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 20, height: 20, color: Colors.white24),
              const SizedBox(width: 8),
              Container(width: 120, height: 16, color: Colors.white24),
              const Spacer(),
              Container(width: 90, height: 14, color: Colors.white24),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(width: 100, height: 28, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(14))),
          ),
          const SizedBox(height: 16),
          Container(width: double.infinity, height: 12, color: Colors.white24),
          const SizedBox(height: 6),
          Container(width: double.infinity, height: 12, color: Colors.white24),
          const SizedBox(height: 6),
          Container(width: 200, height: 12, color: Colors.white24),
          const SizedBox(height: 16),
          Container(width: 80, height: 10, color: Colors.white24),
          const SizedBox(height: 8),
          Container(width: 160, height: 10, color: Colors.white24),
        ],
      ),
    ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: Colors.white.withOpacity(0.08));
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) {
      return "just now";
    } else if (diff.inMinutes < 60) {
      return "${diff.inMinutes} minutes ago";
    } else {
      return "${diff.inHours} hours ago";
    }
  }
}
