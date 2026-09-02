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
