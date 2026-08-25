import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../network/companion_client.dart';
import 'speech_sanitizer.dart';
import 'user_prefs.dart';

abstract class TextToSpeechService {
  Future<void> speak(
    String text, {
    bool interrupt = true,
    bool natural = false,
  });
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
    await _tts.setSpeechRate((speed + 0.12).clamp(0.36, 0.66));
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
  Future<void> speak(
    String text, {
    bool interrupt = true,
    bool natural = false,
  }) async {
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

/// Home chat uses OpenAI gpt-4o-mini-tts (ChatGPT Voice). Walking stays on-device.
class HumanizedTextToSpeechService implements TextToSpeechService {
  HumanizedTextToSpeechService({
    required CompanionClient companion,
    AndroidTextToSpeechService? device,
    AudioPlayer? player,
  })  : _companion = companion,
        _device = device ?? AndroidTextToSpeechService(),
        _player = player ?? AudioPlayer();

  final CompanionClient _companion;
  final AndroidTextToSpeechService _device;
  final AudioPlayer _player;
  Completer<void>? _cloudDone;
  bool _playerReady = false;

  Future<void> _ensurePlayer() async {
    if (_playerReady) {
      return;
    }
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setPlayerMode(PlayerMode.mediaPlayer);
    await _player.setVolume(1.0);
    await _player.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: false,
          contentType: AndroidContentType.speech,
          usageType: AndroidUsageType.assistanceAccessibility,
          audioFocus: AndroidAudioFocus.gain,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {AVAudioSessionOptions.defaultToSpeaker},
        ),
      ),
    );
    _player.onPlayerComplete.listen((_) {
      final pending = _cloudDone;
      if (pending != null && !pending.isCompleted) {
        pending.complete();
      }
    });
    _playerReady = true;
  }

  @override
  Future<void> setLocale(String locale) => _device.setLocale(locale);

  @override
  Future<void> speak(
    String text, {
    bool interrupt = true,
    bool natural = false,
  }) async {
    final spoken = SpeechSanitizer.clean(text);
    if (spoken.isEmpty) {
      throw StateError('Text to speak cannot be empty');
    }
    if (interrupt) {
      await stop();
    }
    if (natural) {
      final played = await _playCloud(spoken);
      if (played) {
        return;
      }
    }
    await _device.speak(spoken, interrupt: interrupt);
  }

  Future<bool> _playCloud(String spoken) async {
    final lang = AppLanguage.fromCode(await UserPrefs.getLanguageCode());
    Uint8List? bytes;
    try {
      bytes = await _companion
          .speakAudio(text: spoken, language: lang.code)
          .timeout(const Duration(seconds: 5));
    } on TimeoutException {
      return false;
    }
    if (bytes == null || bytes.isEmpty) {
      return false;
    }
    try {
      await _ensurePlayer();
      _cloudDone = Completer<void>();
      await _player.play(BytesSource(bytes, mimeType: 'audio/mpeg'));
      await _cloudDone!.future.timeout(const Duration(seconds: 90));
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
    final pending = _cloudDone;
    if (pending != null && !pending.isCompleted) {
      pending.complete();
    }
    _cloudDone = null;
    await _device.stop();
  }
}

class MockTextToSpeechService implements TextToSpeechService {
  @override
  Future<void> speak(
    String text, {
    bool interrupt = true,
    bool natural = false,
  }) async {
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
