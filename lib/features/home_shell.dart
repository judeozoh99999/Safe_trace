import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../shared/widgets/custom_bottom_nav_bar.dart';
import 'location/screens/home_screen.dart';
import 'route/screens/route_intel_screen.dart';
import 'community/screens/community_feed_screen.dart';
import 'sentinel/screens/watch_mode_screen.dart';
import 'profile/screens/profile_screen.dart';
import 'panic/screens/panic_interrupt_screen.dart';

final homeShellIndexProvider = StateProvider<int>((ref) => 0);

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  StreamSubscription? _panicAlertSubscription;
  bool _isInterruptShowing = false;

  final List<Widget> _screens = const [
    HomeScreen(),
    RouteIntelScreen(),
    CommunityFeedScreen(),
    WatchModeScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _listenToIncomingPanics();
  }

  @override
  void dispose() {
    _panicAlertSubscription?.cancel();
    super.dispose();
  }

  void _listenToIncomingPanics() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _panicAlertSubscription?.cancel();
    _panicAlertSubscription = FirebaseFirestore.instance
        .collection('active_panics')
        .where('is_active', isEqualTo: true)
        .snapshots()
        .listen((snapshot) async {
      if (!mounted) return;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final senderUid = data['uid'] ?? doc.id;
        if (senderUid == user.uid) continue; // Skip self

        final List<dynamic> notifiedContacts = data['notified_contacts'] ?? [];
        final List<dynamic> declinedBy = data['declined_by'] ?? [];

        if (declinedBy.contains(user.uid)) continue;

        bool isNotified = notifiedContacts.contains(user.uid);

        if (!isNotified) {
          final List<dynamic> trustedPhones = data['trusted_phones'] ?? [];
          final userPhone = user.phoneNumber ?? '';
          if (userPhone.isNotEmpty) {
            final cleanUserPhone = userPhone.replaceAll(RegExp(r'[^\d]'), '');
            for (final phone in trustedPhones) {
              final cleanPhone = phone.toString().replaceAll(RegExp(r'[^\d]'), '');
              if (cleanPhone.isNotEmpty && cleanUserPhone.endsWith(cleanPhone.length >= 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone)) {
                isNotified = true;
                break;
              }
            }
          }
        }

        if (isNotified && !_isInterruptShowing) {
          _isInterruptShowing = true;

          // Save panic details in SharedPreferences for PanicInterruptScreen
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('active_panic_uid', senderUid);
          await prefs.setString('active_panic_first_name', data['first_name'] ?? '');
          await prefs.setString('active_panic_last_name', data['last_name'] ?? '');
          await prefs.setString('active_panic_address', data['address'] ?? 'Location Unknown');

          if (mounted) {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const PanicInterruptScreen(),
              ),
            );
            _isInterruptShowing = false;
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(homeShellIndexProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        body: IndexedStack(
          index: currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: CustomBottomNavBar(
          currentIndex: currentIndex,
          onTap: (index) {
            ref.read(homeShellIndexProvider.notifier).state = index;
          },
        ),
      ),
    );
  }
}
