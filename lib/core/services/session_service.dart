import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:go_router/go_router.dart';
import 'router.dart';

class SessionService {
  static StreamSubscription<DocumentSnapshot>? _sessionSub;
  static bool _isInvalidating = false;
  static Timer? _debounceTimer;
  static const String _prefKey = 'current_session_token';

  // Android Keystore backed secure storage that survives process kills
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  /// Helper to read session token from secure storage with SharedPreferences fallback
  static Future<String?> _readLocalToken() async {
    try {
      final token = await _secureStorage.read(key: _prefKey);
      if (token != null && token.isNotEmpty) return token;
    } catch (e) {
      debugPrint("SessionService: SecureStorage read error: $e");
    }

    // Fallback to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefKey);
    } catch (e) {
      debugPrint("SessionService: SharedPreferences read error: $e");
      return null;
    }
  }

  /// Helper to write session token to both secure storage and SharedPreferences
  static Future<void> _writeLocalToken(String token) async {
    try {
      await _secureStorage.write(key: _prefKey, value: token);
    } catch (e) {
      debugPrint("SessionService: SecureStorage write error: $e");
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, token);
    } catch (e) {
      debugPrint("SessionService: SharedPreferences write error: $e");
    }
  }

  /// Helper to delete session token from both storage mediums
  static Future<void> _deleteLocalToken() async {
    try {
      await _secureStorage.delete(key: _prefKey);
    } catch (e) {
      debugPrint("SessionService: SecureStorage delete error: $e");
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey);
    } catch (e) {
      debugPrint("SessionService: SharedPreferences remove error: $e");
    }
  }

  /// Generates a new UUID v4 token on successful sign-in / OTP verification,
  /// writes it to Firestore under `active_session_token` via a transaction,
  /// and saves it locally in secure storage.
  static Future<void> createSessionOnSignIn(String uid) async {
    try {
      final newToken = const Uuid().v4();
      await _writeLocalToken(newToken);

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
  /// Implements 3-second debounce and self-healing for aggressive Android ROM restarts.
  static void listenToSession(WidgetRef ref, String uid) {
    _sessionSub?.cancel();
    _debounceTimer?.cancel();
    _isInvalidating = false;

    _sessionSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snap) async {
      if (!snap.exists || _isInvalidating) return;

      final data = snap.data();
      if (data == null) return;

      final remoteToken = data['active_session_token'] as String?;
      if (remoteToken == null || remoteToken.isEmpty) return;

      final localToken = await _readLocalToken();

      // Case 1: Local token is null or empty.
      // On aggressive ROMs (Vivo/Infinix), process kills can cause local storage read to return null
      // while the keystore is reconnecting. DO NOT SIGN OUT.
      // Self-heal by confirming currentUser UID and resynchronising local storage.
      if (localToken == null || localToken.isEmpty) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null && currentUser.uid == uid) {
          debugPrint("SingleDeviceSession: Local token was empty on listener trigger. Self-healing with remote token: $remoteToken");
          await _writeLocalToken(remoteToken);
        }
        return;
      }

      // Case 2: Remote token differs from local token -> Potential login on another device.
      // Add a 3-second debounce to handle race conditions during app resume.
      if (remoteToken != localToken) {
        debugPrint("SingleDeviceSession: Detected token mismatch (Local: $localToken, Remote: $remoteToken). Debouncing 3s before signout...");
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(seconds: 3), () async {
          if (_isInvalidating) return;

          // Re-verify after debounce
          final freshLocal = await _readLocalToken();
          final freshSnap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          final freshRemote = freshSnap.data()?['active_session_token'] as String?;

          if (freshLocal != null && freshRemote != null && freshLocal.isNotEmpty && freshLocal != freshRemote) {
            debugPrint("SingleDeviceSession: Confirmed token mismatch after 3s debounce. Remote ($freshRemote) != Local ($freshLocal). Invalidating session!");
            await handleSessionInvalidated(ref);
          } else {
            debugPrint("SingleDeviceSession: Debounce resolved or self-healed. Cancellation of signout.");
          }
        });
      } else {
        // Tokens match -> cancel any pending debounce
        _debounceTimer?.cancel();
      }
    });
  }

  /// App lifecycle resume check: performs a one-time get on the user document
  /// when returning from background and self-heals if needed.
  static Future<void> checkSessionOnResume(WidgetRef ref) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _isInvalidating) return;

    try {
      final localToken = await _readLocalToken();
      final snap = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      if (!snap.exists) return;

      final remoteToken = snap.data()?['active_session_token'] as String?;

      // If local token is null or empty, self-heal with remote token
      if (localToken == null || localToken.isEmpty) {
        if (remoteToken != null && remoteToken.isNotEmpty) {
          debugPrint("SingleDeviceSession: Resume check found empty local token. Self-healing with remote token: $remoteToken");
          await _writeLocalToken(remoteToken);
        } else {
          // Both null: regenerate a new token and update both
          final newToken = const Uuid().v4();
          await _writeLocalToken(newToken);
          await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
            'active_session_token': newToken,
          });
          debugPrint("SingleDeviceSession: Resume check regenerated missing tokens: $newToken");
        }
        return;
      }

      // If both present and mismatch, verify
      if (remoteToken != null && remoteToken.isNotEmpty && remoteToken != localToken) {
        debugPrint("SingleDeviceSession: Resume check mismatch (Remote: $remoteToken, Local: $localToken). Waiting 3s...");
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(seconds: 3), () async {
          final freshLocal = await _readLocalToken();
          final freshSnap = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
          final freshRemote = freshSnap.data()?['active_session_token'] as String?;
          if (freshLocal != null && freshRemote != null && freshLocal.isNotEmpty && freshLocal != freshRemote) {
            debugPrint("SingleDeviceSession: Confirmed mismatch on resume. Signing out.");
            await handleSessionInvalidated(ref);
          }
        });
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
    _debounceTimer?.cancel();
    _debounceTimer = null;

    await _deleteLocalToken();

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
    _debounceTimer?.cancel();
    _debounceTimer = null;

    await _deleteLocalToken();

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
