import 'package:flutter_tts/flutter_tts.dart';

import 'user_prefs.dart';

abstract class TextToSpeechService {
  Future<void> speak(String text);
  Future<void> stop();
  Future<void> setLocale(String locale);
}

class AndroidTextToSpeechService implements TextToSpeechService {
  AndroidTextToSpeechService({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _ready = false;
  String _locale = 'en-US';

  Future<void> _ensureReady() async {
    if (_ready) {
      return;
    }
    final speed = await UserPrefs.getVoiceSpeed();
    final language = AppLanguage.fromCode(await UserPrefs.getLanguageCode());
    _locale = language.ttsLocale;
    await _tts.setLanguage(_locale);
    await _tts.setSpeechRate(speed);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _ready = true;
  }

  @override
  Future<void> setLocale(String locale) async {
    _locale = locale;
    await _tts.setLanguage(locale);
  }

  @override
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) {
      throw StateError('Text to speak cannot be empty');
    }
    await _ensureReady();
    await _tts.stop();
    await _tts.speak(text);
  }

  @override
  Future<void> stop() => _tts.stop();
}

class MockTextToSpeechService implements TextToSpeechService {
  @override
  Future<void> speak(String text) async {
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
