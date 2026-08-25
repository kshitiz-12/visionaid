import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import 'user_prefs.dart';
import 'speech_sanitizer.dart';

abstract class TextToSpeechService {
  Future<void> speak(String text, {bool interrupt = true});
  Future<void> stop();
  Future<void> setLocale(String locale);
}

class AndroidTextToSpeechService implements TextToSpeechService {
  AndroidTextToSpeechService({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _ready = false;
  String _locale = 'en-US';
  Completer<void>? _speaking;

  Future<void> _ensureReady() async {
    if (_ready) {
      return;
    }
    final speed = await UserPrefs.getVoiceSpeed();
    final language = AppLanguage.fromCode(await UserPrefs.getLanguageCode());
    _locale = language.ttsLocale;
    await _tts.setLanguage(_locale);
    await _tts.setSpeechRate((speed + 0.12).clamp(0.35, 0.75));
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);
    _tts.setCompletionHandler(() {
      final pending = _speaking;
      if (pending != null && !pending.isCompleted) {
        pending.complete();
      }
    });
    _ready = true;
  }

  @override
  Future<void> setLocale(String locale) async {
    _locale = locale;
    await _ensureReady();
    await _tts.setLanguage(locale);
  }

  @override
  Future<void> speak(String text, {bool interrupt = true}) async {
    if (text.trim().isEmpty) {
      throw StateError('Text to speak cannot be empty');
    }
    await _ensureReady();
    if (!interrupt && _speaking != null && !_speaking!.isCompleted) {
      try {
        await _speaking!.future.timeout(const Duration(seconds: 45));
      } on TimeoutException {
        await _tts.stop();
      }
    }
    if (interrupt) {
      await stop();
    }
    final spoken = SpeechSanitizer.clean(text);
    if (spoken.isEmpty) {
      throw StateError('Text to speak cannot be empty');
    }
    _speaking = Completer<void>();
    await _tts.speak(spoken);
    try {
      await _speaking!.future.timeout(const Duration(seconds: 45));
    } on TimeoutException {
      await _tts.stop();
    }
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
    final pending = _speaking;
    if (pending != null && !pending.isCompleted) {
      pending.complete();
    }
    _speaking = null;
  }
}

class HumanizedTextToSpeechService extends AndroidTextToSpeechService {
  HumanizedTextToSpeechService({super.tts});
}

class MockTextToSpeechService implements TextToSpeechService {
  @override
  Future<void> speak(String text, {bool interrupt = true}) async {
    if (text.isEmpty) {
      throw StateError('Text to speak cannot be empty');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> setLocale(String locale) async {}
}
