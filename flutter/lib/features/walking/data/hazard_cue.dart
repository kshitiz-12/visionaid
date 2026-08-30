import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Immediate close-range cue on a separate audio path from TTS.
class HazardCue {
  HazardCue({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  DateTime? _last;
  bool _ready = false;
  bool _released = false;

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

  /// Interval for target-search beeps (ms). Closer + more centered → faster.
  static int targetIntervalMs({
    required double? metres,
    required double centerX,
  }) {
    if (metres == null) {
      return 1600;
    }
    final closeness = (1.0 - (metres / 3.2).clamp(0.0, 1.0));
    final centered = (1.0 - ((centerX - 0.5).abs() / 0.5).clamp(0.0, 1.0));
    final score = 0.55 * closeness + 0.45 * centered;
    return (1550 - score * 1250).round().clamp(280, 1550);
  }

  /// Walk-mode beep: only when the path is blocked and truly close.
  /// Interval slows as distance grows so open scenes stay quiet.
  Future<void> pingIfWithinMetre(double? metres, {bool pathBlocked = false}) async {
    if (_released || !pathBlocked || metres == null) {
      return;
    }
    // Box-size depth often underestimates — keep beeps for imminent only.
    if (metres > 0.5) {
      return;
    }
    final intervalMs = metres <= 0.35
        ? 1000
        : 1800;
    await _ping(
      interval: Duration(milliseconds: intervalMs),
      strongHaptic: metres <= 0.4,
    );
  }

  /// Find-mode cue: beep rate rises as the target nears the frame center.
  Future<void> pingForTarget({
    required double? metres,
    required double centerX,
  }) async {
    if (_released || metres == null || metres > 4.5) {
      return;
    }
    final ms = targetIntervalMs(metres: metres, centerX: centerX);
    await _ping(
      interval: Duration(milliseconds: ms),
      strongHaptic: metres <= 0.9 && (centerX - 0.5).abs() < 0.18,
    );
  }

  Future<void> _ping({
    required Duration interval,
    required bool strongHaptic,
  }) async {
    final now = DateTime.now();
    if (_last != null && now.difference(_last!) < interval) {
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
    if (strongHaptic) {
      await HapticFeedback.vibrate();
    }
  }

  Future<void> dispose() async {
    if (_released) {
      return;
    }
    _released = true;
    await _player.dispose();
  }
}
