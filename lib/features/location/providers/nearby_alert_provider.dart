import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';

// ─── Data Classes ────────────────────────────────────────────────────────────

class NearbyConnection {
  final String id;
  final String requesterUid;
  final String requesterName;
  final String requesterNearbyId;
  final String recipientUid;
  final String recipientName;
  final String recipientNearbyId;
  final String connectionType; // Personal, Venue, Responder
  final String status; // pending, active, expiring, expired, disconnected
  final DateTime createdAt;
  final DateTime? approvedAt;
  final DateTime? expiresAt;
  final double lastDistanceMetres;
  final double requesterLat;
  final double requesterLng;
  final double recipientLat;
  final double recipientLng;

  NearbyConnection({
    required this.id,
    required this.requesterUid,
    required this.requesterName,
    required this.requesterNearbyId,
    required this.recipientUid,
    required this.recipientName,
    required this.recipientNearbyId,
    required this.connectionType,
    required this.status,
    required this.createdAt,
    this.approvedAt,
    this.expiresAt,
    required this.lastDistanceMetres,
    required this.requesterLat,
    required this.requesterLng,
    required this.recipientLat,
    required this.recipientLng,
  });

  factory NearbyConnection.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NearbyConnection(
      id: doc.id,
      requesterUid: data['requester_uid'] ?? '',
      requesterName: data['requester_name'] ?? '',
      requesterNearbyId: data['requester_nearby_alert_id'] ?? '',
      recipientUid: data['recipient_uid'] ?? '',
      recipientName: data['recipient_name'] ?? '',
      recipientNearbyId: data['recipient_nearby_alert_id'] ?? '',
      connectionType: data['connection_type'] ?? 'Personal',
      status: data['status'] ?? 'pending',
      createdAt: data['created_at'] != null 
          ? (data['created_at'] as Timestamp).toDate()
          : DateTime.now(),
      approvedAt: data['approved_at'] != null 
          ? (data['approved_at'] as Timestamp).toDate()
          : null,
      expiresAt: data['expires_at'] != null 
          ? (data['expires_at'] as Timestamp).toDate()
          : null,
      lastDistanceMetres: double.tryParse(data['last_distance_metres']?.toString() ?? '0.0') ?? 0.0,
      requesterLat: double.tryParse(data['requester_lat']?.toString() ?? '0.0') ?? 0.0,
      requesterLng: double.tryParse(data['requester_lng']?.toString() ?? '0.0') ?? 0.0,
      recipientLat: double.tryParse(data['recipient_lat']?.toString() ?? '0.0') ?? 0.0,
      recipientLng: double.tryParse(data['recipient_lng']?.toString() ?? '0.0') ?? 0.0,
    );
  }
}

class NearbyAlertState {
  final String nearbyAlertId;
  final bool isSessionActive;
  final List<NearbyConnection> connections;
  final int activeCount;
  final int expiringCount;
  final int pendingCount;
  final int radius;

  NearbyAlertState({
    this.nearbyAlertId = '',
    this.isSessionActive = false,
    this.connections = const [],
    this.activeCount = 0,
    this.expiringCount = 0,
    this.pendingCount = 0,
    this.radius = 20,
  });

  NearbyAlertState copyWith({
    String? nearbyAlertId,
    bool? isSessionActive,
    List<NearbyConnection>? connections,
    int? activeCount,
    int? expiringCount,
    int? pendingCount,
    int? radius,
  }) {
    return NearbyAlertState(
      nearbyAlertId: nearbyAlertId ?? this.nearbyAlertId,
      isSessionActive: isSessionActive ?? this.isSessionActive,
      connections: connections ?? this.connections,
      activeCount: activeCount ?? this.activeCount,
      expiringCount: expiringCount ?? this.expiringCount,
      pendingCount: pendingCount ?? this.pendingCount,
      radius: radius ?? this.radius,
    );
  }
}

// ─── Riverpod Notifier ───────────────────────────────────────────────────────

class NearbyAlertNotifier extends AsyncNotifier<NearbyAlertState> {
  StreamSubscription<QuerySnapshot>? _connectionsSubscription;
  StreamSubscription<DocumentSnapshot>? _sessionSubscription;
  Timer? _locationUpdateTimer;

  @override
  FutureOr<NearbyAlertState> build() {
    ref.onDispose(() {
      _connectionsSubscription?.cancel();
      _sessionSubscription?.cancel();
      _locationUpdateTimer?.cancel();
    });
    return NearbyAlertState();
  }

  /// Initialize and query user ID
  Future<void> initializeNearbyAlert() async {
    state = const AsyncLoading();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      state = AsyncData(NearbyAlertState());
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      String alertId = '';

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        alertId = data['nearby_alert_id'] ?? data['nearbyAlertId'] ?? '';
      }

      if (alertId.isEmpty) {
        // Generate NA + 8 digits and double check uniqueness
        alertId = await _generateUniqueNearbyId();
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'nearby_alert_id': alertId,
          'nearbyAlertId': alertId,
        });
      }

      state = AsyncData(NearbyAlertState(nearbyAlertId: alertId));
      
      // Start real-time listeners
      listenToConnections();
      _listenToSessionStatus();
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }

  Future<String> _generateUniqueNearbyId() async {
    final rand = Random();
    final usersRef = FirebaseFirestore.instance.collection('users');
    while (true) {
      final num = 10000000 + rand.nextInt(90000000);
      final testId = 'NA$num';
      final query = await usersRef.where('nearby_alert_id', isEqualTo: testId).limit(1).get();
      if (query.docs.isEmpty) {
        return testId;
      }
    }
  }

  /// Listen to connections list
  void listenToConnections() {
    _connectionsSubscription?.cancel();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Combined stream inside Riverpod state updating
    _connectionsSubscription = FirebaseFirestore.instance
        .collection('nearby_connections')
        .snapshots()
        .listen((snap) {
      final currentList = snap.docs
          .map((doc) => NearbyConnection.fromFirestore(doc))
          .where((conn) => conn.requesterUid == user.uid || conn.recipientUid == user.uid)
          .toList();

      final current = state.valueOrNull ?? NearbyAlertState();
      final stats = _computeStatValues(currentList, current.radius);

      state = AsyncData(current.copyWith(
        connections: currentList,
        activeCount: stats['active'] ?? 0,
        expiringCount: stats['expiring'] ?? 0,
        pendingCount: stats['pending'] ?? 0,
      ));
    });
  }

  void _listenToSessionStatus() {
    _sessionSubscription?.cancel();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _sessionSubscription = FirebaseFirestore.instance
        .collection('nearby_sessions')
        .doc(user.uid)
        .snapshots()
        .listen((snap) {
      final exists = snap.exists;
      final isActive = exists ? (snap.data() as Map<String, dynamic>)['is_active'] == true : false;
      final current = state.valueOrNull ?? NearbyAlertState();
      
      state = AsyncData(current.copyWith(isSessionActive: isActive));

      // Setup timer if active, stop if deleted
      if (isActive) {
        _startTimer();
      } else {
        _locationUpdateTimer?.cancel();
      }
    });
  }

  Map<String, int> _computeStatValues(List<NearbyConnection> list, int radius) {
    int active = 0;
    int expiring = 0;
    int pending = 0;

    for (final conn in list) {
      if (conn.status == 'active' || conn.status == 'accepted') active++;
      if (conn.status == 'expiring') expiring++;
      if (conn.status == 'pending') pending++;
    }

    return {'active': active, 'expiring': expiring, 'pending': pending};
  }

  /// Start Nearby Alert Session
  Future<void> startSession({String connectionType = 'Personal', int radius = 20}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final uData = userDoc.data() as Map<String, dynamic>;
    final firstName = uData['first_name'] ?? uData['firstName'] ?? '';
    final lastName = uData['last_name'] ?? uData['lastName'] ?? '';
    final alertId = uData['nearby_alert_id'] ?? uData['nearbyAlertId'] ?? '';

    // Initials
    String initials = 'U';
    if (firstName.isNotEmpty || lastName.isNotEmpty) {
      final f = firstName.isNotEmpty ? firstName[0] : '';
      final l = lastName.isNotEmpty ? lastName[0] : '';
      initials = '$f$l'.toUpperCase();
    }

    // Coordinates
    double lat = 0.0;
    double lng = 0.0;
    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos != null) {
        lat = pos.latitude;
        lng = pos.longitude;
      }
    } catch (_) {}

    final now = FieldValue.serverTimestamp();
    final expires = Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 10)));

    await FirebaseFirestore.instance.collection('nearby_sessions').doc(user.uid).set({
      'uid': user.uid,
      'first_name': firstName,
      'last_name': lastName,
      'nearby_alert_id': alertId,
      'avatar_initials': initials,
      'lat': lat,
      'lng': lng,
      'last_updated': now,
      'expires_at': expires,
      'is_active': true,
      'radius_metres': radius,
      'connection_type': connectionType,
    });

    final current = state.valueOrNull ?? NearbyAlertState();
    state = AsyncData(current.copyWith(isSessionActive: true, radius: radius));
    _startTimer();
  }

  void _startTimer() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      try {
        final pos = await LocationService.getCurrentPosition();
        if (pos != null) {
          await FirebaseFirestore.instance.collection('nearby_sessions').doc(user.uid).update({
            'lat': pos.latitude,
            'lng': pos.longitude,
            'last_updated': FieldValue.serverTimestamp(),
            'expires_at': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 10))),
          });
        }
      } catch (_) {}
    });
  }

  /// Stop Nearby Alert Session
  Future<void> stopSession() async {
    _locationUpdateTimer?.cancel();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('nearby_sessions').doc(user.uid).delete();
    
    final current = state.valueOrNull ?? NearbyAlertState();
    state = AsyncData(current.copyWith(isSessionActive: false));
  }

  /// Send connection request
  Future<void> sendConnectionRequest(String targetNearbyId, String connectionType) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final current = state.valueOrNull ?? NearbyAlertState();
    if (targetNearbyId == current.nearbyAlertId) {
      throw Exception('You cannot connect with yourself.');
    }

    // Find recipient UID
    final usersQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('nearby_alert_id', isEqualTo: targetNearbyId)
        .limit(1)
        .get();

    String recipientUid;
    Map<String, dynamic> recipientData;

    if (usersQuery.docs.isEmpty) {
      // Try camelCase fallback query
      final camelQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('nearbyAlertId', isEqualTo: targetNearbyId)
          .limit(1)
          .get();
      if (camelQuery.docs.isEmpty) {
        throw Exception('No user found with Nearby Alert ID: $targetNearbyId');
      }
      recipientUid = camelQuery.docs.first.id;
      recipientData = camelQuery.docs.first.data();
    } else {
      recipientUid = usersQuery.docs.first.id;
      recipientData = usersQuery.docs.first.data();
    }

    final recipientName = "${recipientData['first_name'] ?? recipientData['firstName'] ?? ''} ${recipientData['last_name'] ?? recipientData['lastName'] ?? ''}".trim();

    // Query requester name
    final requesterDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final reqData = requesterDoc.data() ?? {};
    final requesterName = "${reqData['first_name'] ?? reqData['firstName'] ?? ''} ${reqData['last_name'] ?? reqData['lastName'] ?? ''}".trim();

    // Add connection document
    await FirebaseFirestore.instance.collection('nearby_connections').add({
      'requester_uid': user.uid,
      'requester_name': requesterName.isEmpty ? 'User' : requesterName,
      'requester_nearby_alert_id': current.nearbyAlertId,
      'recipient_uid': recipientUid,
      'recipient_name': recipientName.isEmpty ? 'User' : recipientName,
      'recipient_nearby_alert_id': targetNearbyId,
      'connection_type': connectionType,
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
      'approved_at': null,
      'expires_at': null,
      'last_distance_metres': 0.0,
      'requester_lat': 0.0,
      'requester_lng': 0.0,
      'recipient_lat': 0.0,
      'recipient_lng': 0.0,
    });
  }

  /// Approve Connection Request
  Future<void> approveConnectionRequest(String connectionId) async {
    final now = DateTime.now();
    final expires = Timestamp.fromDate(now.add(const Duration(hours: 24)));

    // 1. Fetch connection doc
    final connDoc = await FirebaseFirestore.instance.collection('nearby_connections').doc(connectionId).get();
    if (!connDoc.exists) return;
    final connData = connDoc.data() as Map<String, dynamic>;

    final reqUid = connData['requester_uid'] ?? '';
    final recUid = connData['recipient_uid'] ?? '';

    // Update connection status
    await FirebaseFirestore.instance.collection('nearby_connections').doc(connectionId).update({
      'status': 'accepted',
      'approved_at': FieldValue.serverTimestamp(),
      'expires_at': expires,
    });

    // Step 1: Collect locations & names
    double reqLat = 0.0;
    double reqLng = 0.0;
    String reqAddress = "Location";
    String reqFirstName = connData['requester_name'] ?? 'User';
    String reqLastName = '';

    double recLat = 0.0;
    double recLng = 0.0;
    String recAddress = "Location";
    String recFirstName = connData['recipient_name'] ?? 'User';
    String recLastName = '';

    // Fetch Requester Details
    final reqUserDoc = await FirebaseFirestore.instance.collection('users').doc(reqUid).get();
    if (reqUserDoc.exists) {
      final data = reqUserDoc.data()!;
      reqFirstName = data['first_name'] ?? data['firstName'] ?? reqFirstName;
      reqLastName = data['last_name'] ?? data['lastName'] ?? '';
      reqLat = double.tryParse((data['last_known_lat'] ?? data['lat'] ?? '0.0').toString()) ?? 0.0;
      reqLng = double.tryParse((data['last_known_lng'] ?? data['lng'] ?? '0.0').toString()) ?? 0.0;
    }
    final reqSessionDoc = await FirebaseFirestore.instance.collection('nearby_sessions').doc(reqUid).get();
    if (reqSessionDoc.exists) {
      final sData = reqSessionDoc.data()!;
      reqLat = double.tryParse((sData['lat'] ?? reqLat).toString()) ?? reqLat;
      reqLng = double.tryParse((sData['lng'] ?? reqLng).toString()) ?? reqLng;
    }
    try {
      if (reqLat != 0.0 && reqLng != 0.0) {
        reqAddress = await LocationService.reverseGeocode(reqLat, reqLng);
      }
    } catch (_) {}

    // Fetch Recipient Details
    final recUserDoc = await FirebaseFirestore.instance.collection('users').doc(recUid).get();
    if (recUserDoc.exists) {
      final data = recUserDoc.data()!;
      recFirstName = data['first_name'] ?? data['firstName'] ?? recFirstName;
      recLastName = data['last_name'] ?? data['lastName'] ?? '';
      recLat = double.tryParse((data['last_known_lat'] ?? data['lat'] ?? '0.0').toString()) ?? 0.0;
      recLng = double.tryParse((data['last_known_lng'] ?? data['lng'] ?? '0.0').toString()) ?? 0.0;
    }
    final recSessionDoc = await FirebaseFirestore.instance.collection('nearby_sessions').doc(recUid).get();
    if (recSessionDoc.exists) {
      final sData = recSessionDoc.data()!;
      recLat = double.tryParse((sData['lat'] ?? recLat).toString()) ?? recLat;
      recLng = double.tryParse((sData['lng'] ?? recLng).toString()) ?? recLng;
    }
    try {
      recAddress = await LocationService.reverseGeocode(recLat, recLng);
    } catch (_) {}

    final expiresAt7Days = Timestamp.fromDate(now.add(const Duration(days: 7)));

    // Step 2: Write location_history entries for both users
    await FirebaseFirestore.instance.collection('users').doc(reqUid).collection('location_history').add({
      'lat': reqLat,
      'lng': reqLng,
      'latitude': reqLat,
      'longitude': reqLng,
      'address': reqAddress,
      'note': 'Connected via Nearby Alert',
      'created_at': FieldValue.serverTimestamp(),
      'expires_at': expiresAt7Days,
      'source': 'nearby_alert',
      'tag_label': 'Nearby Alert',
      'tag_color': '6C3FC4',
    });

    await FirebaseFirestore.instance.collection('users').doc(recUid).collection('location_history').add({
      'lat': recLat,
      'lng': recLng,
      'latitude': recLat,
      'longitude': recLng,
      'address': recAddress,
      'note': 'Connected via Nearby Alert',
      'created_at': FieldValue.serverTimestamp(),
      'expires_at': expiresAt7Days,
      'source': 'nearby_alert',
      'tag_label': 'Nearby Alert',
      'tag_color': '6C3FC4',
    });

    // Step 3: Collect visible_to UIDs (trusted contacts of both users without duplicates + both users)
    final Set<String> visibleTo = {reqUid, recUid};

    final reqTrustedSnap = await FirebaseFirestore.instance
        .collection('trusted_circle_requests')
        .where('status', isEqualTo: 'accepted')
        .get();

    for (final doc in reqTrustedSnap.docs) {
      final data = doc.data();
      final r1 = data['requester_uid'];
      final r2 = data['recipient_uid'];
      if (r1 == reqUid && r2 != null) visibleTo.add(r2.toString());
      if (r2 == reqUid && r1 != null) visibleTo.add(r1.toString());
      if (r1 == recUid && r2 != null) visibleTo.add(r2.toString());
      if (r2 == recUid && r1 != null) visibleTo.add(r1.toString());
    }

    final visibleToList = visibleTo.toList();

    // Write to nearby_alert_events collection
    final eventRef = await FirebaseFirestore.instance.collection('nearby_alert_events').add({
      'connection_id': connectionId,
      'requester_uid': reqUid,
      'requester_first_name': reqFirstName,
      'requester_last_name': reqLastName,
      'requester_lat': reqLat,
      'requester_lng': reqLng,
      'requester_address': reqAddress,
      'recipient_uid': recUid,
      'recipient_first_name': recFirstName,
      'recipient_last_name': recLastName,
      'recipient_lat': recLat,
      'recipient_lng': recLng,
      'recipient_address': recAddress,
      'status': 'accepted',
      'connected_at': FieldValue.serverTimestamp(),
      'visible_to': visibleToList,
    });

    // Step 4: Write FCM notification entries to visible_to UIDs
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    for (final contactUid in visibleToList) {
      if (contactUid == reqUid || contactUid == recUid) continue; // notify trusted contacts
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(contactUid)
            .collection('notifications')
            .add({
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'title': 'Nearby Alert Connection',
          'message': '$reqFirstName and $recFirstName connected via Nearby Alert at $timeStr',
          'desc': '$reqFirstName and $recFirstName connected via Nearby Alert at $timeStr',
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'nearby_alert',
          'nearby_alert_event_id': eventRef.id,
        });
      } catch (e) {
        debugPrint("Failed to write notification to $contactUid: $e");
      }
    }
  }

  /// Decline Connection Request
  Future<void> declineConnectionRequest(String connectionId) async {
    final connDoc = await FirebaseFirestore.instance.collection('nearby_connections').doc(connectionId).get();
    if (!connDoc.exists) return;
    final connData = connDoc.data() as Map<String, dynamic>;

    final reqUid = connData['requester_uid'] ?? '';
    final recUid = connData['recipient_uid'] ?? '';

    await FirebaseFirestore.instance.collection('nearby_connections').doc(connectionId).update({
      'status': 'declined',
    });

    final Set<String> visibleTo = {reqUid, recUid};
    final eventRef = await FirebaseFirestore.instance.collection('nearby_alert_events').add({
      'connection_id': connectionId,
      'requester_uid': reqUid,
      'requester_first_name': connData['requester_name'] ?? 'User',
      'requester_last_name': '',
      'requester_lat': connData['requester_lat'] ?? 0.0,
      'requester_lng': connData['requester_lng'] ?? 0.0,
      'requester_address': '',
      'recipient_uid': recUid,
      'recipient_first_name': connData['recipient_name'] ?? 'User',
      'recipient_last_name': '',
      'recipient_lat': connData['recipient_lat'] ?? 0.0,
      'recipient_lng': connData['recipient_lng'] ?? 0.0,
      'recipient_address': '',
      'status': 'declined',
      'connected_at': FieldValue.serverTimestamp(),
      'visible_to': visibleTo.toList(),
    });
  }

  /// Cancel request (Delete connection)
  Future<void> cancelConnectionRequest(String connectionId) async {
    await FirebaseFirestore.instance.collection('nearby_connections').doc(connectionId).delete();
  }

  /// Renew Connection
  Future<void> renewConnection(String connectionId) async {
    final now = DateTime.now();
    final expires = Timestamp.fromDate(now.add(const Duration(hours: 24)));

    await FirebaseFirestore.instance.collection('nearby_connections').doc(connectionId).update({
      'status': 'active',
      'expires_at': expires,
    });
  }

  /// Disconnect connection
  Future<void> disconnectConnection(String connectionId) async {
    await FirebaseFirestore.instance.collection('nearby_connections').doc(connectionId).update({
      'status': 'disconnected',
    });
  }
}

final nearbyAlertProvider = AsyncNotifierProvider<NearbyAlertNotifier, NearbyAlertState>(() {
  return NearbyAlertNotifier();
});
