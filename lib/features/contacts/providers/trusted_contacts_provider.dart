import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Structured data model containing all 3 categories of trusted circle contacts
class TrustedCircleData {
  final List<QueryDocumentSnapshot> activeCircle;
  final List<QueryDocumentSnapshot> pendingSent;
  final List<QueryDocumentSnapshot> incomingRequests;

  const TrustedCircleData({
    this.activeCircle = const [],
    this.pendingSent = const [],
    this.incomingRequests = const [],
  });

  bool get isEmpty => activeCircle.isEmpty && pendingSent.isEmpty && incomingRequests.isEmpty;
  int get activeCount => activeCircle.length;
  int get pendingCount => pendingSent.length;
  int get incomingCount => incomingRequests.length;
}

/// Robust StreamProvider for all Trusted Circle contacts & requests.
/// Merges two scoped Firestore queries (requester and recipient) with keepAlive
/// so data is never lost or prematurely reset across screen navigation.
final trustedCircleStreamProvider = StreamProvider<TrustedCircleData>((ref) {
  ref.keepAlive();

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    debugPrint('[TRUSTED_CIRCLE_PROVIDER] User is null -> emitting empty');
    return Stream.value(const TrustedCircleData());
  }

  final controller = StreamController<TrustedCircleData>();

  debugPrint('[TRUSTED_CIRCLE_PROVIDER] Subscribing to queries for user: ${user.uid}');

  // Query 1: Where current user is the requester
  final reqStream = FirebaseFirestore.instance
      .collection('trusted_circle_requests')
      .where('requester_uid', isEqualTo: user.uid)
      .snapshots();

  // Query 2: Where current user is the recipient
  final recStream = FirebaseFirestore.instance
      .collection('trusted_circle_requests')
      .where('recipient_uid', isEqualTo: user.uid)
      .snapshots();

  List<QueryDocumentSnapshot>? latestReqDocs;
  List<QueryDocumentSnapshot>? latestRecDocs;

  void emitMerged() {
    final docMap = <String, QueryDocumentSnapshot>{};
    for (final doc in latestReqDocs ?? <QueryDocumentSnapshot>[]) {
      docMap[doc.id] = doc;
    }
    for (final doc in latestRecDocs ?? <QueryDocumentSnapshot>[]) {
      docMap[doc.id] = doc;
    }

    final activeCircle = <QueryDocumentSnapshot>[];
    final pendingSent = <QueryDocumentSnapshot>[];
    final incomingRequests = <QueryDocumentSnapshot>[];

    for (final doc in docMap.values) {
      final data = doc.data() as Map<String, dynamic>;
      final reqUid = (data['requester_uid'] ?? '').toString();
      final recUid = (data['recipient_uid'] ?? '').toString();
      final status = (data['status'] ?? '').toString().toLowerCase().trim();

      debugPrint('[TRUSTED_CIRCLE_PROVIDER] Doc ${doc.id}: req=$reqUid, rec=$recUid, status=$status');

      if (reqUid != user.uid && recUid != user.uid) {
        debugPrint('[TRUSTED_CIRCLE_PROVIDER] Doc ${doc.id} filtered out (UID mismatch)');
        continue;
      }

      if (status == 'accepted' || status == 'pending_deletion') {
        activeCircle.add(doc);
      } else if (status == 'pending') {
        if (reqUid == user.uid) {
          pendingSent.add(doc);
        } else if (recUid == user.uid) {
          incomingRequests.add(doc);
        }
      }
    }

    debugPrint(
      '[TRUSTED_CIRCLE_PROVIDER] EMISSION -> '
      'Active: ${activeCircle.length}, '
      'Pending Sent: ${pendingSent.length}, '
      'Incoming: ${incomingRequests.length}',
    );

    if (!controller.isClosed) {
      controller.add(TrustedCircleData(
        activeCircle: activeCircle,
        pendingSent: pendingSent,
        incomingRequests: incomingRequests,
      ));
    }
  }

  final sub1 = reqStream.listen(
    (snap) {
      latestReqDocs = snap.docs;
      emitMerged();
    },
    onError: (err) {
      debugPrint('[TRUSTED_CIRCLE_PROVIDER] Error in reqStream: $err');
    },
  );

  final sub2 = recStream.listen(
    (snap) {
      latestRecDocs = snap.docs;
      emitMerged();
    },
    onError: (err) {
      debugPrint('[TRUSTED_CIRCLE_PROVIDER] Error in recStream: $err');
    },
  );

  ref.onDispose(() {
    sub1.cancel();
    sub2.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Count provider derived directly from trustedCircleStreamProvider or user doc
final trustedContactsCountProvider = StreamProvider<int>((ref) {
  ref.keepAlive();
  final circleAsync = ref.watch(trustedCircleStreamProvider);
  return Stream.value(circleAsync.valueOrNull?.activeCount ?? 0);
});

/// Data model representing an accepted trusted contact for panic alerts and UI indicators
class AcceptedTrustedContact {
  final String uid;
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String documentId;

  const AcceptedTrustedContact({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    this.documentId = '',
  });

  String get fullName => '$firstName $lastName'.trim();
  String get name => fullName.isEmpty ? 'Trusted Contact' : fullName;
}

/// Normalise phone numbers to international +234 format without spaces, dashes, or brackets
String normalizePhoneNumber(String rawPhone) {
  String clean = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');
  if (clean.startsWith('0')) {
    clean = '+234${clean.substring(1)}';
  } else if (clean.startsWith('234')) {
    clean = '+$clean';
  } else if (!clean.startsWith('+') && clean.isNotEmpty) {
    clean = '+234$clean';
  }
  return clean;
}

/// Service providing single source of truth for accepted trusted contacts
class TrustedContactsService {
  /// Fetch all accepted trusted contacts for the given UID across both requester and recipient queries
  static Future<List<AcceptedTrustedContact>> getAcceptedTrustedContacts(String uid) async {
    if (uid.isEmpty) return [];

    try {
      // Query 1: where requester_uid equals current user and status is 'accepted'
      final q1 = await FirebaseFirestore.instance
          .collection('trusted_circle_requests')
          .where('requester_uid', isEqualTo: uid)
          .where('status', isEqualTo: 'accepted')
          .get();

      // Query 2: where recipient_uid equals current user and status is 'accepted'
      final q2 = await FirebaseFirestore.instance
          .collection('trusted_circle_requests')
          .where('recipient_uid', isEqualTo: uid)
          .where('status', isEqualTo: 'accepted')
          .get();

      final docMap = <String, QueryDocumentSnapshot>{};
      for (final doc in q1.docs) {
        docMap[doc.id] = doc;
      }
      for (final doc in q2.docs) {
        docMap[doc.id] = doc;
      }

      final List<AcceptedTrustedContact> contacts = [];
      for (final doc in docMap.values) {
        final data = doc.data() as Map<String, dynamic>;
        final reqUid = (data['requester_uid'] ?? '').toString();
        final recUid = (data['recipient_uid'] ?? '').toString();
        final status = (data['status'] ?? '').toString().toLowerCase().trim();

        if (status != 'accepted') continue;

        if (reqUid == uid && recUid.isNotEmpty) {
          final rawPhone = (data['recipient_phone'] ?? '').toString();
          contacts.add(AcceptedTrustedContact(
            uid: recUid,
            firstName: (data['recipient_first_name'] ?? '').toString().trim(),
            lastName: (data['recipient_last_name'] ?? '').toString().trim(),
            phoneNumber: normalizePhoneNumber(rawPhone),
            documentId: doc.id,
          ));
        } else if (recUid == uid && reqUid.isNotEmpty) {
          final rawPhone = (data['requester_phone'] ?? '').toString();
          contacts.add(AcceptedTrustedContact(
            uid: reqUid,
            firstName: (data['requester_first_name'] ?? '').toString().trim(),
            lastName: (data['requester_last_name'] ?? '').toString().trim(),
            phoneNumber: normalizePhoneNumber(rawPhone),
            documentId: doc.id,
          ));
        }
      }

      return contacts;
    } catch (e) {
      debugPrint('[TRUSTED_CONTACTS] Error in getAcceptedTrustedContacts: $e');
      return [];
    }
  }
}

/// Real-time stream provider for accepted trusted contacts (for home screen & panic readiness)
final acceptedTrustedContactsStreamProvider = StreamProvider<List<AcceptedTrustedContact>>((ref) {
  ref.keepAlive();
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return Stream.value(const []);
  }

  final controller = StreamController<List<AcceptedTrustedContact>>();

  final q1Stream = FirebaseFirestore.instance
      .collection('trusted_circle_requests')
      .where('requester_uid', isEqualTo: user.uid)
      .where('status', isEqualTo: 'accepted')
      .snapshots();

  final q2Stream = FirebaseFirestore.instance
      .collection('trusted_circle_requests')
      .where('recipient_uid', isEqualTo: user.uid)
      .where('status', isEqualTo: 'accepted')
      .snapshots();

  List<QueryDocumentSnapshot>? snap1Docs;
  List<QueryDocumentSnapshot>? snap2Docs;

  void emit() {
    final docMap = <String, QueryDocumentSnapshot>{};
    for (final doc in snap1Docs ?? <QueryDocumentSnapshot>[]) {
      docMap[doc.id] = doc;
    }
    for (final doc in snap2Docs ?? <QueryDocumentSnapshot>[]) {
      docMap[doc.id] = doc;
    }

    final contacts = <AcceptedTrustedContact>[];
    for (final doc in docMap.values) {
      final data = doc.data() as Map<String, dynamic>;
      final reqUid = (data['requester_uid'] ?? '').toString();
      final recUid = (data['recipient_uid'] ?? '').toString();
      final status = (data['status'] ?? '').toString().toLowerCase().trim();

      if (status != 'accepted') continue;

      if (reqUid == user.uid && recUid.isNotEmpty) {
        contacts.add(AcceptedTrustedContact(
          uid: recUid,
          firstName: (data['recipient_first_name'] ?? '').toString().trim(),
          lastName: (data['recipient_last_name'] ?? '').toString().trim(),
          phoneNumber: normalizePhoneNumber((data['recipient_phone'] ?? '').toString()),
          documentId: doc.id,
        ));
      } else if (recUid == user.uid && reqUid.isNotEmpty) {
        contacts.add(AcceptedTrustedContact(
          uid: reqUid,
          firstName: (data['requester_first_name'] ?? '').toString().trim(),
          lastName: (data['requester_last_name'] ?? '').toString().trim(),
          phoneNumber: normalizePhoneNumber((data['requester_phone'] ?? '').toString()),
          documentId: doc.id,
        ));
      }
    }

    if (!controller.isClosed) {
      controller.add(contacts);
    }
  }

  final s1 = q1Stream.listen((s) {
    snap1Docs = s.docs;
    emit();
  }, onError: (e) => debugPrint('[STREAM_ERR_Q1] $e'));

  final s2 = q2Stream.listen((s) {
    snap2Docs = s.docs;
    emit();
  }, onError: (e) => debugPrint('[STREAM_ERR_Q2] $e'));

  ref.onDispose(() {
    s1.cancel();
    s2.cancel();
    controller.close();
  });

  return controller.stream;
});

