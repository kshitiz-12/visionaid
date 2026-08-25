import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Immediate close-range cue on a separate audio path from TTS.
class HazardCue {
  HazardCue({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  DateTime? _last;
  bool _ready = false;

  Future<void> _ensurePlayer() async {
    if (_ready) {
      return;
    }
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setPlayerMode(PlayerMode.lowLatency);
    await _player.setVolume(1.0);
    await _player.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: false,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.assistanceSonification,
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
          options: {AVAudioSessionOptions.mixWithOthers},
        ),
      ),
    );
    _ready = true;
  }

  Future<void> pingIfWithinMetre(double? metres) async {
    if (_released || metres == null || metres > 1.0) {
      return;
    }
    final now = DateTime.now();
    if (_last != null && now.difference(_last!) < const Duration(milliseconds: 750)) {
      return;
    }
    _last = now;
    await HapticFeedback.heavyImpact();
    try {
      await _ensurePlayer();
      await _player.stop();
      await _player.play(AssetSource('audio/proximity_beep.wav'));
    } catch (_) {
      await SystemSound.play(SystemSoundType.click);
    }
    if (metres <= 0.6) {
      await HapticFeedback.vibrate();
    }
  }

  bool _released = false;

  Future<void> dispose() async {
    if (_released) {
      return;
    }
    _released = true;
    await _player.dispose();
  }
}
