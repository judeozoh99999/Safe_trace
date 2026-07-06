import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../shared/widgets/custom_bottom_nav_bar.dart';
import 'location/screens/home_screen.dart';
import 'route/screens/route_intel_screen.dart';
import 'community/screens/community_feed_screen.dart';
import 'sentinel/screens/watch_mode_screen.dart';
import 'profile/screens/profile_screen.dart';

final homeShellIndexProvider = StateProvider<int>((ref) => 0);

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  final List<Widget> _screens = const [
    HomeScreen(),
    RouteIntelScreen(),
    CommunityFeedScreen(),
    WatchModeScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(homeShellIndexProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
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
