import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import '../../features/location/services/location_service.dart';

class SentinelAlertEvent {
  final String id;
  final String matchedPhrase;
  final String threatCategory;
  final double confidence;
  final String alertType; // 'speech' or 'sound'
  final DateTime timestamp;
  final bool isFalseAlarm;

  SentinelAlertEvent({
    required this.id,
    required this.matchedPhrase,
    required this.threatCategory,
    required this.confidence,
    required this.alertType,
    required this.timestamp,
    this.isFalseAlarm = false,
  });
}

class AlertTriggerService {
  static final AlertTriggerService _instance = AlertTriggerService._internal();
  factory AlertTriggerService() => _instance;
  AlertTriggerService._internal();

  DateTime? _lastAlertTime;
  Timer? _falseAlarmTimer;
  String? _pendingAlertDocId;

  // Stream controller for active 5-second false alarm countdowns
  final StreamController<int?> _countdownController = StreamController<int?>.broadcast();
  Stream<int?> get countdownStream => _countdownController.stream;

  // Callback to update UI logs
  void Function(SentinelAlertEvent event)? onLogEvent;

  Future<void> triggerAlert({
    required String matchedPhrase,
    required String threatCategory,
    required double confidence,
    required String alertType,
    double threshold = 0.85,
  }) async {
    final now = DateTime.now();

    // 1. Apply 3-second Cooldown
    if (_lastAlertTime != null && now.difference(_lastAlertTime!).inSeconds < 3) {
      debugPrint("[ALERT_TRIGGER] Cooldown active (3s). Ignoring trigger.");
      return;
    }
    _lastAlertTime = now;

    // 2. Short 3-pulse vibration pattern
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        Vibration.vibrate(pattern: [0, 150, 100, 150, 100, 150]);
      } else {
        HapticFeedback.heavyImpact();
      }
    } catch (_) {
      HapticFeedback.heavyImpact();
    }

    final eventId = DateTime.now().millisecondsSinceEpoch.toString();
    final event = SentinelAlertEvent(
      id: eventId,
      matchedPhrase: matchedPhrase,
      threatCategory: threatCategory,
      confidence: confidence,
      alertType: alertType,
      timestamp: now,
    );

    // 3. Update Real-Time UI Log
    onLogEvent?.call(event);

    // 4. If confidence >= threshold, initiate 5-second False Alarm countdown & Firestore write
    if (confidence >= threshold) {
      await _initiateAlertSequence(event);
    }
  }

  Future<void> _initiateAlertSequence(SentinelAlertEvent event) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Fetch user current position
    final pos = await LocationService.getCurrentPosition();
    final lat = pos?.latitude ?? 0.0;
    final lng = pos?.longitude ?? 0.0;
    final address = (lat != 0.0 && lng != 0.0)
        ? await LocationService.reverseGeocode(lat, lng)
        : "Unknown Location";

    try {
      // Write sentinel_alert document to Firestore
      final docRef = await FirebaseFirestore.instance.collection('sentinel_alerts').add({
        'uid': user.uid,
        'matched_phrase': event.matchedPhrase,
        'threat_category': event.threatCategory,
        'confidence': event.confidence,
        'lat': lat,
        'lng': lng,
        'address': address,
        'triggered_at': FieldValue.serverTimestamp(),
        'alert_type': event.alertType,
        'is_false_alarm': false,
      });

      _pendingAlertDocId = docRef.id;
    } catch (e) {
      debugPrint("[ALERT_TRIGGER] Firestore write error: $e");
    }

    // 5-second False Alarm countdown
    _falseAlarmTimer?.cancel();
    int secondsRemaining = 5;
    _countdownController.add(secondsRemaining);

    _falseAlarmTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      secondsRemaining--;
      if (secondsRemaining > 0) {
        _countdownController.add(secondsRemaining);
      } else {
        timer.cancel();
        _countdownController.add(null);
        // 5 seconds expired without tapping False Alarm -> Send FCM to Trusted Contacts!
        await _dispatchFCMNotifications(user.uid, event.matchedPhrase, lat, lng, address);
        _pendingAlertDocId = null;
      }
    });
  }

  /// Called when user taps the "False Alarm" button within 5 seconds
  Future<void> cancelFalseAlarm() async {
    _falseAlarmTimer?.cancel();
    _countdownController.add(null);

    if (_pendingAlertDocId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('sentinel_alerts')
            .doc(_pendingAlertDocId)
            .update({'is_false_alarm': true});
        debugPrint("[ALERT_TRIGGER] Alert marked as False Alarm: $_pendingAlertDocId");
      } catch (e) {
        debugPrint("[ALERT_TRIGGER] Error updating false alarm: $e");
      }
      _pendingAlertDocId = null;
    }
  }

  Future<void> _dispatchFCMNotifications(String uid, String phrase, double lat, double lng, String address) async {
    try {
      // Fetch user profile name
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final firstName = userDoc.data()?['first_name'] ?? userDoc.data()?['firstName'] ?? 'User';

      // Send panic FCM alert to all trusted contacts using panic endpoint
      await FirebaseFirestore.instance.collection('panic_alerts').add({
        'user_id': uid,
        'user_name': firstName,
        'user_phone': userDoc.data()?['phone'] ?? '',
        'latitude': lat,
        'longitude': lng,
        'address': address,
        'timestamp': FieldValue.serverTimestamp(),
        'alert_type': 'audio_sentinel',
        'matched_phrase': phrase,
        'title': 'Audio Sentinel Alert',
        'message': '$firstName may be in danger. A distress signal was detected near their location.',
      });

      debugPrint("[ALERT_TRIGGER] FCM Sentinel Alert dispatched successfully.");
    } catch (e) {
      debugPrint("[ALERT_TRIGGER] Error dispatching FCM alert: $e");
    }
  }
}
