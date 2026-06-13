import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Represents the current state of the voice engine.
enum VoiceState {
  idle,
  listening,
  wakeWordArmed, // continuous mode, waiting for "DomFix"
  processing,
  success,
  error,
}

/// Result from a single STT capture.
class VoiceCapture {
  final String text;
  final bool hadWakeWord;
  final bool isFinal;

  const VoiceCapture({
    required this.text,
    this.hadWakeWord = false,
    this.isFinal = false,
  });
}

/// Unified Voice Control Service.
///
/// All NLP / command execution is handled by the AI layer (Groq).
/// This service is ONLY responsible for:
///   1. STT → transcript text
///   2. Wake-word detection (prefix "domfix" / "hey domfix")
///   3. Continuous listening loop for hands-free mode
class VoiceControlService {
  VoiceControlService._();
  static final VoiceControlService instance = VoiceControlService._();
  factory VoiceControlService() => instance;

  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  bool _continuousRunning = false;

  /// Observable voice state for UI bindings.
  final ValueNotifier<VoiceState> state = ValueNotifier(VoiceState.idle);

  /// Real-time partial transcript (updated as user speaks).
  final ValueNotifier<String> liveTranscript = ValueNotifier('');

  // ─── Wake word patterns ─────────────────────────────────────
  static const List<String> _wakeWords = [
    'hey domfix',
    'domfix',
    'dom fix',
    'hey dom fix',
    // Darija variants
    'doomfix',
    'dom fics',
  ];

  // ─── Supported locales (try in order, use first available) ──
  static const List<String> _preferredLocales = [
    'en_US',
    'fr_FR',
    'ar_SA',
    'ar',
    'fr',
    'en',
  ];

  // ─── Initialization ─────────────────────────────────────────

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    _isInitialized = await _speech.initialize(
      onError: (error) => debugPrint('🎤 [STT Error] $error'),
      onStatus: (status) => debugPrint('🎤 [STT Status] $status'),
    );
    return _isInitialized;
  }

  Future<String?> _bestLocale() async {
    final available = await _speech.locales();
    final ids = available.map((l) => l.localeId).toSet();
    for (final pref in _preferredLocales) {
      if (ids.contains(pref)) return pref;
      // Partial match: 'ar' matches 'ar_SA'
      final partial = ids.where((id) => id.startsWith(pref)).firstOrNull;
      if (partial != null) return partial;
    }
    return null; // Let STT pick device default
  }

  // ─── One-shot listening ─────────────────────────────────────

  /// Listen once for a command. Returns a stream of partial results; 
  /// completes with the final transcript (stripped of any wake word).
  ///
  /// The caller (UI) sends the result to [AiService].
  Future<void> startListening({
    required void Function(String partial) onPartial,
    required void Function(String finalText) onFinal,
    required void Function(String error) onError,
  }) async {
    if (!await initialize()) {
      onError('Microphone not available or permission denied.');
      return;
    }

    state.value = VoiceState.listening;
    liveTranscript.value = '';

    final locale = await _bestLocale();

    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        final words = result.recognizedWords;
        liveTranscript.value = words;
        onPartial(words);

        if (result.finalResult) {
          final stripped = _stripWakeWord(words);
          state.value = VoiceState.idle;
          liveTranscript.value = '';
          onFinal(stripped);
        }
      },
      listenOptions: SpeechListenOptions(
        localeId: locale,
        listenMode: ListenMode.confirmation,
        cancelOnError: true,
        pauseFor: const Duration(seconds: 2),
        listenFor: const Duration(seconds: 20),
      ),
    );
  }

  /// Stop current one-shot listen.
  Future<void> stopListening() async {
    await _speech.stop();
    state.value = VoiceState.idle;
    liveTranscript.value = '';
  }

  // ─── Continuous / Wake-word mode ────────────────────────────

  /// Start a continuous listening loop that fires [onWakeCommand] when
  /// the user says "DomFix, <command>".
  ///
  /// The callback receives the command text (wake word stripped).
  /// Caller should route it to [AiService] for execution.
  Future<void> startContinuousListening({
    required void Function(String command) onWakeCommand,
    required void Function(String partial) onPartial,
    void Function()? onListenCycleStart,
  }) async {
    if (!await initialize()) return;
    if (_continuousRunning) return;

    _continuousRunning = true;
    state.value = VoiceState.wakeWordArmed;

    final locale = await _bestLocale();

    while (_continuousRunning) {
      if (!_speech.isAvailable) break;

      onListenCycleStart?.call();
      liveTranscript.value = '';

      final completer = Completer<String?>();

      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          final words = result.recognizedWords;
          liveTranscript.value = words;
          onPartial(words);

          if (result.finalResult && !completer.isCompleted) {
            completer.complete(words);
          }
        },
        listenOptions: SpeechListenOptions(
          localeId: locale,
          listenMode: ListenMode.dictation,
          cancelOnError: false,
          pauseFor: const Duration(seconds: 2),
          listenFor: const Duration(seconds: 8),
        ),
      );

      // Wait for result or timeout
      final text = await completer.future
          .timeout(const Duration(seconds: 10), onTimeout: () => null);

      if (!_continuousRunning) break;

      if (text != null && text.isNotEmpty) {
        final lower = text.toLowerCase().trim();
        final hasWake = _wakeWords.any((w) => lower.startsWith(w));

        if (hasWake) {
          final command = _stripWakeWord(text);
          if (command.isNotEmpty) {
            state.value = VoiceState.processing;
            onWakeCommand(command);
            // Brief pause to avoid immediately re-triggering
            await Future.delayed(const Duration(seconds: 1));
            state.value = VoiceState.wakeWordArmed;
          }
        }
      }

      // Brief pause between cycles
      await Future.delayed(const Duration(milliseconds: 300));
    }

    state.value = VoiceState.idle;
  }

  Future<void> stopContinuousListening() async {
    _continuousRunning = false;
    await _speech.stop();
    state.value = VoiceState.idle;
    liveTranscript.value = '';
  }

  bool get isContinuousListening => _continuousRunning;

  // ─── Helpers ────────────────────────────────────────────────

  /// Strip wake word prefix from spoken text.
  String _stripWakeWord(String text) {
    final lower = text.toLowerCase().trim();
    for (final wake in _wakeWords) {
      if (lower.startsWith(wake)) {
        final stripped = text.substring(wake.length).trim();
        // Remove leading comma, "," 
        return stripped.replaceFirst(RegExp(r'^[,،\s]+'), '').trim();
      }
    }
    return text.trim();
  }

  /// Check if text contains a wake word (for UI display).
  bool containsWakeWord(String text) {
    final lower = text.toLowerCase().trim();
    return _wakeWords.any((w) => lower.contains(w));
  }
}
