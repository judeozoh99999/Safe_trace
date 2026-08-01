import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/location_service.dart';
import '../../../core/services/inactivity_service.dart';

enum HomeViewMode { map, history }

class HomeState {
  final HomeViewMode viewMode;
  final bool isTracking;
  final double currentLatitude;
  final double currentLongitude;
  final List<Map<String, String>> logs;

  HomeState({
    this.viewMode = HomeViewMode.map,
    this.isTracking = false,
    this.currentLatitude = 0.0,
    this.currentLongitude = 0.0,
    this.logs = const [],
  });

  HomeState copyWith({
    HomeViewMode? viewMode,
    bool? isTracking,
    double? currentLatitude,
    double? currentLongitude,
    List<Map<String, String>>? logs,
  }) {
    return HomeState(
      viewMode: viewMode ?? this.viewMode,
      isTracking: isTracking ?? this.isTracking,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      logs: logs ?? this.logs,
    );
  }
}

class HomeNotifier extends StateNotifier<HomeState> {
  final Ref _ref;
  ProviderSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot>? _locationsSubscription;
  StreamSubscription<QuerySnapshot>? _historySubscription;
  StreamSubscription<Position>? _positionSubscription;

  HomeNotifier(this._ref) : super(HomeState()) {
    _ref.read(firebaseAuthProvider).authStateChanges().listen((user) {
      if (user != null) {
        _subscribeToLocations(user.uid);
      } else {
        _unsubscribe();
        state = HomeState();
      }
    });
  }

  void _subscribeToLocations(String uid) {
    _locationsSubscription?.cancel();
    _historySubscription?.cancel();

    QuerySnapshot? locSnap;
    QuerySnapshot? histSnap;

    void updateLogs() {
      final locDocs = locSnap?.docs ?? [];
      final histDocs = histSnap?.docs ?? [];

      // Combine and deduplicate by doc ID
      final Map<String, QueryDocumentSnapshot> docMap = {};
      for (final doc in [...locDocs, ...histDocs]) {
        docMap[doc.id] = doc;
      }
      final allDocs = docMap.values.toList();

      // Sort combined docs by timestamp descending
      allDocs.sort((a, b) {
        final dataA = a.data() as Map<String, dynamic>;
        final dataB = b.data() as Map<String, dynamic>;
        final tsA = (dataA['created_at'] ?? dataA['timestamp'] ?? dataA['added_at']) as Timestamp?;
        final tsB = (dataB['created_at'] ?? dataB['timestamp'] ?? dataB['added_at']) as Timestamp?;
        if (tsA == null && tsB == null) return 0;
        if (tsA == null) return 1;
        if (tsB == null) return -1;
        return tsB.compareTo(tsA);
      });

      final logsList = allDocs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final ts = (data['created_at'] ?? data['timestamp'] ?? data['added_at']) as Timestamp?;
        final timestampStr = ts != null ? ts.toDate().toLocal().toString() : 'Just now';
        final rawLat = (data['lat'] ?? data['latitude'] ?? '').toString();
        final rawLng = (data['lng'] ?? data['longitude'] ?? '').toString();
        final address = (data['address'] ?? data['locationName'] ?? 'Logged Location').toString();
        final note = (data['note'] ?? '').toString();
        final source = (data['source'] ?? '').toString();
        final tagLabel = (data['tag_label'] ?? '').toString();
        final tagColor = (data['tag_color'] ?? '').toString();

        return <String, String>{
          'id': doc.id,
          'location': address,
          'timestamp': timestampStr,
          'note': note,
          'aiAdvice': (data['aiAdvice'] ?? '').toString(),
          'latitude': rawLat,
          'longitude': rawLng,
          'lat': rawLat,
          'lng': rawLng,
          'source': source,
          'tag_label': tagLabel,
          'tag_color': tagColor,
          'raw_timestamp': ts != null ? ts.millisecondsSinceEpoch.toString() : '',
        };
      }).toList();

      state = state.copyWith(logs: logsList);
    }

    _locationsSubscription = _ref
        .read(firestoreProvider)
        .collection('users')
        .doc(uid)
        .collection('locations')
        .snapshots()
        .listen((s) {
      locSnap = s;
      updateLogs();
    });

    _historySubscription = _ref
        .read(firestoreProvider)
        .collection('users')
        .doc(uid)
        .collection('location_history')
        .snapshots()
        .listen((s) {
      histSnap = s;
      updateLogs();
    });
  }

  void _unsubscribe() {
    _locationsSubscription?.cancel();
    _locationsSubscription = null;
    _historySubscription?.cancel();
    _historySubscription = null;
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  @override
  void dispose() {
    _authSubscription?.close();
    _unsubscribe();
    super.dispose();
  }

  void setViewMode(HomeViewMode mode) {
    state = state.copyWith(viewMode: mode);
  }

  Future<void> toggleTracking() async {
    if (state.isTracking) {
      _positionSubscription?.cancel();
      _positionSubscription = null;
      state = state.copyWith(isTracking: false);
      InactivityService.updateActivity();
    } else {
      final hasPermission = await LocationService.requestPermissions();
      if (!hasPermission) {
        throw Exception("Location permissions are required to track location.");
      }

      state = state.copyWith(isTracking: true);
      InactivityService.updateActivity();

      // Start stream tracking
      _positionSubscription = LocationService.getPositionStream().listen((position) {
        state = state.copyWith(
          currentLatitude: position.latitude,
          currentLongitude: position.longitude,
        );
        _saveLocationToFirestore(position, "Automated tracking check-in");
      });

      // Log initial position immediately
      final currentPos = await LocationService.getCurrentPosition();
      if (currentPos != null) {
        state = state.copyWith(
          currentLatitude: currentPos.latitude,
          currentLongitude: currentPos.longitude,
        );
        _saveLocationToFirestore(currentPos, "Tracking started");
      }
    }
  }

  Future<void> addManualLog(String note, String aiAdvice, {double? lat, double? lng, String? address}) async {
    final Position position;
    if (lat != null && lng != null) {
      position = Position(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
        accuracy: 0.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
    } else {
      final currentPos = await LocationService.getCurrentPosition();
      if (currentPos == null) {
        throw Exception("Unable to fetch current location. Please verify GPS settings.");
      }
      position = currentPos;
    }

    final finalAddress = address ?? await LocationService.reverseGeocode(position.latitude, position.longitude);
    await _saveLocationToFirestore(position, note, customAiAdvice: aiAdvice, locationName: finalAddress);
    InactivityService.updateActivity();
  }

  Future<void> _saveLocationToFirestore(Position position, String note, {String? customAiAdvice, String? locationName}) async {
    final user = _ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;

    final finalLocationName = locationName ?? await LocationService.reverseGeocode(position.latitude, position.longitude);
    final advice = customAiAdvice ?? "Location updated. Keep your panic button ready and circle alert updated.";

    await _ref.read(firestoreProvider)
        .collection('users')
        .doc(user.uid)
        .collection('locations')
        .add({
      'lat': position.latitude,
      'lng': position.longitude,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'locationName': finalLocationName,
      'timestamp': FieldValue.serverTimestamp(),
      'note': note,
      'aiAdvice': advice,
    });
  }

  Future<void> deleteLog(String id) async {
    final user = _ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;

    await _ref.read(firestoreProvider)
        .collection('users')
        .doc(user.uid)
        .collection('locations')
        .doc(id)
        .delete();
  }
}

final homeProvider = StateNotifierProvider<HomeNotifier, HomeState>((ref) {
  return HomeNotifier(ref);
});
