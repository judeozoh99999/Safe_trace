import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../../auth/providers/auth_provider.dart';
import '../../location/providers/home_provider.dart';

class CommunityNoteModel {
  final String id;
  final double latitude;
  final double longitude;
  final String address;
  final String note;
  final String uid;
  final String firstName;
  final String lastName;
  final DateTime timestamp;
  final bool isVisible;

  CommunityNoteModel({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.note,
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.timestamp,
    required this.isVisible,
  });

  String get category => "Alert";
  String get severity => "Medium";
  String get location => address;
  String get noteText => note;

  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) {
      return "just now";
    } else if (diff.inMinutes < 60) {
      return "${diff.inMinutes} mins ago";
    } else if (diff.inHours < 24) {
      return "${diff.inHours} hours ago";
    } else {
      return "${diff.inDays} days ago";
    }
  }

  factory CommunityNoteModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    DateTime ts = DateTime.now();
    if (data['created_at'] != null) {
      if (data['created_at'] is Timestamp) {
        ts = (data['created_at'] as Timestamp).toDate();
      } else if (data['created_at'] is int) {
        ts = DateTime.fromMillisecondsSinceEpoch(data['created_at'] as int);
      }
    }
    return CommunityNoteModel(
      id: doc.id,
      latitude: double.tryParse(data['lat']?.toString() ?? '0.0') ?? 0.0,
      longitude: double.tryParse(data['lng']?.toString() ?? '0.0') ?? 0.0,
      address: data['address'] ?? '',
      note: data['note'] ?? '',
      uid: data['uid'] ?? '',
      firstName: data['first_name'] ?? data['firstName'] ?? '',
      lastName: data['last_name'] ?? data['lastName'] ?? '',
      timestamp: ts,
      isVisible: data['is_visible'] ?? true,
    );
  }
}

class CommunityState {
  final String activeFilter; // Kept for compatibility
  final List<CommunityNoteModel> notes;

  CommunityState({
    this.activeFilter = 'All',
    this.notes = const [],
  });

  CommunityState copyWith({
    String? activeFilter,
    List<CommunityNoteModel>? notes,
  }) {
    return CommunityState(
      activeFilter: activeFilter ?? this.activeFilter,
      notes: notes ?? this.notes,
    );
  }
}

class CommunityNotifier extends StateNotifier<CommunityState> {
  final Ref _ref;
  StreamSubscription<QuerySnapshot>? _subscription;

  CommunityNotifier(this._ref) : super(CommunityState()) {
    _subscribeToIncidents();
  }

  void _subscribeToIncidents() {
    _subscription?.cancel();
    
    // Subscribe to community_notes stream
    _subscription = _ref
        .read(firestoreProvider)
        .collection('community_notes')
        .where('is_visible', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      final allNotes = snapshot.docs.map((doc) {
        return CommunityNoteModel.fromFirestore(doc);
      }).toList();

      // Sort by timestamp descending
      allNotes.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      state = state.copyWith(notes: allNotes);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void setFilter(String filter) {
    state = state.copyWith(activeFilter: filter);
  }

  Future<void> addNote({
    required double lat,
    required double lng,
    required String address,
    required String note,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final uData = userDoc.data() ?? {};
    final fName = uData['first_name'] ?? '';
    final lName = uData['last_name'] ?? '';

    final id = DateTime.now().millisecondsSinceEpoch.toString();

    await _ref
        .read(firestoreProvider)
        .collection('community_notes')
        .doc(id)
        .set({
      'lat': lat,
      'lng': lng,
      'address': address,
      'note': note,
      'uid': user.uid,
      'first_name': fName,
      'last_name': lName,
      'created_at': FieldValue.serverTimestamp(),
      'is_visible': true,
    });
  }
}

final communityProvider = StateNotifierProvider<CommunityNotifier, CommunityState>((ref) {
  return CommunityNotifier(ref);
});
