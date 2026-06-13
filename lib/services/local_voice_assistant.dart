import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/activity_log.dart';
import 'activity_log_service.dart';
import 'iot_service.dart';

class LocalVoiceAssistant {
  LocalVoiceAssistant._();
  static final LocalVoiceAssistant instance = LocalVoiceAssistant._();

  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      _isInitialized = await _speechToText.initialize(
        onError: (error) => debugPrint('Voice Assistant Error: $error'),
        onStatus: (status) => debugPrint('Voice Assistant Status: $status'),
      );
    } catch (e) {
      debugPrint('Voice Assistant Init Error: $e');
    }
    return _isInitialized;
  }

  bool get isListening => _speechToText.isListening;

  Future<void> startListening({
    required Function(String) onResult,
    required VoidCallback onDone,
  }) async {
    if (!_isInitialized) await initialize();
    if (!_isInitialized) {
      onDone();
      return;
    }

    await _speechToText.listen(
      onResult: (SpeechRecognitionResult result) {
        onResult(result.recognizedWords);
        if (result.finalResult) {
          onDone();
        }
      },
    );
  }

  Future<void> stopListening() async {
    await _speechToText.stop();
  }

  /// Process the command and return a success message or null if unrecognized
  Future<String?> processCommand(String text) async {
    final lower = text.toLowerCase();
    
    ActivityLogService.instance.logEvent(
      title: 'Voice Command',
      description: 'Heard: "$text"',
      type: LogType.voiceCommand,
    );
    
    // Direct matches
    if (_matches(lower, ['turn on the light', 'allume la lumière', 'شغل الضوء', 'ch3el daw', 'turn on light'])) {
      await IoTService.instance.toggleDevice('ESP32_LED', true);
      return 'Light turned on';
    }
    if (_matches(lower, ['turn off the light', 'éteins la lumière', 'اطفئ الضوء', 'tfi daw', 'turn off light'])) {
      await IoTService.instance.toggleDevice('ESP32_LED', false);
      return 'Light turned off';
    }

    // Smart matching based on keywords
    bool isOn = _containsAny(lower, ['turn on', 'allume', 'ch3el', 'شغل', 'start', 'open', 'ouvre', 'افتح', '7el']);
    bool isOff = _containsAny(lower, ['turn off', 'éteins', 'tfi', 'اطفئ', 'stop', 'close', 'ferme', 'اغلق', 'sed']);
    
    if (isOn || isOff) {
      if (_containsAny(lower, ['light', 'lumière', 'ضوء', 'daw'])) {
        await IoTService.instance.toggleDevice('ESP32_LED', isOn);
        return isOn ? 'Light turned on' : 'Light turned off';
      }
      if (_containsAny(lower, ['fan', 'ventilateur', 'مروحة', 'ervaha', 'air', 'climatiseur'])) {
        await IoTService.instance.toggleDevice('ESP32_FAN', isOn);
        return isOn ? 'Fan turned on' : 'Fan turned off';
      }
      if (_containsAny(lower, ['door', 'porte', 'باب', 'bab', 'garage'])) {
        await IoTService.instance.toggleDevice('ESP32_SERVO', isOn);
        return isOn ? 'Door opened' : 'Door closed';
      }
    }

    return null; // Unrecognized command
  }

  bool _matches(String text, List<String> phrases) {
    return phrases.any((p) => text.contains(p));
  }

  bool _containsAny(String text, List<String> words) {
    return words.any((w) => text.contains(w));
  }
}
