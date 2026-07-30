import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';

class ContactModel {
  final String id;
  final String uid;
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final Color avatarColor;
  final String relationship;
  final bool welfareCheck;
  final DateTime? addedAt;

  ContactModel({
    required this.id,
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    required this.avatarColor,
    required this.relationship,
    required this.welfareCheck,
    this.addedAt,
  });

  String get name {
    final fullName = "$firstName $lastName".trim();
    return fullName.isNotEmpty ? fullName : "Unknown User";
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'first_name': firstName,
      'firstName': firstName,
      'last_name': lastName,
      'lastName': lastName,
      'phone_number': phoneNumber,
      'phoneNumber': phoneNumber,
      'avatarColorHex': avatarColor.value,
      'relationship': relationship,
      'welfare_check_enabled': welfareCheck,
      'welfareCheck': welfareCheck,
      'added_at': addedAt != null ? Timestamp.fromDate(addedAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory ContactModel.fromMap(Map<String, dynamic> map, String docId) {
    final fName = map['first_name'] ?? map['firstName'] ?? '';
    final lName = map['last_name'] ?? map['lastName'] ?? '';
    final legacyName = map['name'] ?? '';
    final parts = legacyName.toString().split(' ');
    final resolvedFirstName = fName.toString().isNotEmpty 
        ? fName.toString() 
        : (parts.isNotEmpty ? parts.first : '');
    final resolvedLastName = lName.toString().isNotEmpty 
        ? lName.toString() 
        : (parts.length > 1 ? parts.sublist(1).join(' ') : '');

    return ContactModel(
      id: docId,
      uid: map['uid'] ?? map['id'] ?? docId,
      firstName: resolvedFirstName,
      lastName: resolvedLastName,
      phoneNumber: map['phone_number'] ?? map['phoneNumber'] ?? '',
      avatarColor: map['avatarColorHex'] != null 
          ? Color(map['avatarColorHex'] as int) 
          : AppColors.avatarPurple,
      relationship: map['relationship'] ?? 'Family',
      welfareCheck: map['welfare_check_enabled'] ?? map['welfareCheck'] ?? true,
      addedAt: map['added_at'] != null 
          ? (map['added_at'] as Timestamp).toDate()
          : (map['addedAt'] != null ? DateTime.tryParse(map['addedAt'].toString()) : null),
    );
  }
}

class ContactsNotifier extends StateNotifier<List<ContactModel>> {
  final Ref _ref;
  StreamSubscription<QuerySnapshot>? _subscription;

  ContactsNotifier(this._ref) : super([]) {
    _ref.read(firebaseAuthProvider).authStateChanges().listen((user) {
      if (user != null) {
        _subscribeToContacts(user.uid);
      } else {
        _unsubscribe();
        state = [];
      }
    });
  }

  void _subscribeToContacts(String uid) {
    _subscription?.cancel();
    _subscription = _ref
        .read(firestoreProvider)
        .collection('users')
        .doc(uid)
        .collection('contacts')
        .snapshots()
        .listen((snapshot) {
      state = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return ContactModel.fromMap(data, doc.id);
      }).toList();
    });
  }

  void _unsubscribe() {
    _subscription?.cancel();
    _subscription = null;
  }

  Future<void> addTrustedContact({
    required String contactUid,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String relationship,
    required bool welfareCheck,
  }) async {
    if (state.length >= 5) return;

    final user = _ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;

    final color = AppColors.avatarColors[state.length % AppColors.avatarColors.length];
    final newContact = ContactModel(
      id: contactUid,
      uid: contactUid,
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phoneNumber,
      avatarColor: color,
      relationship: relationship,
      welfareCheck: welfareCheck,
      addedAt: DateTime.now(),
    );

    await _ref
        .read(firestoreProvider)
        .collection('users')
        .doc(user.uid)
        .collection('contacts')
        .doc(contactUid)
        .set(newContact.toMap());
  }

  Future<void> addContact(
    String name,
    String phone, {
    String relationship = "Family",
    bool welfareCheck = true,
  }) async {
    if (state.length >= 5) return;

    final user = _ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;

    final color = AppColors.avatarColors[state.length % AppColors.avatarColors.length];
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    
    final parts = name.split(' ');
    final fName = parts.isNotEmpty ? parts.first : '';
    final lName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    final newContact = ContactModel(
      id: id,
      uid: id,
      firstName: fName,
      lastName: lName,
      phoneNumber: phone,
      avatarColor: color,
      relationship: relationship,
      welfareCheck: welfareCheck,
      addedAt: DateTime.now(),
    );

    await _ref
        .read(firestoreProvider)
        .collection('users')
        .doc(user.uid)
        .collection('contacts')
        .doc(id)
        .set(newContact.toMap());
  }

  Future<void> removeContact(String id) async {
    final user = _ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;

    await _ref
        .read(firestoreProvider)
        .collection('users')
        .doc(user.uid)
        .collection('contacts')
        .doc(id)
        .delete();
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }
}

final contactsProvider = StateNotifierProvider<ContactsNotifier, List<ContactModel>>((ref) {
  return ContactsNotifier(ref);
});
