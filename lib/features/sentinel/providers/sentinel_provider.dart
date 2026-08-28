import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/services/speech_sentinel_service.dart';
import '../../../core/services/alert_trigger_service.dart';
import '../services/audio_sentinel_service.dart';
import '../../../core/services/subscription_service.dart';

class SentinelLogEntry {
  final String id;
  final String timestamp;
  final String transcription;
  final String matchedPhrase;
  final double confidence;
  final String threatCategory;
  final String type; // 'speech' or 'sound'
  bool isFalseAlarm;

  SentinelLogEntry({
    required this.id,
    required this.timestamp,
    required this.transcription,
    required this.matchedPhrase,
    required this.confidence,
    required this.threatCategory,
    required this.type,
    this.isFalseAlarm = false,
  });
}

class SentinelState {
  final bool isActive;
  final String lastClassification;
  final double confidence;
  final String liveTranscription;
  final double sensitivityThreshold;
  final AudioSentinelLanguageMode languageMode;
  final List<SentinelLogEntry> history;
  final int? countdownSeconds;
  final int? sessionTimeRemainingSeconds;
  final bool showUpgradeModal;

  SentinelState({
    this.isActive = false,
    this.lastClassification = 'Inactive',
    this.confidence = 0.0,
    this.liveTranscription = '',
    this.sensitivityThreshold = 0.85,
    this.languageMode = AudioSentinelLanguageMode.nigerianEnglishAndPidgin,
    this.history = const [],
    this.countdownSeconds,
    this.sessionTimeRemainingSeconds,
    this.showUpgradeModal = false,
  });

  SentinelState copyWith({
    bool? isActive,
    String? lastClassification,
    double? confidence,
    String? liveTranscription,
    double? sensitivityThreshold,
    AudioSentinelLanguageMode? languageMode,
    List<SentinelLogEntry>? history,
    int? countdownSeconds,
    bool clearCountdown = false,
    int? sessionTimeRemainingSeconds,
    bool? showUpgradeModal,
  }) {
    return SentinelState(
      isActive: isActive ?? this.isActive,
      lastClassification: lastClassification ?? this.lastClassification,
      confidence: confidence ?? this.confidence,
      liveTranscription: liveTranscription ?? this.liveTranscription,
      sensitivityThreshold: sensitivityThreshold ?? this.sensitivityThreshold,
      languageMode: languageMode ?? this.languageMode,
      history: history ?? this.history,
      countdownSeconds: clearCountdown ? null : (countdownSeconds ?? this.countdownSeconds),
      sessionTimeRemainingSeconds: sessionTimeRemainingSeconds ?? this.sessionTimeRemainingSeconds,
      showUpgradeModal: showUpgradeModal ?? this.showUpgradeModal,
    );
  }
}

class SentinelNotifier extends StateNotifier<SentinelState> {
  SentinelNotifier() : super(SentinelState());

  SpeechSentinelService? _speechService;
  AudioSentinelService? _yamnetService;
  StreamSubscription<int?>? _countdownSub;
  Timer? _sessionTimer;

  Future<void> toggleActive() async {
    if (state.isActive) {
      await stopSentinel();
    } else {
      await startSentinel();
    }
  }

  Future<void> startSentinel() async {
    // 1. Request microphone permissions
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      debugPrint("[SENTINEL] Microphone permission denied.");
      return;
    }

    // 2. Check Subscription Gating (Section 5 & 7)
    final info = await SubscriptionService.getSubscriptionInfo();
    int? remainingSecs;
    if (!info.isPlus) {
      remainingSecs = 180; // 3 minutes limit per session for Free tier; Unlimited for SafeTrace Plus
    }

    state = state.copyWith(
      isActive: true,
      lastClassification: 'Listening...',
      confidence: 1.0,
      showUpgradeModal: false,
      sessionTimeRemainingSeconds: remainingSecs,
    );

    // 3. Start Session Timer for Free Users
    if (remainingSecs != null) {
      _sessionTimer?.cancel();
      _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (state.sessionTimeRemainingSeconds != null && state.sessionTimeRemainingSeconds! > 0) {
          final next = state.sessionTimeRemainingSeconds! - 1;
          state = state.copyWith(sessionTimeRemainingSeconds: next);
          if (next == 0) {
            timer.cancel();
            stopSentinel();
            state = state.copyWith(showUpgradeModal: true);
          }
        }
      });
    }

    // 4. Initialize Services
    _yamnetService = AudioSentinelService();
    await _yamnetService!.init();
    _yamnetService!.startParallelClassification();

    // Section 5 Gate: Only start Speech-to-Text streaming for Plus users
    if (info.isPlus) {
      _speechService = SpeechSentinelService();
      _speechService!.setSensitivity(state.sensitivityThreshold);
      _speechService!.setLanguageMode(state.languageMode);
      _speechService!.onLiveTranscriptionChanged = (text) {
        state = state.copyWith(liveTranscription: text);
      };
      await _speechService!.startListening();
    }

    // Bind Threat Detection & Alert Service
    AlertTriggerService().onLogEvent = (event) {
      _addLogEntry(event);
    };

    // Bind 5-second False Alarm countdown overlay stream
    _countdownSub?.cancel();
    _countdownSub = AlertTriggerService().countdownStream.listen((secs) {
      if (secs == null) {
        state = state.copyWith(clearCountdown: true);
      } else {
        state = state.copyWith(countdownSeconds: secs);
      }
    });
  }

  void setSensitivity(double threshold) {
    state = state.copyWith(sensitivityThreshold: threshold);
    _speechService?.setSensitivity(threshold);
  }

  void setLanguageMode(AudioSentinelLanguageMode mode) {
    state = state.copyWith(languageMode: mode);
    _speechService?.setLanguageMode(mode);
  }

  void cancelFalseAlarm() {
    AlertTriggerService().cancelFalseAlarm();
    state = state.copyWith(clearCountdown: true);
    if (state.history.isNotEmpty) {
      final updated = List<SentinelLogEntry>.from(state.history);
      updated.first.isFalseAlarm = true;
      state = state.copyWith(history: updated);
    }
  }

  void dismissUpgradeModal() {
    state = state.copyWith(showUpgradeModal: false);
  }

  void _addLogEntry(SentinelAlertEvent event) {
    final timestamp = event.timestamp.toLocal().toString().substring(11, 19);
    final newEntry = SentinelLogEntry(
      id: event.id,
      timestamp: timestamp,
      transcription: state.liveTranscription.isNotEmpty
          ? state.liveTranscription
          : event.matchedPhrase,
      matchedPhrase: event.matchedPhrase,
      confidence: event.confidence,
      threatCategory: event.threatCategory,
      type: event.alertType,
    );

    state = state.copyWith(
      lastClassification: event.matchedPhrase,
      confidence: event.confidence,
      history: [newEntry, ...state.history.take(25)],
    );
  }

  Future<void> stopSentinel() async {
    _sessionTimer?.cancel();
    _countdownSub?.cancel();
    _speechService?.stopListening();
    _yamnetService?.stop();

    _speechService = null;
    _yamnetService = null;

    state = state.copyWith(
      isActive: false,
      lastClassification: 'Inactive',
      confidence: 0.0,
      liveTranscription: '',
      clearCountdown: true,
    );
  }

  @override
  void dispose() {
    stopSentinel();
    super.dispose();
  }
}

final sentinelProvider = StateNotifierProvider<SentinelNotifier, SentinelState>((ref) {
  return SentinelNotifier();
});
