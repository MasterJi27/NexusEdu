import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Shared Text-to-Speech facade for every voice feature (AI tutor, Bharat
/// AI Voice Tutor). Fixes the three ways flutter_tts can go silent on real
/// devices:
///
/// 1. Android drop lockout — the plugin's native `speaking` flag (armed by
///    `awaitSpeakCompletion(true)`) is only cleared by engine callbacks that
///    devices routinely miss (Doze, engine restart, interrupted utterance).
///    Once stuck, every later `speak()` returns 0 and plays NOTHING until the
///    app restarts. This facade never arms that flag and `stop()`s before
///    every utterance instead.
/// 2. Unsupported forced language — `setLanguage("hi-IN")` on an engine
///    without Hindi makes `speak()` fail silently. Languages are probed via
///    `getLanguages()` and the first supported one is picked, with the engine
///    default as final fallback.
/// 3. iOS silent switch — TTS is muted by the hardware switch unless the
///    audio session is shared; `setSharedInstance(true)` fixes that.
class TtsService {
  TtsService._();

  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  final StreamController<void> _utteranceDone = StreamController<void>.broadcast();
  bool _ready = false;

  bool get ready => _ready;

  /// One-time (or re-runnable) setup. [preferred] is tried in order; the
  /// first language the device's engine actually supports wins.
  Future<void> init({List<String> preferred = const []}) async {
    try {
      await _tts.setSharedInstance(true);
      await _tts.awaitSpeakCompletion(false);
      final supported = await _supportedLanguages();
      final pick = preferred.firstWhere(
        supported.contains,
        orElse: () => '',
      );
      if (pick.isNotEmpty) {
        final ok = await _tts.setLanguage(pick);
        if (ok != true) debugPrint('TtsService: engine rejected language $pick');
      }
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.0);
      _tts.setCompletionHandler(() {
        if (!_utteranceDone.isClosed) _utteranceDone.add(null);
      });
      _tts.setCancelHandler(() {
        if (!_utteranceDone.isClosed) _utteranceDone.add(null);
      });
      _tts.setErrorHandler((_) {
        if (!_utteranceDone.isClosed) _utteranceDone.add(null);
      });
      _ready = true;
    } catch (e) {
      debugPrint('TtsService.init failed: $e');
      _ready = false;
    }
  }

  Future<Set<String>> _supportedLanguages() async {
    try {
      final raw = await _tts.getLanguages;
      if (raw is List) {
        return raw.map((e) => e.toString()).toSet();
      }
    } catch (e) {
      debugPrint('TtsService.getLanguages failed: $e');
    }
    return const {};
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('TtsService.stop failed: $e');
    }
  }

  /// Speaks [text] and returns true when the utterance was handed to the
  /// engine. A `stop()` first clears any stuck native state.
  Future<bool> speak(String text) async {
    if (text.trim().isEmpty) return false;
    if (!_ready) await init();
    try {
      await _tts.stop();
      final ok = await _tts.speak(text);
      return ok == true;
    } catch (e) {
      debugPrint('TtsService.speak failed: $e');
      return false;
    }
  }

  /// Speaks [text] and resolves once the utterance actually finishes (or is
  /// cancelled/errored), falling back to [timeout] so callers never hang on
  /// a device that dropped the callbacks. Returns false when the engine
  /// rejected the utterance.
  Future<bool> speakAndWait(
    String text, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    if (text.trim().isEmpty) return false;
    final done = _utteranceDone.stream.first.timeout(
      timeout,
      onTimeout: () => null,
    );
    final ok = await speak(text);
    if (!ok) return false;
    await done.catchError((_) {});
    return true;
  }
}