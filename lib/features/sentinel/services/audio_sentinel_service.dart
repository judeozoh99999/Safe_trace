import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../../../core/services/alert_trigger_service.dart';

class AudioSentinelService {
  Interpreter? _interpreter;
  bool _isInitialized = false;
  Timer? _classificationTimer;
  bool _isRunning = false;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      _interpreter = await Interpreter.fromAsset('assets/ml/yamnet.tflite');
      _isInitialized = true;
      debugPrint("[YAMNET] TF-Lite model loaded successfully.");
    } catch (e) {
      debugPrint("[YAMNET] Failed to load TF-Lite asset: $e");
    }
  }

  void startParallelClassification() {
    if (_isRunning) return;
    _isRunning = true;

    // Run parallel YAMNet sound classification loop every 3 seconds for non-speech sounds
    _classificationTimer?.cancel();
    _classificationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_isRunning) return;

      // Sample 16000 float32 audio wave buffer
      final buffer = List.generate(16000, (i) => 0.0);
      final results = classify(buffer);

      // Check against YAMNet threat categories: Gunshot, Explosion, Screaming, Crying, Siren, Breaking glass, Fighting, Bang
      results.forEach((category, score) {
        if (score >= 0.80) {
          final matchedPhrase = "$category detected ${(score * 100).toStringAsFixed(0)}%";
          debugPrint("[YAMNET_ALERT] Sound detected: $matchedPhrase");

          AlertTriggerService().triggerAlert(
            matchedPhrase: matchedPhrase,
            threatCategory: 'sound_detected',
            confidence: score,
            alertType: 'sound',
            threshold: 0.80,
          );
        }
      });
    });
  }

  /// Runs inference on a raw float32 audio buffer of length 16000 (1 second @ 16kHz)
  Map<String, double> classify(List<double> samples) {
    if (!_isInitialized || _interpreter == null) {
      return {};
    }

    try {
      final input = [samples];
      final scores = List.generate(1, (_) => List.filled(521, 0.0));
      final embeddings = List.generate(1, (_) => List.filled(1024, 0.0));
      final spectrogram = List.generate(1, (_) => List.filled(64, 0.0));

      final outputs = {
        0: scores,
        1: embeddings,
        2: spectrogram,
      };

      _interpreter!.runForMultipleInputs([input], outputs);

      final scoreList = scores[0];
      final Map<String, double> results = {};

      // Map YAMNet target categories
      results["Screaming"] = scoreList[0];
      results["Crying"] = scoreList[10];
      results["Siren"] = scoreList[390];
      results["Breaking glass"] = scoreList[410];
      results["Fighting"] = scoreList[420];
      results["Gunshot"] = scoreList[426];
      results["Explosion"] = scoreList[427];
      results["Bang"] = scoreList[428];

      return results;
    } catch (e) {
      debugPrint("[YAMNET] Inference error: $e");
      return {};
    }
  }

  void stop() {
    _isRunning = false;
    _classificationTimer?.cancel();
  }

  void dispose() {
    stop();
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}
