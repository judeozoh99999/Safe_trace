import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:async/async.dart';

final trustedContactsCountProvider = StreamProvider<int>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return Stream.value(0);
  }

  final controller = StreamController<int>();

  // 1. User document stream (for denormalized accepted_contacts_count field)
  final userDocStream = FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots();

  // 2. Collection streams fallback
  final reqStream = FirebaseFirestore.instance
      .collection('trusted_circle_requests')
      .where('requester_uid', isEqualTo: user.uid)
      .where('status', isEqualTo: 'accepted')
      .snapshots();

  final recStream = FirebaseFirestore.instance
      .collection('trusted_circle_requests')
      .where('recipient_uid', isEqualTo: user.uid)
      .where('status', isEqualTo: 'accepted')
      .snapshots();

  final zipStream = StreamZip([reqStream, recStream]);

  StreamSubscription? userSub;
  StreamSubscription? zipSub;

  userSub = userDocStream.listen((userSnap) {
    if (userSnap.exists) {
      final data = userSnap.data();
      if (data != null && data.containsKey('accepted_contacts_count') && data['accepted_contacts_count'] != null) {
        final count = (data['accepted_contacts_count'] as num).toInt();
        if (!controller.isClosed) {
          controller.add(count < 0 ? 0 : count);
        }
        return;
      }
    }
  }, onError: (_) {});

  zipSub = zipStream.listen((events) {
    final reqSnap = events[0];
    final recSnap = events[1];

    final uniqueDocIds = <String>{};
    for (final doc in reqSnap.docs) {
      uniqueDocIds.add(doc.id);
    }
    for (final doc in recSnap.docs) {
      uniqueDocIds.add(doc.id);
    }

    if (!controller.isClosed) {
      controller.add(uniqueDocIds.length);
    }
  }, onError: (err) {
    if (!controller.isClosed) {
      controller.addError(err);
    }
  });

  ref.onDispose(() {
    userSub?.cancel();
    zipSub?.cancel();
    controller.close();
  });

  return controller.stream;
});
