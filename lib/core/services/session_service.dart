import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:go_router/go_router.dart';
import 'router.dart';

class SessionService {
  static StreamSubscription<DocumentSnapshot>? _sessionSub;
  static bool _isInvalidating = false;
  static const String _prefKey = 'current_session_token';

  /// Generates a new UUID v4 token on successful sign-in / OTP verification,
  /// writes it to Firestore under `active_session_token` via a transaction,
  /// and saves it locally in SharedPreferences.
  static Future<void> createSessionOnSignIn(String uid) async {
    try {
      final newToken = const Uuid().v4();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, newToken);

      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(userRef);
        if (snap.exists) {
          tx.update(userRef, {'active_session_token': newToken});
        } else {
          tx.set(userRef, {'active_session_token': newToken}, SetOptions(merge: true));
        }
      });

      debugPrint("SingleDeviceSession: Created new session token for $uid -> $newToken");
    } catch (e) {
      debugPrint("SingleDeviceSession: Error creating session token: $e");
    }
  }

  /// Listens to real-time changes on the current user's document for `active_session_token`.
  /// If the token changes to a different value, triggers immediate logout flow.
  static void listenToSession(WidgetRef ref, String uid) {
    _sessionSub?.cancel();
    _isInvalidating = false;

    _sessionSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snap) async {
      if (!snap.exists || _isInvalidating) return;

      final data = snap.data() as Map<String, dynamic>?;
      if (data == null) return;

      final remoteToken = data['active_session_token'] as String?;
      if (remoteToken == null || remoteToken.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final localToken = prefs.getString(_prefKey);

      // If local token exists and remote token differs -> logged in on another device
      if (localToken != null && localToken.isNotEmpty && remoteToken != localToken) {
        debugPrint("SingleDeviceSession: Remote token ($remoteToken) != Local token ($localToken). Invalidating session!");
        await handleSessionInvalidated(ref);
      }
    });
  }

  /// App lifecycle resume check: performs a one-time get on the user document
  /// when returning from background.
  static Future<void> checkSessionOnResume(WidgetRef ref) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _isInvalidating) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final localToken = prefs.getString(_prefKey);
      if (localToken == null || localToken.isEmpty) return;

      final snap = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      if (!snap.exists) return;

      final remoteToken = snap.data()?['active_session_token'] as String?;
      if (remoteToken != null && remoteToken.isNotEmpty && remoteToken != localToken) {
        debugPrint("SingleDeviceSession: Resume check failed. Remote ($remoteToken) != Local ($localToken). Invalidating session!");
        await handleSessionInvalidated(ref);
      }
    } catch (e) {
      debugPrint("SingleDeviceSession: Error during resume session check: $e");
    }
  }

  /// Performs the invalidation flow when account is accessed on another device.
  static Future<void> handleSessionInvalidated(WidgetRef ref) async {
    if (_isInvalidating) return;
    _isInvalidating = true;

    _sessionSub?.cancel();
    _sessionSub = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);

    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint("Error during signOut: $e");
    }

    // Invalidate riverpod states
    ref.invalidate(routerProvider);

    final context = rootNavigatorKey.currentContext;
    if (context != null && context.mounted) {
      // Navigate to login screen
      GoRouter.of(context).go('/login');

      // Display signed out notification dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
              SizedBox(width: 8),
              Text(
                "Signed Out",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: const Text(
            "You have been signed out because your account was accessed on another device.",
            style: TextStyle(fontSize: 14, color: Color(0xFF374151)),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  /// Cleans up session token on intentional manual sign-out.
  static Future<void> clearSessionOnSignOut(String uid) async {
    _sessionSub?.cancel();
    _sessionSub = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'active_session_token': '',
      });
    } catch (e) {
      debugPrint("Error clearing active_session_token in Firestore: $e");
    }

    await FirebaseAuth.instance.signOut();
  }
}
