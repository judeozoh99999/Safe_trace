import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/custom_buttons.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../location/services/location_service.dart';
import '../../location/providers/home_provider.dart';
import '../providers/community_provider.dart';
import '../widgets/ai_safety_summary_card.dart';
import '../../../shared/widgets/upgrade_bottom_sheet.dart';
import '../../../core/providers/subscription_provider.dart';
import 'select_community_location_screen.dart';
import '../../home_shell.dart';

final selectedCommunityNoteProvider = StateProvider<CommunityNoteModel?>((ref) => null);

class CommunityFeedScreen extends ConsumerStatefulWidget {
  const CommunityFeedScreen({super.key});

  @override
  ConsumerState<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends ConsumerState<CommunityFeedScreen> {
  LatLng? _selectedCenterLatLng;
  String _selectedCenterAddress = "Your Current Location";
  Position? _lastGpsPosition;

  @override
  void initState() {
    super.initState();
    _initGpsPosition();
  }

  Future<void> _initGpsPosition() async {
    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      if (mounted) {
        setState(() {
          _lastGpsPosition = pos;
        });
      }
    } catch (_) {}
  }

  double _calculateHaversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 - cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final communityState = ref.watch(communityProvider);
    final homeState = ref.watch(homeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notifier = ref.read(communityProvider.notifier);

    // Calculate center coordinates
    final centerLat = _selectedCenterLatLng?.latitude ?? (homeState.currentLatitude != 0.0 ? homeState.currentLatitude : (_lastGpsPosition?.latitude ?? 0.0));
    final centerLng = _selectedCenterLatLng?.longitude ?? (homeState.currentLongitude != 0.0 ? homeState.currentLongitude : (_lastGpsPosition?.longitude ?? 0.0));

    // Filter notes within 10km radius using Haversine
    final filteredNotes = communityState.notes.where((n) {
      if (n.latitude == 0.0 && n.longitude == 0.0) return true;
      final dist = _calculateHaversineDistance(centerLat, centerLng, n.latitude, n.longitude);
      return dist <= 10.0;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF9FAFB),
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              // Heading
              Text(
                "Community",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                "Crowdsourced safety updates within 10km",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark ? AppColors.textDarkSecondary : const Color(0xFF6B7280),
                    ),
              ),
              const SizedBox(height: 10),

              // Location Selector Bar
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SelectCommunityLocationScreen(
                        currentGpsLocation: LatLng(centerLat, centerLng),
                        currentSelectedAddress: _selectedCenterAddress,
                      ),
                    ),
                  );
                  if (result != null && result is Map<String, dynamic>) {
                    setState(() {
                      _selectedCenterLatLng = result['latLng'] as LatLng;
                      _selectedCenterAddress = result['address'] as String;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2235) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: Color(0xFFEF4444), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedCenterAddress,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Color(0xFFEF4444), size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Feed List
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    if (_selectedCenterLatLng != null)
                      AiSafetySummaryCard(location: _selectedCenterLatLng!),
                    if (filteredNotes.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.report_gmailerrorred_rounded, size: 48, color: Color(0xFF9CA3AF)),
                              SizedBox(height: 12),
                              Text(
                                "No community reports near you right now. Be the first to share something.",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...filteredNotes.map((note) {
                        final isOwnNote = note.uid == currentUserId;
                        return _buildNoteCard(context, ref, note, isOwnNote, isDark);
                      }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Builder(
        builder: (context) {
          final subInfo = ref.watch(currentSubscriptionProvider);
          return FloatingActionButton(
            backgroundColor: subInfo.isFree ? const Color(0xFF6B7280) : AppColors.primary,
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            elevation: 6,
            onPressed: () {
              if (subInfo.isFree) {
                UpgradeBottomSheet.show(
                  context,
                  message: 'Upgrade to SafeTrace Plus to post community safety alerts.',
                );
                return;
              }
              _showAddReportSheet(context, ref, notifier, isDark);
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.add_alert_rounded, size: 26),
                if (subInfo.isFree)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_rounded, size: 10, color: Colors.white),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Fully Anonymous Community Feed Post Card Builder
  Widget _buildNoteCard(BuildContext context, WidgetRef ref, CommunityNoteModel note, bool isOwnNote, bool isDark) {
    return GestureDetector(
      onTap: () {
        ref.read(selectedCommunityNoteProvider.notifier).state = note;
        ref.read(homeShellIndexProvider.notifier).state = 1; // Route Tab
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10.0),
        decoration: BoxDecoration(
          color: isOwnNote 
              ? (isDark ? const Color(0xFF1E2235) : const Color(0xFFEEF2FF))
              : (isDark ? const Color(0xFF1A1D27) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isOwnNote 
                ? const Color(0xFFC7D2FE) 
                : (isDark ? const Color(0xFF2E3347) : const Color(0xFFE5E7EB)),
            width: 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: isDark ? const Color(0xFF2E3347) : const Color(0xFFE5E7EB),
              child: Icon(Icons.person, size: 16, color: isDark ? Colors.white54 : const Color(0xFF6B7280)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Anonymous User",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      Text(
                        _getTimeAgo(note.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    note.location,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    note.noteText,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF374151),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isOwnNote)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                onPressed: () => _confirmDeleteNote(context, ref, note.id),
              ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(dynamic timestamp) {
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      return "Recently";
    }

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) return "${difference.inSeconds}s ago";
    if (difference.inMinutes < 60) return "${difference.inMinutes}m ago";
    if (difference.inHours < 24) return "${difference.inHours}h ago";
    return "${difference.inDays}d ago";
  }

  void _confirmDeleteNote(BuildContext context, WidgetRef ref, String noteId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Are you sure you want to delete this note?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel"),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          try {
                             await FirebaseFirestore.instance
                                 .collection('community_notes')
                                 .doc(noteId)
                                 .delete();
                             ScaffoldMessenger.of(context).showSnackBar(
                               const SnackBar(content: Text("Note deleted successfully.")),
                             );
                          } catch (e) {
                             debugPrint("Failed to delete note: $e");
                          }
                        },
                        child: const Text("Delete"),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  // Submission Dialog BottomSheet
  void _showAddReportSheet(BuildContext context, WidgetRef ref, CommunityNotifier notifier, bool isDark) {
    final noteController = TextEditingController();
    String address = "Resolving location...";
    double latitude = 0.0;
    double longitude = 0.0;
    bool isLocationResolved = false;

    // Resolve current coordinates & address in the background
    final homeState = ref.read(homeProvider);
    if (homeState.currentLatitude != 0.0 && homeState.currentLongitude != 0.0) {
      latitude = homeState.currentLatitude;
      longitude = homeState.currentLongitude;
      isLocationResolved = true;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            // Trigger geocoder once coordinates are set
            if (isLocationResolved && address == "Resolving location...") {
              address = "Fetching address name...";
              LocationService.reverseGeocode(latitude, longitude).then((addr) {
                setSheetState(() {
                  address = addr;
                });
              }).catchError((_) {
                setSheetState(() {
                  address = "Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}";
                });
              });
            }

            // Fallback Geolocator fetch if homeProvider coordinates were 0,0
            if (!isLocationResolved) {
              Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best).then((pos) {
                latitude = pos.latitude;
                longitude = pos.longitude;
                isLocationResolved = true;
                setSheetState(() {});
              }).catchError((_) {
                setSheetState(() {
                  address = "Unable to resolve GPS location.";
                });
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: AppSpacing.md,
                right: AppSpacing.md,
                top: AppSpacing.lg,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Report Safety Incident",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Current Location (read-only)
                    const Text("CURRENT LOCATION", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Text(
                        address,
                        style: const TextStyle(
                          color: Color(0xFF374151),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Details Note Input
                    const Text("YOUR NOTES", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                    const SizedBox(height: 6),
                    SafeTraceTextField(
                      hintText: "What is happening? Provide clear details to help others.",
                      controller: noteController,
                      maxLines: 4,
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Send Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: !isLocationResolved
                            ? null
                            : () async {
                                final note = noteController.text.trim();
                                if (note.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Please type some notes")),
                                  );
                                  return;
                                }

                                await notifier.addNote(
                                  lat: latitude,
                                  lng: longitude,
                                  address: address,
                                  note: note,
                                );
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Safety note posted to the feed!")),
                                );
                              },
                        child: const Text(
                          "Send",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
