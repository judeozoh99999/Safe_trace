import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/enter_details_screen.dart';
import '../../features/auth/screens/verify_email_screen.dart';
import '../../features/auth/screens/place_alerts_screen.dart';
import '../../features/auth/screens/welcome_back_screen.dart';
import '../../features/contacts/screens/contacts_setup_screen.dart';
import '../../features/home_shell.dart';
import '../../features/location/screens/notifications_screen.dart';
import '../../features/profile/screens/safetrace_plus_screen.dart';
import '../../features/location/screens/add_connection_screen.dart';
import '../../features/auth/providers/auth_provider.dart';

import '../../features/panic/screens/panic_interrupt_screen.dart';
import '../../features/panic/screens/panic_map_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authStatusNotifierProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    refreshListenable: authNotifier,
    initialLocation: '/',
    redirect: (context, state) {
      final status = authNotifier.status;
      final isLoggingIn = state.matchedLocation == '/login' ||
          state.matchedLocation == '/onboarding' ||
          state.matchedLocation == '/enter-details' ||
          state.matchedLocation == '/verify-email' ||
          state.matchedLocation == '/' ||
          state.matchedLocation == '/welcome-back' ||
          state.matchedLocation == '/welcome-back-user';

      if (status == AuthStatus.loading) {
        // Never redirect while Auth state is still loading / restoring from disk
        return null;
      }

      if (status == AuthStatus.unauthenticated) {
        // If not authenticated, redirect to /login unless already navigating login/onboarding flow
        if (!isLoggingIn) {
          return '/login';
        }
      } else if (status == AuthStatus.authenticated) {
        // If authenticated, redirect away from splash/login/onboarding to /home
        if (isLoggingIn) {
          return '/home';
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/enter-details',
        builder: (context, state) => const EnterDetailsScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: '/place-alerts',
        builder: (context, state) => const PlaceAlertsScreen(),
      ),
      GoRoute(
        path: '/welcome-back',
        builder: (context, state) => const WelcomeBackScreen(),
      ),
      GoRoute(
        path: '/contacts-setup',
        builder: (context, state) => const ContactsSetupScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeShell(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/safetrace-plus',
        builder: (context, state) => const SafeTracePlusScreen(),
      ),
      GoRoute(
        path: '/add-connection',
        builder: (context, state) => const AddConnectionScreen(),
      ),
      GoRoute(
        path: '/panic-interrupt',
        builder: (context, state) => const PanicInterruptScreen(),
      ),
      GoRoute(
        path: '/panic-map/:victimUid',
        builder: (context, state) {
          final victimUid = state.pathParameters['victimUid']!;
          return PanicMapScreen(victimUid: victimUid);
        },
      ),
    ],
  );
});
