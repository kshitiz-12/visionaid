import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';

import '../network/companion_client.dart';
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
  Completer<void>? _speaking;

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
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) {
      throw StateError('Text to speak cannot be empty');
    }
    await _ensureReady();
    await stop();
    _speaking = Completer<void>();
    await _tts.speak(text);
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

class HumanizedTextToSpeechService implements TextToSpeechService {
  HumanizedTextToSpeechService({
    CompanionClient? companion,
    AndroidTextToSpeechService? device,
  })  : _companion = companion ?? CompanionClient(),
        _device = device ?? AndroidTextToSpeechService();

  final CompanionClient _companion;
  final AndroidTextToSpeechService _device;
  final AudioPlayer _player = AudioPlayer();

  bool _useDeviceOnly(String text) {
    final t = text.trim().toLowerCase();
    return t == 'listening…' ||
        t == 'listening...' ||
        t.startsWith('listening') ||
        t.startsWith('working');
  }

  @override
  Future<void> setLocale(String locale) async {
    await _device.setLocale(locale);
  }

  @override
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) {
      throw StateError('Text to speak cannot be empty');
    }
    await stop();
    if (!_useDeviceOnly(text)) {
      try {
        final lang = AppLanguage.fromCode(await UserPrefs.getLanguageCode()).code;
        final bytes = await _companion.speakAudio(text: text, language: lang);
        if (bytes != null && bytes.isNotEmpty) {
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/visionaid_tts.mp3');
          await file.writeAsBytes(bytes, flush: true);
          final done = Completer<void>();
          StreamSubscription<void>? sub;
          sub = _player.onPlayerComplete.listen((_) {
            if (!done.isCompleted) {
              done.complete();
            }
          });
          await _player.play(DeviceFileSource(file.path));
          await done.future.timeout(const Duration(seconds: 60));
          await sub.cancel();
          return;
        }
      } catch (_) {
        // Fall back to on-device TTS.
      }
    }
    await _device.speak(text);
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await _device.stop();
  }
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
