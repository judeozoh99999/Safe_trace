import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SentinelState {
  final bool isActive;
  final String lastClassification;
  final double confidence;
  final List<String> history;

  SentinelState({
    this.isActive = false,
    this.lastClassification = 'Inactive',
    this.confidence = 0.0,
    this.history = const [],
  });

  SentinelState copyWith({
    bool? isActive,
    String? lastClassification,
    double? confidence,
    List<String>? history,
  }) {
    return SentinelState(
      isActive: isActive ?? this.isActive,
      lastClassification: lastClassification ?? this.lastClassification,
      confidence: confidence ?? this.confidence,
      history: history ?? this.history,
    );
  }
}

class SentinelNotifier extends StateNotifier<SentinelState> {
  SentinelNotifier() : super(SentinelState());

  Timer? _classificationTimer;
  final List<String> _mockSounds = [
    'Ambient Office Hum',
    'Street Traffic Noise',
    'Background Conversation',
    'Car Horn in Distance',
    'Silence',
  ];

  void toggleActive() {
    if (state.isActive) {
      _classificationTimer?.cancel();
      state = state.copyWith(
        isActive: false,
        lastClassification: 'Inactive',
        confidence: 0.0,
      );
    } else {
      state = state.copyWith(
        isActive: true,
        lastClassification: 'Calibrating microphone...',
        confidence: 1.0,
        history: ['Watch Mode Activated - listening for danger signals...'],
      );

      // Trigger classification every 3 seconds
      _classificationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        final sound = _mockSounds[timer.tick % _mockSounds.length];
        final confidence = 0.85 + (timer.tick % 15) * 0.01;
        final timestamp = DateTime.now().toLocal().toString().substring(11, 19);
        final log = '[$timestamp] Detected: $sound (${(confidence * 100).toStringAsFixed(0)}%)';
        
        state = state.copyWith(
          lastClassification: sound,
          confidence: confidence,
          history: [log, ...state.history.take(15)],
        );
      });
    }
  }

  @override
  void dispose() {
    _classificationTimer?.cancel();
    super.dispose();
  }
}

final sentinelProvider = StateNotifierProvider<SentinelNotifier, SentinelState>((ref) {
  return SentinelNotifier();
});
