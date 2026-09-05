import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/sms_service.dart';
import '../../contacts/providers/trusted_contacts_provider.dart';
import '../../contacts/screens/trusted_circle_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/home_provider.dart';
import '../services/location_service.dart';
import '../../panic/screens/panic_alert_screen.dart';
import '../../notes/screens/log_notes_screen.dart';
import 'nearby_alert_screen.dart';
import 'notifications_screen.dart';
import '../../home_shell.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/inactivity_service.dart';
import '../../../core/services/battery_optimization_service.dart';
import 'package:share_plus/share_plus.dart';
import '../../profile/screens/profile_detail_screens.dart';
import '../../route/screens/route_intel_screen.dart';
import '../../../shared/widgets/upgrade_bottom_sheet.dart';
import '../../../core/providers/subscription_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _rippleController;
  late AnimationController _panicHoldController;
  bool _isHoldingPanic = false;
  bool _hasSmsPermission = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 1. Repeating concentric ripple controller for the panic button
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    // 2. Panic button hold progress controller (2 seconds hold)
    _panicHoldController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _panicHoldController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _triggerPanic();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLocationPermissionsOnLaunch();
      _checkInactivityOnLaunch();
      _checkSmsPermission();
      BatteryOptimizationService.checkAndPromptPermissions(context);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSmsPermission();
    }
  }

  Future<void> _checkSmsPermission() async {
    if (!Platform.isAndroid) return;
    final status = await Permission.sms.status;
    if (!mounted) return;
    setState(() {
      _hasSmsPermission = status.isGranted;
    });

    if (!status.isGranted) {
      final prefs = await SharedPreferences.getInstance();
      final prompted = prefs.getBool('sms_permission_prompted') ?? false;

      if (!prompted && mounted) {
        await prefs.setBool('sms_permission_prompted', true);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text("SMS Permission Required"),
            content: const Text(
              "SafeTrace needs SMS permission to send emergency alerts to your trusted contacts when you trigger the panic button. This is essential for the panic feature to work.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final res = await Permission.sms.request();
                  if (mounted) {
                    setState(() {
                      _hasSmsPermission = res.isGranted;
                    });
                  }
                },
                child: const Text("Grant Permission"),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _checkLocationPermissionsOnLaunch() async {
    await LocationService.requestPermissionsSilent();
  }

  Future<void> _checkInactivityOnLaunch() async {
    await InactivityService.checkInactivity(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rippleController.dispose();
    _panicHoldController.dispose();
    super.dispose();
  }

  void _onPanicStart() {
    setState(() {
      _isHoldingPanic = true;
    });
    _panicHoldController.forward();
  }

  void _onPanicEnd() {
    if (_panicHoldController.status != AnimationStatus.completed) {
      setState(() {
        _isHoldingPanic = false;
      });
      _panicHoldController.reverse();
    }
  }

  Future<void> _triggerPanic() async {
    _panicHoldController.reset();
    setState(() {
      _isHoldingPanic = false;
    });

    final authState = ref.read(authNotifierProvider);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFEF4444),
            content: Text("Please sign in again to use the panic button."),
          ),
        );
      }
      return;
    }

    final userName = authState.displayName.isEmpty ? 'A SafeTrace User' : authState.displayName;

    // Fetch accepted contacts using the single shared method
    final List<AcceptedTrustedContact> circleContacts =
        await TrustedContactsService.getAcceptedTrustedContacts(currentUser.uid);

    final contactNames = circleContacts.map((c) => c.firstName).join(', ');
    debugPrint("PANIC CONTACTS FOUND: ${circleContacts.length} contacts. Names: $contactNames");

    if (circleContacts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: const Text("No contacts in your Trusted Circle yet. Please add trusted contacts first."),
            action: SnackBarAction(
              label: "Add Contacts",
              textColor: Colors.white,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TrustedCircleScreen()),
                );
              },
            ),
          ),
        );
      }
      return;
    }

    // Determine current coordinates
    double lat = 0.0;
    double lng = 0.0;
    try {
      final currentPos = await LocationService.getCurrentPosition();
      if (currentPos != null) {
        lat = currentPos.latitude;
        lng = currentPos.longitude;
      } else {
        final homeState = ref.read(homeProvider);
        lat = homeState.currentLatitude;
        lng = homeState.currentLongitude;
      }
    } catch (_) {
      final homeState = ref.read(homeProvider);
      lat = homeState.currentLatitude;
      lng = homeState.currentLongitude;
    }

    final firstName = authState.firstName.isNotEmpty ? authState.firstName : "User";
    final lastName = authState.lastName;

    final message = await SmsService.buildPanicMessage(
      firstName: firstName,
      lastName: lastName,
      lat: lat,
      lng: lng,
    );

    final recipients = circleContacts.map((c) => c.phoneNumber).where((p) => p.isNotEmpty).toList();

    try {
      if (recipients.isNotEmpty && _hasSmsPermission) {
        await SmsService.sendPanicSms(phoneNumbers: recipients, message: message);
      }
    } catch (e) {
      debugPrint("Failed to send native SMS: $e");
    }

    final List<String> notifiedUids = [];
    final List<String> trustedPhones = [];

    // Send dynamic distress notifications to contacts in trusted circle
    for (final contact in circleContacts) {
      final contactUid = contact.uid;
      final contactPhone = contact.phoneNumber;
      final contactName = contact.name;

      if (contactUid.isNotEmpty) {
        notifiedUids.add(contactUid);
      }
      if (contactPhone.isNotEmpty) {
        trustedPhones.add(contactPhone);
      }

      try {
        if (contactUid.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(contactUid)
              .collection('notifications')
              .add({
            'id': DateTime.now().millisecondsSinceEpoch.toString(),
            'title': '🚨 EMERGENCY DISTRESS ALERT',
            'desc': '$userName is in danger! Pinpoint location: https://www.google.com/maps/search/?api=1&query=$lat,$lng',
            'message': '$userName triggered an emergency alert! Location: https://www.google.com/maps/search/?api=1&query=$lat,$lng',
            'timestamp': FieldValue.serverTimestamp(),
            'type': 'distress',
            'senderName': userName,
            'senderUid': currentUser.uid,
            'latitude': lat,
            'longitude': lng,
            'lat': lat,
            'lng': lng,
          });
        }
      } catch (e) {
        debugPrint("Failed to notify contact $contactName: $e");
      }
    }

    // Write active panic document to active_panics in backend
    try {
      await FirebaseFirestore.instance.collection('active_panics').doc(currentUser.uid).set({
        'uid': currentUser.uid,
        'first_name': authState.firstName.isEmpty ? 'User' : authState.firstName,
        'last_name': authState.lastName,
        'lat': lat,
        'lng': lng,
        'address': 'Emergency Location',
        'triggered_at': FieldValue.serverTimestamp(),
        'is_active': true,
        'notified_contacts': notifiedUids,
        'trusted_phones': trustedPhones,
        'declined_by': [],
      });
    } catch (e) {
      debugPrint("Failed to set active panic doc: $e");
    }

    // Insert overlay notification banner
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 50,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () {
              entry.remove();
              ref.read(homeShellIndexProvider.notifier).state = 1;
              ref.read(routeIntelActiveTabProvider.notifier).state = 1;
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFEF4444),
                    child: Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "ALERT ACTIVE: $userName",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          "Emergency SMS sent to circle. Tap to view on Live Map.",
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white54),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 8), () {
      if (entry.mounted) {
        entry.remove();
      }
    });

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PanicAlertScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final homeState = ref.watch(homeProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userFirstName = authState.firstName.isEmpty ? 'User' : authState.firstName;
    final initials = (authState.firstName.isNotEmpty && authState.lastName.isNotEmpty)
        ? "${authState.firstName[0]}${authState.lastName[0]}".toUpperCase()
        : (userFirstName.length >= 2 ? userFirstName.substring(0, 2).toUpperCase() : 'U');

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  // User Avatar
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFF131522), // Dark Navy
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Greetings
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Good evening",
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "$userFirstName 👋",
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status Pill "Safe" / "Tracking"
                  GestureDetector(
                    onTap: () async {
                      final hasPermission = await LocationService.checkAndRequestPermissions(context);
                      if (!hasPermission) return;
                      try {
                        await ref.read(homeProvider.notifier).toggleTracking();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ref.read(homeProvider).isTracking
                                    ? "Location tracking enabled"
                                    : "Location tracking disabled",
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString())),
                          );
                        }
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: homeState.isTracking
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: homeState.isTracking
                              ? const Color(0xFFC8E6C9)
                              : const Color(0xFFE5E7EB),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.circle,
                            size: 8,
                            color: homeState.isTracking
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFF9CA3AF),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            homeState.isTracking ? "Tracking" : "Unsafe",
                            style: TextStyle(
                              color: homeState.isTracking
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFF6B7280),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Share icon (red button)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD32F2F),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.share, color: Colors.white, size: 18),
                      onPressed: () {
                        final user = ref.read(firebaseAuthProvider).currentUser;
                        if (user != null) {
                          final trackingUrl = "https://safetrace.live/track/${user.uid}";
                          Share.share(
                            "Securely track my live location on SafeTrace: $trackingUrl",
                            subject: "SafeTrace Live Location Tracking",
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Authenticate first to share your tracking link")),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(FirebaseAuth.instance.currentUser?.uid ?? 'unknown')
                        .collection('notifications')
                        .where('type', isEqualTo: 'distress')
                        .limit(1)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final hasDistress = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
                      return PulsingNotificationRing(
                        isDistress: hasDistress,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                            );
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.cardDark : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: hasDistress 
                                    ? const Color(0xFFEF4444) 
                                    : (isDark ? AppColors.dividerDark : const Color(0xFFE5E7EB)),
                                width: hasDistress ? 1.5 : 1.0,
                              ),
                            ),
                            child: Icon(
                              hasDistress ? Icons.notifications_active_rounded : Icons.notifications_none,
                              color: hasDistress 
                                  ? const Color(0xFFEF4444) 
                                  : (isDark ? Colors.white : const Color(0xFF111827)),
                              size: 20,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const Text(
              "EMERGENCY PANIC",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Color(0xFF9CA3AF),
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // 2. Large Central Panic Button with Looping Ripples
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 320,
                  height: 320,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Concentric Looping Ripple Outlines
                      AnimatedBuilder(
                        animation: _rippleController,
                        builder: (context, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: List.generate(3, (index) {
                              // Stagger the start times of the ripples
                              final double progress = (_rippleController.value + (index / 3.0)) % 1.0;
                              final double scale = 1.0 + (progress * 1.5);
                              final double opacity = (1.0 - progress) * 0.45;

                              return Transform.scale(
                                scale: scale,
                                child: Opacity(
                                  opacity: opacity,
                                  child: Container(
                                    width: 130,
                                    height: 130,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFFEB444E).withOpacity(0.4),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          );
                        },
                      ),

                      // SOS HOLD BUTTON
                      GestureDetector(
                        onLongPressStart: (_) => _onPanicStart(),
                        onLongPressEnd: (_) => _onPanicEnd(),
                        child: AnimatedBuilder(
                          animation: _panicHoldController,
                          builder: (context, child) {
                            final double scale = 1.0 + (_panicHoldController.value * 0.15);

                            return Transform.scale(
                              scale: scale,
                              child: Container(
                                width: 144,
                                height: 144,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEB444E), // Coral red
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFEB444E).withOpacity(0.45),
                                      blurRadius: 24,
                                      offset: const Offset(0, 10),
                                    )
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Holding Progress Overlay Ring
                                    if (_isHoldingPanic)
                                      SizedBox(
                                        width: 134,
                                        height: 134,
                                        child: CircularProgressIndicator(
                                          value: _panicHoldController.value,
                                          strokeWidth: 5,
                                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                          backgroundColor: Colors.white24,
                                        ),
                                      ),
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Icon(
                                          Icons.shield_outlined,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                        SizedBox(height: 6),
                                        Text(
                                          "HOLD TO ALERT\nCONTACTS",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                            height: 1.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Contact availability indicator or empty warning banner (Step 8 & 9)
            Consumer(
              builder: (context, ref, child) {
                final contactsAsync = ref.watch(acceptedTrustedContactsStreamProvider);
                final contacts = contactsAsync.valueOrNull ?? [];
                final count = contacts.length;

                if (contactsAsync.isLoading && contacts.isEmpty) {
                  return const SizedBox(height: 16);
                }

                if (count > 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "$count ${count == 1 ? 'contact' : 'contacts'} ready",
                          style: const TextStyle(
                            color: Color(0xFF059669),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const TrustedCircleScreen()),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFEF4444), width: 1.2),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "No contacts in your Trusted Circle yet. Tap to add contacts.",
                                style: TextStyle(
                                  color: Color(0xFF991B1B),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, color: Color(0xFF991B1B), size: 18),
                          ],
                        ),
                      ),
                    ),
                  );
                }
              },
            ),

            const Text(
              "Hold for 2 seconds to send emergency alert",
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
            if (!_hasSmsPermission) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  await openAppSettings();
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "SMS permission not granted — panic alerts will use notifications only. Tap to enable in settings.",
                          style: TextStyle(
                            color: Color(0xFF92400E),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // 3. Grid actions & Recent Activity Section
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    // Grid Cards Row
                    Row(
                      children: [
                        // Log My Location Card
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final subInfo = ref.read(currentSubscriptionProvider);
                              final remaining = subInfo.locationLogsRemainingThisMonth;
                              if (remaining != null && remaining <= 0) {
                                UpgradeBottomSheet.show(
                                  context,
                                  message: 'Unlock unlimited location logging with SafeTrace Plus.',
                                );
                                return;
                              }

                              final hasPermission = await LocationService.checkAndRequestPermissions(context);
                              if (hasPermission && mounted) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const LogNotesScreen()),
                                );
                              }
                            },
                            child: Container(
                              height: 125,
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.cardDark : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: isDark ? AppColors.dividerDark : const Color(0xFFE5E7EB)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1F2937) : const Color(0xFFEEF2FF),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.all(6),
                                    child: Icon(Icons.location_on_outlined, color: isDark ? AppColors.primary : const Color(0xFF4F46E5), size: 20),
                                  ),
                                  const Spacer(),
                                  Text(
                                    "Log My Location",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : const Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Builder(
                                    builder: (context) {
                                      final subInfo = ref.watch(currentSubscriptionProvider);
                                      final remaining = subInfo.locationLogsRemainingThisMonth;
                                      if (remaining != null && remaining >= 1 && remaining <= 3) {
                                        return Text(
                                          "$remaining logs remaining this month",
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFD97706),
                                          ),
                                        );
                                      }
                                      return const Text(
                                        "Add a safety note",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF6B7280),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Nearby Alert Card
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const NearbyAlertScreen()),
                              );
                            },
                            child: Container(
                              height: 125,
                              decoration: BoxDecoration(
                                color: const Color(0xFF131522), // Dark Navy matching mockup
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  )
                                ],
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.all(6),
                                    child: const Icon(Icons.radar, color: Colors.white, size: 20),
                                  ),
                                  const Spacer(),
                                  const Text(
                                    "Nearby Alert",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                      "Connect with your nearby contact",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white60,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Plan a Safe Route Card
                    GestureDetector(
                      onTap: () {
                        ref.read(homeShellIndexProvider.notifier).state = 1;
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.cardDark : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? AppColors.dividerDark : const Color(0xFFE5E7EB)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2D1B22) : const Color(0xFFFFF1F2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.all(8),
                              child: Icon(Icons.navigation_outlined, color: isDark ? AppColors.primary : const Color(0xFFF43F5E), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Plan a Safe Route",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : const Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    "AI-Augmented route intelligence",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Builder(
                              builder: (context) {
                                final subInfo = ref.watch(currentSubscriptionProvider);
                                if (subInfo.isFree) {
                                  return Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
                                        SizedBox(width: 2),
                                        Text(
                                          'PLUS',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFFF59E0B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                            const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Recent Activity
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Recent Activity",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                        Text(
                          "See all",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.primary : const Color(0xFF4F46E5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Recent Activity List Items
                    if (homeState.logs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            "No recent activity logged.",
                            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                          ),
                        ),
                      )
                    else ...[
                      Builder(
                        builder: (context) {
                          final subInfo = ref.watch(currentSubscriptionProvider);
                          final limit = subInfo.recentActivityLimit;
                          final displayedLogs = homeState.logs.take(limit).toList();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              ...displayedLogs.map((log) {
                                final rawLat = double.tryParse((log['lat'] ?? log['latitude'] ?? '0.0').toString()) ?? 0.0;
                                final rawLng = double.tryParse((log['lng'] ?? log['longitude'] ?? '0.0').toString()) ?? 0.0;
                                return _buildActivityItem(
                                  log['id'] ?? '',
                                  log['location'] ?? '',
                                  log['note'] ?? '',
                                  log['timestamp'] ?? '',
                                  source: (log['source'] ?? '').toString(),
                                  tagLabel: (log['tag_label'] ?? '').toString(),
                                  lat: rawLat,
                                  lng: rawLng,
                                );
                              }).toList(),
                              if (subInfo.isFree && homeState.logs.length > 5) ...[
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: () {
                                    UpgradeBottomSheet.show(
                                      context,
                                      message: 'Upgrade to SafeTrace Plus to view your full activity history.',
                                    );
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8.0),
                                    child: Text(
                                      'See more in SafeTrace Plus →',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF4F46E5),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(String id, String title, String subtitle, String time, {String source = '', String tagLabel = '', double lat = 0.0, double lng = 0.0}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isNearbyAlert = source == 'nearby_alert' || tagLabel == 'Nearby Alert' || subtitle.contains('Nearby Alert');

    return Dismissible(
      key: Key(id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        ref.read(homeProvider.notifier).deleteLog(id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location entry deleted")),
        );
      },
      child: InkWell(
        onTap: () {
          debugPrint("RECENT ACTIVITY TAP LAT $lat LNG $lng");
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RouteIntelScreen(
                initialDestLatLng: (lat != 0.0 && lng != 0.0) ? LatLng(lat, lng) : null,
                initialDestAddress: title,
                isNearbyAlertHistoricalView: isNearbyAlert,
                historicalCardTitle: isNearbyAlert ? "Nearby Alert Connection Location" : null,
              ),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppColors.dividerDark : const Color(0xFFF3F4F6)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: isNearbyAlert ? const Color(0xFF6C3FC4).withOpacity(0.15) : (isDark ? const Color(0xFF1F2937) : const Color(0xFFEEF2FF)),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(8),
                child: Icon(
                  isNearbyAlert ? Icons.people_alt_rounded : Icons.location_on,
                  color: isNearbyAlert ? const Color(0xFF6C3FC4) : (isDark ? AppColors.primary : const Color(0xFF4F46E5)),
                  size: 18,
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
                            title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
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
                    const SizedBox(height: 2),
                    Text(
                      isNearbyAlert ? "Connected via Nearby Alert" : subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: isNearbyAlert ? FontStyle.italic : FontStyle.normal,
                        color: isNearbyAlert ? const Color(0xFF6C3FC4) : (isDark ? AppColors.textDarkSecondary : const Color(0xFF6B7280)),
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              time,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.textDarkSecondary : const Color(0xFF9CA3AF),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class PulsingNotificationRing extends StatefulWidget {
  final Widget child;
  final bool isDistress;

  const PulsingNotificationRing({
    super.key,
    required this.child,
    required this.isDistress,
  });

  @override
  State<PulsingNotificationRing> createState() => _PulsingNotificationRingState();
}

class _PulsingNotificationRingState extends State<PulsingNotificationRing> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    if (widget.isDistress) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant PulsingNotificationRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDistress && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isDistress && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isDistress) return widget.child;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + (_pulseController.value * 0.18);
        final opacity = 0.8 - (_pulseController.value * 0.6);
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 40 * scale,
              height: 40 * scale,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEF4444).withOpacity(opacity),
              ),
            ),
            widget.child,
          ],
        );
      },
    );
  }
}
