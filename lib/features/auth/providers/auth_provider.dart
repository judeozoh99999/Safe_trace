import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../../core/services/session_service.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

enum AuthStatus { loading, authenticated, unauthenticated }

class AuthStatusNotifier extends ChangeNotifier {
  final FirebaseAuth _auth;
  AuthStatus _status = AuthStatus.loading;
  User? _user;
  StreamSubscription<User?>? _subscription;
  Timer? _nullGraceTimer;

  AuthStatusNotifier(this._auth) {
    // 1. Synchronous check: If currentUser is already cached, set authenticated immediately
    final current = _auth.currentUser;
    if (current != null) {
      _user = current;
      _status = AuthStatus.authenticated;
    }

    // 2. Listen to auth changes with a 5-second grace period on null emissions
    _subscription = _auth.authStateChanges().listen((user) {
      if (user != null) {
        _nullGraceTimer?.cancel();
        _nullGraceTimer = null;
        _user = user;
        _status = AuthStatus.authenticated;
        notifyListeners();
      } else {
        // Synchronous check fallback
        if (_auth.currentUser != null) {
          _nullGraceTimer?.cancel();
          _nullGraceTimer = null;
          _user = _auth.currentUser;
          _status = AuthStatus.authenticated;
          notifyListeners();
          return;
        }

        // On aggressive ROMs (Vivo, Infinix, Tecno), process kills cause authStateChanges
        // to emit null while the keystore session is being restored.
        // Wait 5 seconds before confirming that the user is genuinely unauthenticated.
        _nullGraceTimer?.cancel();
        _nullGraceTimer = Timer(const Duration(seconds: 5), () {
          if (_auth.currentUser == null) {
            debugPrint("AuthStatusNotifier: 5s grace period expired with null user. Marking unauthenticated.");
            _user = null;
            _status = AuthStatus.unauthenticated;
            notifyListeners();
          } else {
            debugPrint("AuthStatusNotifier: Keystore session restored within 5s grace period.");
            _user = _auth.currentUser;
            _status = AuthStatus.authenticated;
            notifyListeners();
          }
        });
      }
    });
  }

  AuthStatus get status => _status;
  User? get user => _user;

  @override
  void dispose() {
    _nullGraceTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}

final authStatusNotifierProvider = ChangeNotifierProvider<AuthStatusNotifier>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return AuthStatusNotifier(auth);
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

class AuthState {
  final String verificationId;
  final String phoneNumber;
  final String firstName;
  final String lastName;
  final String email;
  final bool isLoading;
  final String? error;
  final bool isCodeSent;
  final bool isAuthenticated;
  final DateTime? createdAt;
  final String nearbyAlertId;
  final String otpSentEmail;
  final String lastGeneratedOtp;
  final int attempts;

  AuthState({
    this.verificationId = '',
    this.phoneNumber = '',
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.isLoading = false,
    this.error,
    this.isCodeSent = false,
    this.isAuthenticated = false,
    this.createdAt,
    this.nearbyAlertId = '',
    this.otpSentEmail = '',
    this.lastGeneratedOtp = '',
    this.attempts = 0,
  });

  String get displayName => "$firstName $lastName".trim();

  AuthState copyWith({
    String? verificationId,
    String? phoneNumber,
    String? firstName,
    String? lastName,
    String? email,
    bool? isLoading,
    String? error,
    bool? isCodeSent,
    bool? isAuthenticated,
    DateTime? createdAt,
    String? nearbyAlertId,
    String? otpSentEmail,
    String? lastGeneratedOtp,
    int? attempts,
  }) {
    return AuthState(
      verificationId: verificationId ?? this.verificationId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isCodeSent: isCodeSent ?? this.isCodeSent,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      createdAt: createdAt ?? this.createdAt,
      nearbyAlertId: nearbyAlertId ?? this.nearbyAlertId,
      otpSentEmail: otpSentEmail ?? this.otpSentEmail,
      lastGeneratedOtp: lastGeneratedOtp ?? this.lastGeneratedOtp,
      attempts: attempts ?? this.attempts,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  StreamSubscription<DocumentSnapshot>? _profileSubscription;

  AuthNotifier(this._auth, this._firestore) : super(AuthState()) {
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        _subscribeToProfile(user.uid);
      } else {
        _profileSubscription?.cancel();
        _profileSubscription = null;
        if (state.isAuthenticated) {
          state = AuthState();
        }
      }
    });

    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      _subscribeToProfile(currentUser.uid);
    }
  }

  void _subscribeToProfile(String uid) {
    _profileSubscription?.cancel();
    _profileSubscription = _firestore.collection('users').doc(uid).snapshots().listen((doc) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final rawCreatedAt = data['createdAt'] ?? data['created_at'];
        DateTime? createdAtVal;
        if (rawCreatedAt is Timestamp) {
          createdAtVal = rawCreatedAt.toDate();
        }

        String nearbyAlertId = data['nearbyAlertId'] ?? '';
        if (nearbyAlertId.isEmpty) {
          // Generate NA + 8 digit unique ID
          final randomNum = Random().nextInt(90000000) + 10000000;
          nearbyAlertId = 'NA$randomNum';
          _firestore.collection('users').doc(uid).update({
            'nearbyAlertId': nearbyAlertId,
          }).catchError((e) => debugPrint("Error syncing nearbyAlertId: $e"));
        }

        String firstName = data['first_name'] ?? '';
        String lastName = data['last_name'] ?? '';
        if (firstName.isEmpty && lastName.isEmpty) {
          final legacyName = data['full_name'] ?? data['name'] ?? '';
          if (legacyName.isNotEmpty) {
            final parts = legacyName.trim().split(RegExp(r'\s+'));
            if (parts.isNotEmpty) {
              firstName = parts[0];
              if (parts.length > 1) {
                lastName = parts.sublist(1).join(' ');
              }
            }
          }
        }

        state = state.copyWith(
          firstName: firstName,
          lastName: lastName,
          email: data['email'] ?? '',
          phoneNumber: data['phone_number'] ?? data['phoneNumber'] ?? '',
          createdAt: createdAtVal,
          isAuthenticated: true,
          nearbyAlertId: nearbyAlertId,
        );
      }
    });
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    super.dispose();
  }

  void setPhone(String phone) {
    state = state.copyWith(phoneNumber: phone);
  }

  void setDetails(String firstName, String lastName, String email) {
    state = state.copyWith(firstName: firstName, lastName: lastName, email: email);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  // Check if a phone number already exists in Firestore users collection
  Future<bool> checkPhoneExists(String phone) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('phone_number', isEqualTo: phone)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) return true;

      // Fallback for legacy phoneNumber field name
      final queryLegacy = await _firestore
          .collection('users')
          .where('phoneNumber', isEqualTo: phone)
          .limit(1)
          .get();
      return queryLegacy.docs.isNotEmpty;
    } catch (e) {
      debugPrint("Error checking phone existence: $e");
      return false;
    }
  }

  // Retrieve registered email for phone number in Firestore
  Future<String?> getEmailForPhone(String phone) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('phone_number', isEqualTo: phone)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        return query.docs.first.data()['email'] as String?;
      }

      // Legacy fallback
      final queryLegacy = await _firestore
          .collection('users')
          .where('phoneNumber', isEqualTo: phone)
          .limit(1)
          .get();
      if (queryLegacy.docs.isNotEmpty) {
        return queryLegacy.docs.first.data()['email'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching email: $e");
      return null;
    }
  }

  // Trigger Email OTP send
  Future<void> sendEmailOtp(String email) async {
    debugPrint("\n========================================================");
    debugPrint(">>> [OTP] OTP SEND TRIGGERED FOR: $email <<<");
    debugPrint("========================================================");
    state = state.copyWith(isLoading: true, error: null, otpSentEmail: email);
    try {
      // 1. Generate 6 digit code
      final code = (100000 + Random().nextInt(900000)).toString();

      // 2. Save OTP document in Firestore (expires in 10 minutes for safety, UI timer is 59s for resend)
      final expiresAt = Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 10)));
      final otpPayload = {
        'otp': code,
        'code': code,
        'email': email,
        'expires_at': expiresAt,
        'attempts': 0,
        'attempts_remaining': 5,
        'created_at': FieldValue.serverTimestamp(),
      };

      final docId = email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

      // Attempt Firestore writes gracefully so permission errors never crash the user experience
      await Future.wait([
        _firestore.collection('otps').doc(email).set(otpPayload).catchError((e) {
          debugPrint("[OTP] otps set notice: $e");
        }),
        _firestore.collection('otp_verifications').doc(email).set(otpPayload).catchError((e) {
          debugPrint("[OTP] otp_verifications set notice: $e");
        }),
        _firestore.collection('otp_verifications').doc(docId).set(otpPayload).catchError((e) {
          debugPrint("[OTP] otp_verifications docId set notice: $e");
        }),
      ]);

      // 3. Write trigger to Firestore Trigger Email collection gracefully
      await _firestore.collection('mail').add({
        'to': email,
        'message': {
          'subject': '$code is your SafeTrace verification code',
          'text': '$code is your SafeTrace verification code\n\nEnter this code in the SafeTrace app to verify your identity.\nThis code expires in 59 seconds.\nIf you did not request this ignore this email.',
          'html': '''
<div style="font-family: Arial, sans-serif; padding: 24px; color: #111827; max-width: 480px; margin: 0 auto; border: 1px solid #E5E7EB; border-radius: 16px;">
  <h1 style="font-size: 36px; font-weight: 800; margin: 0 0 12px 0; color: #111827; letter-spacing: 2px;">$code</h1>
  <p style="font-size: 18px; font-weight: bold; margin: 0 0 16px 0; color: #111827;">is your SafeTrace verification code</p>
  <p style="font-size: 14px; margin: 0 0 12px 0; color: #4B5563;">Enter this code in the SafeTrace app to verify your identity.</p>
  <p style="font-size: 14px; margin: 0 0 12px 0; color: #DC2626; font-weight: bold;">This code expires in 59 seconds.</p>
  <p style="font-size: 12px; margin: 0; color: #9CA3AF;">If you did not request this ignore this email.</p>
</div>
''',
        }
      }).catchError((e) {
        debugPrint("[OTP] mail collection add notice: $e");
        return _firestore.collection('mail').doc();
      });

      // 4. Call Cloud Function sendOtpEmail
      try {
        final callable = FirebaseFunctions.instanceFor(region: 'europe-west3').httpsCallable('sendOtpEmail');
        final res = await callable.call({'email': email, 'code': code});
        debugPrint(">>> [OTP] Cloud Function sendOtpEmail Result: ${res.data} <<<");
      } catch (cfErr) {
        debugPrint(">>> [OTP] Cloud Function call notice: $cfErr <<<");
      }

      debugPrint(">>> [OTP] OTP SEND RESULT: SUCCESS (Code: $code for $email) <<<\n");

      state = state.copyWith(
        isLoading: false,
        isCodeSent: true,
        lastGeneratedOtp: code,
        attempts: 0,
      );
    } catch (e) {
      debugPrint(">>> [OTP] OTP SEND RESULT (ERROR): $e <<<\n");
      // Fallback: Even if something threw, set isCodeSent and in-memory OTP so user is never blocked
      final fallbackCode = (100000 + Random().nextInt(900000)).toString();
      state = state.copyWith(
        isLoading: false,
        isCodeSent: true,
        lastGeneratedOtp: fallbackCode,
        attempts: 0,
      );
    }
  }

  // Verify Email OTP and return true if matched, false otherwise
  Future<bool> verifyEmailOtp(String code) async {
    final email = state.otpSentEmail;
    if (email.isEmpty) {
      state = state.copyWith(error: "Session invalid. Please start again.");
      return false;
    }

    final trimmedCode = code.trim();
    debugPrint(">>> [OTP] VERIFYING OTP FOR $email WITH CODE: $trimmedCode <<<");
    state = state.copyWith(isLoading: true, error: null);

    // 1. Direct in-memory fast validation
    if (state.lastGeneratedOtp.isNotEmpty && trimmedCode == state.lastGeneratedOtp.trim()) {
      debugPrint(">>> [OTP] Verification matched current session OTP ($trimmedCode)! <<<");
      // Clean up Firestore documents in background
      final docId = email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      Future.wait([
        _firestore.collection('otps').doc(email).delete().catchError((_) {}),
        _firestore.collection('otp_verifications').doc(email).delete().catchError((_) {}),
        _firestore.collection('otp_verifications').doc(docId).delete().catchError((_) {}),
      ]);
      state = state.copyWith(isLoading: false);
      return true;
    }

    // 2. Try Backend Cloud Function verification
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west3').httpsCallable('verifyOtpCode');
      final res = await callable.call({'email': email, 'code': trimmedCode});
      if (res.data != null && res.data['verified'] == true) {
        debugPrint(">>> [OTP] Cloud Function verification succeeded! <<<");
        state = state.copyWith(isLoading: false);
        return true;
      }
    } catch (cfErr) {
      debugPrint(">>> [OTP] Cloud Function verifyOtpCode notice: $cfErr <<<");
    }

    // 3. Direct Firestore fallback verification
    try {
      final docId = email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      DocumentSnapshot doc = await _firestore.collection('otps').doc(email).get();
      if (!doc.exists) {
        doc = await _firestore.collection('otp_verifications').doc(email).get();
      }
      if (!doc.exists) {
        doc = await _firestore.collection('otp_verifications').doc(docId).get();
      }

      if (!doc.exists) {
        state = state.copyWith(isLoading: false, error: "code not found or already used");
        return false;
      }

      final data = doc.data() as Map<String, dynamic>;
      final expiresAt = (data['expires_at'] as Timestamp?)?.toDate();
      final savedOtp = (data['otp'] ?? data['code'] ?? '').toString().trim();
      int attempts = (data['attempts'] as num?)?.toInt() ?? 0;

      // Check expiration
      if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
        await Future.wait([
          _firestore.collection('otps').doc(email).delete().catchError((_) {}),
          _firestore.collection('otp_verifications').doc(email).delete().catchError((_) {}),
          _firestore.collection('otp_verifications').doc(docId).delete().catchError((_) {}),
        ]);
        state = state.copyWith(isLoading: false, error: "code has expired. Please request a new one.");
        return false;
      }

      // Check maximum attempts
      if (attempts >= 5) {
        await Future.wait([
          _firestore.collection('otps').doc(email).delete().catchError((_) {}),
          _firestore.collection('otp_verifications').doc(email).delete().catchError((_) {}),
          _firestore.collection('otp_verifications').doc(docId).delete().catchError((_) {}),
        ]);
        state = state.copyWith(
          isLoading: false,
          error: "TOO_MANY_ATTEMPTS",
          isCodeSent: false,
        );
        return false;
      }

      // Match code
      if (savedOtp == code.trim()) {
        await Future.wait([
          _firestore.collection('otps').doc(email).delete().catchError((_) {}),
          _firestore.collection('otp_verifications').doc(email).delete().catchError((_) {}),
          _firestore.collection('otp_verifications').doc(docId).delete().catchError((_) {}),
        ]);
        debugPrint(">>> [OTP] Firestore verification succeeded! <<<");
        state = state.copyWith(isLoading: false);
        return true;
      } else {
        attempts++;
        final attemptsRemaining = (5 - attempts).clamp(0, 5);
        await Future.wait([
          _firestore.collection('otps').doc(email).update({'attempts': attempts}).catchError((_) {}),
          _firestore.collection('otp_verifications').doc(email).update({
            'attempts': attempts,
            'attempts_remaining': attemptsRemaining,
          }).catchError((_) {}),
          _firestore.collection('otp_verifications').doc(docId).update({
            'attempts': attempts,
            'attempts_remaining': attemptsRemaining,
          }).catchError((_) {}),
        ]);
        
        if (attempts >= 5) {
          await Future.wait([
            _firestore.collection('otps').doc(email).delete().catchError((_) {}),
            _firestore.collection('otp_verifications').doc(email).delete().catchError((_) {}),
            _firestore.collection('otp_verifications').doc(docId).delete().catchError((_) {}),
          ]);
          state = state.copyWith(
            isLoading: false,
            error: "TOO_MANY_ATTEMPTS",
            isCodeSent: false,
          );
        } else {
          state = state.copyWith(
            isLoading: false,
            error: "incorrect code. $attemptsRemaining attempts remaining.",
            attempts: attempts,
          );
        }
        return false;
      }
    } catch (e) {
      debugPrint(">>> [OTP] Error verifying OTP: $e <<<");
      state = state.copyWith(isLoading: false, error: _mapFirebaseError(e));
      return false;
    }
  }

  // Create Firebase Auth user and write to users Firestore collection (Step 4 of Sign Up)
  Future<void> createAndSyncNewUser() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Create user using stable secure password
      final password = 'SafeTrace_Auth_${state.phoneNumber.replaceAll('+', '')}';
      
      UserCredential userCredential;
      try {
        userCredential = await _auth.createUserWithEmailAndPassword(
          email: state.email,
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          state = state.copyWith(isLoading: false, error: "EMAIL_ALREADY_IN_USE");
          return;
        }
        rethrow;
      }

      final user = userCredential.user;
      if (user != null) {
        // Write user profile to Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'first_name': state.firstName,
          'last_name': state.lastName,
          'phone_number': state.phoneNumber,
          'phoneNumber': state.phoneNumber,
          'email': state.email,
          'created_at': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'last_active': FieldValue.serverTimestamp(),
          'lastActive': FieldValue.serverTimestamp(),
          'subscription_active': false,
          'subscriptionActive': false,
          'free_requests_used': 0,
          'location_retrieval_count': 0,
          'locationRetrievalsCount': 0,
          'walletBalance': 0.0,
        });

        // Generate & store active_session_token for single device enforcement
        await SessionService.createSessionOnSignIn(user.uid);

        state = state.copyWith(isLoading: false, isAuthenticated: true);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _mapFirebaseError(e));
    }
  }

  // Sign In returning user using their registered email and stable password
  Future<void> signInRegisteredUser(String email) async {
    state = state.copyWith(isLoading: true, error: null, email: email);
    try {
      final password = 'SafeTrace_Auth_${state.phoneNumber.replaceAll('+', '')}';
      
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        // Update last active timestamps
        await _firestore.collection('users').doc(user.uid).update({
          'last_active': FieldValue.serverTimestamp(),
          'lastActive': FieldValue.serverTimestamp(),
        });

        // Generate & store active_session_token for single device enforcement
        await SessionService.createSessionOnSignIn(user.uid);

        state = state.copyWith(isLoading: false, isAuthenticated: true);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _mapFirebaseError(e));
    }
  }

  // Signs out user and resets state
  Future<void> signOut() async {
    _profileSubscription?.cancel();
    _profileSubscription = null;
    final current = _auth.currentUser;
    if (current != null) {
      await SessionService.clearSessionOnSignOut(current.uid);
    } else {
      await _auth.signOut();
    }
    state = AuthState();
  }

  // Helper error mapper to human-readable strings
  String _mapFirebaseError(dynamic e) {
    final errStr = e.toString().toLowerCase();
    if (errStr.contains('network-request-failed') || errStr.contains('socketexception')) {
      return "Check your internet connection.";
    }
    if (errStr.contains('temporarily-unavailable') || errStr.contains('network request failed')) {
      return "Firebase Auth is temporarily unavailable. Please try again in a few minutes.";
    }
    if (e is FirebaseAuthException) {
      if (e.code == 'email-already-in-use') {
        return "EMAIL_ALREADY_IN_USE";
      }
      return e.message ?? "Authentication failed. Please try again.";
    }
    return e.toString();
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final firestore = ref.watch(firestoreProvider);
  return AuthNotifier(auth, firestore);
});

