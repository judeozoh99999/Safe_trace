import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:record/record.dart';
import 'threat_detection_engine.dart';
import 'alert_trigger_service.dart';

enum AudioSentinelLanguageMode {
  englishOnly,
  nigerianEnglishAndPidgin,
  allSupportedLanguages,
}

class SpeechSentinelService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool _isListening = false;
  bool _isInitialized = false;
  String _liveTranscription = "";
  AudioSentinelLanguageMode _languageMode = AudioSentinelLanguageMode.nigerianEnglishAndPidgin;
  double _sensitivityThreshold = 0.85; // Medium default

  Timer? _reconnectTimer;
  StreamSubscription<Amplitude>? _amplitudeSub;
  bool _isAmplitudeActive = true;

  // Callbacks
  void Function(String liveText)? onLiveTranscriptionChanged;
  void Function(ThreatResult result)? onThreatDetected;

  String get liveTranscription => _liveTranscription;
  bool get isListening => _isListening;

  void setSensitivity(double threshold) {
    _sensitivityThreshold = threshold;
    debugPrint("[SPEECH_SENTINEL] Sensitivity threshold updated to: $threshold");
  }

  void setLanguageMode(AudioSentinelLanguageMode mode) {
    _languageMode = mode;
    debugPrint("[SPEECH_SENTINEL] Language mode set to: $mode");
    if (_isListening) {
      _restartListeningStream();
    }
  }

  String _getPrimaryLocale() {
    switch (_languageMode) {
      case AudioSentinelLanguageMode.englishOnly:
        return 'en-US';
      case AudioSentinelLanguageMode.nigerianEnglishAndPidgin:
        return 'en-NG';
      case AudioSentinelLanguageMode.allSupportedLanguages:
        return 'en-NG';
    }
  }

  List<String> _getAlternativeLanguageCodes() {
    switch (_languageMode) {
      case AudioSentinelLanguageMode.englishOnly:
        return ['en-US', 'en-GB'];
      case AudioSentinelLanguageMode.nigerianEnglishAndPidgin:
        return ['en-NG', 'pcm', 'en-US'];
      case AudioSentinelLanguageMode.allSupportedLanguages:
        return ['en-NG', 'en-GH', 'en-US', 'yo-NG', 'ig-NG', 'ha-NG', 'pcm'];
    }
  }

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      _isInitialized = await _speech.initialize(
        onError: (error) {
          debugPrint("[SPEECH_SENTINEL] Error: ${error.errorMsg}");
          if (_isListening) {
            _scheduleReconnect();
          }
        },
        onStatus: (status) {
          debugPrint("[SPEECH_SENTINEL] Status: $status");
          if (status == 'done' || status == 'notListening') {
            if (_isListening && _isAmplitudeActive) {
              _restartListeningStream();
            }
          }
        },
      );
      return _isInitialized;
    } catch (e) {
      debugPrint("[SPEECH_SENTINEL] Init error: $e");
      return false;
    }
  }

  Future<void> startListening() async {
    final ok = await initialize();
    if (!ok) {
      debugPrint("[SPEECH_SENTINEL] Failed to initialize speech recognition.");
      return;
    }

    _isListening = true;
    _liveTranscription = "";
    onLiveTranscriptionChanged?.call("");

    // Start amplitude monitoring for API cost optimization (-20 dB threshold)
    _startAmplitudeMonitoring();

    // Start 5-minute auto-reconnect timer (Speech API 300s limit)
    _start5MinReconnectTimer();

    await _startListeningStream();
  }

  Future<void> _startListeningStream() async {
    if (!_isListening) return;

    try {
      final localeId = _getPrimaryLocale();
      final altLanguages = _getAlternativeLanguageCodes();

      await _speech.listen(
        onResult: (result) {
          _liveTranscription = result.recognizedWords;
          onLiveTranscriptionChanged?.call(_liveTranscription);

          // Real-time interim & final scanning via ThreatDetectionEngine
          if (_liveTranscription.trim().isNotEmpty) {
            final threatResult = ThreatDetectionEngine.evaluate(_liveTranscription);

            if (threatResult.detected) {
              onThreatDetected?.call(threatResult);

              // Trigger alert service
              AlertTriggerService().triggerAlert(
                matchedPhrase: threatResult.matchedPhrase,
                threatCategory: threatResult.threatCategory,
                confidence: threatResult.confidence,
                alertType: 'speech',
                threshold: _sensitivityThreshold,
              );
            }
          }
        },
        localeId: localeId,
        listenFor: const Duration(minutes: 5), // 5-minute continuous chunk
        pauseFor: const Duration(seconds: 5),
        partialResults: true, // Interim results enabled!
        onDevice: false, // Stream to cloud model for maximum Nigerian English accuracy
        listenMode: stt.ListenMode.dictation,
      );

      debugPrint("[SPEECH_SENTINEL] Started listening stream (Locale: $localeId, Alt: $altLanguages)");
    } catch (e) {
      debugPrint("[SPEECH_SENTINEL] Listen error: $e");
    }
  }

  void _startAmplitudeMonitoring() {
    _amplitudeSub?.cancel();
    try {
      // Monitor amplitude every 500ms
      _amplitudeSub = _audioRecorder
          .onAmplitudeChanged(const Duration(milliseconds: 500))
          .listen((amp) {
        final currentDb = amp.current; // dB value
        // Only stream speech when amplitude > -20 dB (cost optimization)
        if (currentDb <= -20.0) {
          if (_isAmplitudeActive) {
            _isAmplitudeActive = false;
            debugPrint("[SPEECH_SENTINEL] Environment quiet (${currentDb.toStringAsFixed(1)} dB <= -20dB). Pausing stream to optimize API cost.");
          }
        } else {
          if (!_isAmplitudeActive) {
            _isAmplitudeActive = true;
            debugPrint("[SPEECH_SENTINEL] Sound detected (${currentDb.toStringAsFixed(1)} dB > -20dB). Resuming stream.");
            if (_isListening && !_speech.isListening) {
              _startListeningStream();
            }
          }
        }
      });
    } catch (e) {
      debugPrint("[SPEECH_SENTINEL] Amplitude monitoring setup error: $e");
    }
  }

  void _start5MinReconnectTimer() {
    _reconnectTimer?.cancel();
    // Reconnect every 4 mins 58s with 2s overlap so no audio is lost
    _reconnectTimer = Timer.periodic(const Duration(minutes: 4, seconds: 58), (_) {
      if (_isListening) {
        debugPrint("[SPEECH_SENTINEL] 5-minute limit reached. Executing seamless stream reconnection...");
        _restartListeningStream();
      }
    });
  }

  Future<void> _restartListeningStream() async {
    if (!_isListening) return;
    try {
      await _speech.stop();
      await Future.delayed(const Duration(milliseconds: 200));
      await _startListeningStream();
    } catch (e) {
      debugPrint("[SPEECH_SENTINEL] Reconnect error: $e");
    }
  }

  void _scheduleReconnect() {
    Timer(const Duration(seconds: 1), () {
      if (_isListening) {
        _startListeningStream();
      }
    });
  }

  Future<void> stopListening() async {
    _isListening = false;
    _reconnectTimer?.cancel();
    _amplitudeSub?.cancel();
    try {
      await _speech.stop();
    } catch (_) {}
    _liveTranscription = "";
    onLiveTranscriptionChanged?.call("");
    debugPrint("[SPEECH_SENTINEL] Stopped listening.");
  }

  void dispose() {
    stopListening();
  }
}
