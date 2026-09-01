import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:permission_handler/permission_handler.dart';
import 'firebase_options.dart';
import 'core/services/router.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables gracefully
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Warning: .env file not found or empty. Using default configurations.");
  }

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Set Firebase Auth Persistence to LOCAL explicitly for all Android versions
  try {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  } catch (e) {
    debugPrint("Warning setting Auth persistence: $e");
  }

  // Create test user "Director Martin" in the database
  try {
    final testUserDoc = FirebaseFirestore.instance.collection('users').doc('test_director_martin_uid');
    final doc = await testUserDoc.get();
    if (!doc.exists) {
      await testUserDoc.set({
        'uid': 'test_director_martin_uid',
        'name': 'Director Martin',
        'phoneNumber': '07067113490',
        'email': 'director.martin@safetrace.com',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  } catch (e) {
    debugPrint("Error creating test user: $e");
  }

  // Subscribe to auth state changes to inject "Director Martin" into current user's trusted contacts
  FirebaseAuth.instance.authStateChanges().listen((user) async {
    if (user != null) {
      try {
        final contactDoc = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('contacts')
            .doc('test_director_martin');
        final doc = await contactDoc.get();
        if (!doc.exists) {
          await contactDoc.set({
            'id': 'test_director_martin',
            'name': 'Director Martin',
            'phoneNumber': '07067113490',
            'avatarColorHex': Colors.indigo.value,
            'relationship': 'Family',
            'welfareCheck': true,
          });
        }
      } catch (e) {
        debugPrint("Error creating test contact: $e");
      }
    }
  });

  // Initialize FCM Notifications
  await NotificationService.initializeNotifications();

  // Request SMS permission once at startup on Android before home screen renders
  if (Platform.isAndroid) {
    try {
      final status = await Permission.sms.status;
      if (!status.isGranted) {
        await Permission.sms.request();
      }
    } catch (e) {
      debugPrint("Error requesting SMS permission at startup: $e");
    }
  }

  runApp(
    const ProviderScope(
      child: SafeTraceApp(),
    ),
  );
}

class SafeTraceApp extends ConsumerStatefulWidget {
  const SafeTraceApp({super.key});

  @override
  ConsumerState<SafeTraceApp> createState() => _SafeTraceAppState();
}

class _SafeTraceAppState extends ConsumerState<SafeTraceApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAuthToken();
    }
  }

  Future<void> _refreshAuthToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await user.getIdToken(true); // Force token refresh on foreground
      } on FirebaseAuthException catch (e) {
        debugPrint("Token refresh failed: ${e.code} - ${e.message}");
        if (e.code == 'user-not-found' || e.code == 'user-disabled' || e.code == 'invalid-user-token' || e.code == 'token-expired') {
          await FirebaseAuth.instance.signOut();
        }
      } catch (e) {
        debugPrint("Error refreshing auth token: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'SafeTrace',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
