import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

import '../core/services/tts_service.dart';

/// Priority tiers for the spatial audio manager.
enum AudioPriorityTier {
  /// Critical hazard — 0 ms delay, interrupts everything.
  critical,

  /// Navigation / spatial vector — 2.5 s cooldown + stereo cue.
  navVector,

  /// Ambient / Q&A — cancelled when Tier 1 or Tier 2 fires.
  ambient,
}

/// One utterance submitted to [PriorityAudio].
class PriorityUtterance {
  const PriorityUtterance({
    required this.tier,
    required this.text,
    this.angleXDegrees,
    this.id,
  });

  final AudioPriorityTier tier;
  final String text;

  /// Horizontal angle in degrees (−30…+30). Used for Tier 2 stereo balance.
  final double? angleXDegrees;
  final String? id;
}

/// Outcome of a successful [PriorityAudio.enqueue] that reached the speaker.
class PriorityAudioPlayResult {
  const PriorityAudioPlayResult({
    required this.tier,
    required this.text,
    required this.hapticApplied,
    required this.stereoBalance,
    required this.cancelledLowerTiers,
  });

  final AudioPriorityTier tier;
  final String text;
  final bool hapticApplied;

  /// −1.0 (full left) … +1.0 (full right). Null when unused.
  final double? stereoBalance;
  final bool cancelledLowerTiers;
}

class PriorityAudioException implements Exception {
  const PriorityAudioException(this.message, {this.code = 'PRIORITY_AUDIO'});

  final String message;
  final String code;

  @override
  String toString() => 'PriorityAudioException($code): $message';
}

class PriorityAudioConfigException extends PriorityAudioException {
  const PriorityAudioConfigException(super.message)
      : super(code: 'PRIORITY_AUDIO_CONFIG');
}

class PriorityAudioSpeakException extends PriorityAudioException {
  const PriorityAudioSpeakException(super.message)
      : super(code: 'PRIORITY_AUDIO_SPEAK');
}

class PriorityAudioHapticException extends PriorityAudioException {
  const PriorityAudioHapticException(super.message)
      : super(code: 'PRIORITY_AUDIO_HAPTIC');
}

class PriorityAudioStereoException extends PriorityAudioException {
  const PriorityAudioStereoException(super.message)
      : super(code: 'PRIORITY_AUDIO_STEREO');
}

class PriorityAudioCooldownSkip implements Exception {
  const PriorityAudioCooldownSkip(this.message);

  final String message;

  @override
  String toString() => 'PriorityAudioCooldownSkip: $message';
}

/// 3-tier priority audio manager for the spatial agent.
///
/// - **Tier 1 (critical):** immediate interrupt + haptic pattern + speak
/// - **Tier 2 (navVector):** 2.5 s cooldown; stereo-panned cue tone + speak
/// - **Tier 3 (ambient):** conversational TTS; cancelled by Tier 1 or 2
///
/// Note: `flutter_tts` has no stereo pan API. Tier 2 spatialization uses
/// [AudioPlayer.setBalance] on a short cue tone, then speaks via TTS.
class PriorityAudio {
  PriorityAudio({
    required TextToSpeechService tts,
    AudioPlayer? stereoPlayer,
    Duration navCooldown = const Duration(milliseconds: 2500),
    String stereoCueAsset = 'audio/proximity_beep.wav',
    List<int> criticalHapticPattern = const [0, 80, 60, 80, 60, 120],
  })  : _tts = tts,
        _stereoPlayer = stereoPlayer ?? AudioPlayer(),
        _navCooldown = navCooldown,
        _stereoCueAsset = stereoCueAsset,
        _criticalHapticPattern = List<int>.unmodifiable(criticalHapticPattern) {
    if (_navCooldown.isNegative) {
      throw const PriorityAudioConfigException(
        'navCooldown must not be negative.',
      );
    }
    if (_stereoCueAsset.trim().isEmpty) {
      throw const PriorityAudioConfigException(
        'stereoCueAsset must be a non-empty asset path.',
      );
    }
    if (_criticalHapticPattern.isEmpty) {
      throw const PriorityAudioConfigException(
        'criticalHapticPattern must not be empty.',
      );
    }
  }

  final TextToSpeechService _tts;
  final AudioPlayer _stereoPlayer;
  final Duration _navCooldown;
  final String _stereoCueAsset;
  final List<int> _criticalHapticPattern;

  Completer<void>? _gate;
  bool _speaking = false;
  AudioPriorityTier? _activeTier;
  DateTime? _lastNavAt;
  DateTime? _lastGeigerAt;
  bool _stereoReady = false;
  bool _disposed = false;
  bool _geigerBusy = false;

  bool get isSpeaking => _speaking;
  AudioPriorityTier? get activeTier => _activeTier;

  /// Enqueues [utterance] according to its tier rules.
  ///
  /// Tier 2 submissions inside the cooldown window throw
  /// [PriorityAudioCooldownSkip] (explicit, not silent).
  Future<PriorityAudioPlayResult> enqueue(PriorityUtterance utterance) async {
    _ensureAlive();
    final text = utterance.text.trim();
    if (text.isEmpty) {
      throw const PriorityAudioConfigException(
        'PriorityUtterance.text must be non-empty.',
      );
    }
    if (utterance.tier == AudioPriorityTier.navVector) {
      final angle = utterance.angleXDegrees;
      if (angle != null && (angle.isNaN || angle.isInfinite)) {
        throw const PriorityAudioConfigException(
          'navVector angleXDegrees must be finite when provided.',
        );
      }
    }

    switch (utterance.tier) {
      case AudioPriorityTier.critical:
        return _playCritical(text);
      case AudioPriorityTier.navVector:
        return _playNavVector(text, utterance.angleXDegrees);
      case AudioPriorityTier.ambient:
        return _playAmbient(text);
    }
  }

  Future<void> stopAll() async {
    _ensureAlive();
    try {
      await Vibration.cancel();
    } catch (_) {}
    try {
      await _stereoPlayer.stop();
    } catch (error, stack) {
      throw PriorityAudioStereoException(
        'Failed to stop stereo cue player: $error\n$stack',
      );
    }
    try {
      await _tts.stop();
    } catch (error, stack) {
      throw PriorityAudioSpeakException(
        'Failed to stop TTS: $error\n$stack',
      );
    }
    _speaking = false;
    _activeTier = null;
    final gate = _gate;
    if (gate != null && !gate.isCompleted) {
      gate.complete();
    }
    _gate = null;
  }

  /// TARGET_SEARCH geiger: vibration rate rises as [depthZMetres] shrinks and
  /// [angleXDegrees] approaches center (0°). No repetitive metre speech.
  ///
  /// Returns true when a pulse was fired.
  Future<bool> pulseTargetGeiger({
    required double depthZMetres,
    double angleXDegrees = 0,
  }) async {
    _ensureAlive();
    if (_geigerBusy) {
      return false;
    }
    if (depthZMetres.isNaN || depthZMetres.isInfinite || depthZMetres <= 0) {
      return false;
    }

    // Closer + more centered → shorter gap between pulses.
    final depthNorm = (depthZMetres.clamp(0.3, 5.0) - 0.3) / 4.7; // 0 near … 1 far
    final angleNorm = (angleXDegrees.abs() / 30.0).clamp(0.0, 1.0);
    final urgency = (1.0 - depthNorm) * 0.7 + (1.0 - angleNorm) * 0.3;
    final gapMs = (900 - urgency * 780).round().clamp(120, 900);

    final now = DateTime.now();
    if (_lastGeigerAt != null &&
        now.difference(_lastGeigerAt!).inMilliseconds < gapMs) {
      return false;
    }
    _lastGeigerAt = now;
    _geigerBusy = true;
    try {
      final duration = (40 + urgency * 100).round().clamp(40, 140);
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator) {
        await Vibration.vibrate(duration: duration);
      } else {
        if (urgency > 0.7) {
          await HapticFeedback.heavyImpact();
        } else if (urgency > 0.35) {
          await HapticFeedback.mediumImpact();
        } else {
          await HapticFeedback.lightImpact();
        }
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      _geigerBusy = false;
    }
  }

  /// Sparse spoken cue for target search (not continuous "1 metre" loops).
  String targetProximityHint({
    required String label,
    required double depthZMetres,
    required double angleXDegrees,
  }) {
    final name = label.trim().isEmpty ? 'target' : label.trim();
    final side = angleXDegrees.abs() < 6
        ? 'ahead'
        : (angleXDegrees < 0 ? 'left' : 'right');
    if (depthZMetres < 0.55) {
      return 'Stop. $name very close $side.';
    }
    if (depthZMetres < 1.2) {
      return '$name close, $side.';
    }
    if (depthZMetres < 2.5) {
      return '$name $side.';
    }
    return '$name farther $side.';
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    try {
      await _stereoPlayer.dispose();
    } catch (error, stack) {
      throw PriorityAudioStereoException(
        'Failed to dispose stereo cue player: $error\n$stack',
      );
    }
  }

  Future<PriorityAudioPlayResult> _playCritical(String text) async {
    final cancelledLower = _cancelLowerTiers(includingNav: true);
    await _interruptSpeechAndCue();
    // Speak first so a haptic failure never blocks the hazard announcement.
    await _speakNow(text, tier: AudioPriorityTier.critical);
    final hapticOk = await _fireCriticalHaptic();
    return PriorityAudioPlayResult(
      tier: AudioPriorityTier.critical,
      text: text,
      hapticApplied: hapticOk,
      stereoBalance: null,
      cancelledLowerTiers: cancelledLower,
    );
  }

  Future<PriorityAudioPlayResult> _playNavVector(
    String text,
    double? angleXDegrees,
  ) async {
    final now = DateTime.now();
    if (_lastNavAt != null && now.difference(_lastNavAt!) < _navCooldown) {
      final remaining =
          _navCooldown - now.difference(_lastNavAt!);
      throw PriorityAudioCooldownSkip(
        'Tier 2 navVector cooldown active '
        '(${remaining.inMilliseconds} ms remaining of '
        '${_navCooldown.inMilliseconds} ms).',
      );
    }

    final cancelledLower = _cancelLowerTiers(includingNav: false);
    if (_speaking && _activeTier == AudioPriorityTier.ambient) {
      await _interruptSpeechAndCue();
    }

    final balance = _balanceFromAngle(angleXDegrees);
    await _playStereoCue(balance);
    await _speakNow(text, tier: AudioPriorityTier.navVector);
    _lastNavAt = DateTime.now();
    return PriorityAudioPlayResult(
      tier: AudioPriorityTier.navVector,
      text: text,
      hapticApplied: false,
      stereoBalance: balance,
      cancelledLowerTiers: cancelledLower,
    );
  }

  Future<PriorityAudioPlayResult> _playAmbient(String text) async {
    // Serialize ambient behind any active speech.
    await _waitUntilIdle();
    if (_disposed) {
      throw const PriorityAudioConfigException(
        'PriorityAudio was disposed before ambient speech could play.',
      );
    }
    // Re-check: a higher tier may have been requested while waiting.
    if (_speaking &&
        (_activeTier == AudioPriorityTier.critical ||
            _activeTier == AudioPriorityTier.navVector)) {
      throw const PriorityAudioSpeakException(
        'Ambient utterance cancelled because a higher-tier utterance '
        'became active while waiting.',
      );
    }

    await _speakNow(text, tier: AudioPriorityTier.ambient);
    return PriorityAudioPlayResult(
      tier: AudioPriorityTier.ambient,
      text: text,
      hapticApplied: false,
      stereoBalance: null,
      cancelledLowerTiers: false,
    );
  }

  bool _cancelLowerTiers({required bool includingNav}) {
    final hadAmbient =
        _speaking && _activeTier == AudioPriorityTier.ambient;
    if (includingNav &&
        _speaking &&
        _activeTier == AudioPriorityTier.navVector) {
      return true;
    }
    return hadAmbient;
  }

  Future<void> _interruptSpeechAndCue() async {
    try {
      await _stereoPlayer.stop();
    } catch (error, stack) {
      throw PriorityAudioStereoException(
        'Failed to stop stereo cue during interrupt: $error\n$stack',
      );
    }
    try {
      await _tts.stop();
    } catch (error, stack) {
      throw PriorityAudioSpeakException(
        'Failed to stop TTS during interrupt: $error\n$stack',
      );
    }
    _speaking = false;
    _activeTier = null;
    final gate = _gate;
    if (gate != null && !gate.isCompleted) {
      gate.complete();
    }
    _gate = null;
  }

  Future<void> _speakNow(String text, {required AudioPriorityTier tier}) async {
    _speaking = true;
    _activeTier = tier;
    _gate = Completer<void>();
    try {
      await _tts.speak(text, interrupt: true);
    } catch (error, stack) {
      throw PriorityAudioSpeakException(
        'TTS failed for tier $tier: $error\n$stack',
      );
    } finally {
      _speaking = false;
      _activeTier = null;
      final gate = _gate;
      if (gate != null && !gate.isCompleted) {
        gate.complete();
      }
      _gate = null;
    }
  }

  Future<void> _waitUntilIdle() async {
    while (_speaking) {
      final gate = _gate;
      if (gate == null) {
        break;
      }
      await gate.future;
    }
  }

  Future<bool> _fireCriticalHaptic() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator) {
        final custom = await Vibration.hasCustomVibrationsSupport();
        if (custom) {
          await Vibration.vibrate(pattern: _criticalHapticPattern);
        } else {
          await Vibration.vibrate(duration: 180);
          await Future<void>.delayed(const Duration(milliseconds: 70));
          await Vibration.vibrate(duration: 180);
        }
        return true;
      }
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await HapticFeedback.vibrate();
      return true;
    } catch (error, stack) {
      throw PriorityAudioHapticException(
        'Critical haptic pattern failed: $error\n$stack',
      );
    }
  }

  double _balanceFromAngle(double? angleXDegrees) {
    if (angleXDegrees == null) {
      return 0.0;
    }
    // Map −30…+30 → −1…+1.
    final normalized = (angleXDegrees / 30.0).clamp(-1.0, 1.0);
    return normalized.toDouble();
  }

  Future<void> _playStereoCue(double balance) async {
    if (balance.isNaN || balance.isInfinite) {
      throw PriorityAudioStereoException(
        'Stereo balance must be finite (got $balance).',
      );
    }
    final clamped = balance.clamp(-1.0, 1.0).toDouble();
    try {
      await _ensureStereoPlayer();
      await _stereoPlayer.stop();
      await _stereoPlayer.setBalance(clamped);
      await _stereoPlayer.setVolume(math.min(1.0, 0.55 + clamped.abs() * 0.45));
      await _stereoPlayer.play(AssetSource(_stereoCueAsset));
    } catch (error, stack) {
      if (error is PriorityAudioException) {
        rethrow;
      }
      throw PriorityAudioStereoException(
        'Failed to play stereo nav cue (balance=$clamped): $error\n$stack',
      );
    }
  }

  Future<void> _ensureStereoPlayer() async {
    if (_stereoReady) {
      return;
    }
    try {
      await _stereoPlayer.setReleaseMode(ReleaseMode.stop);
      await _stereoPlayer.setPlayerMode(PlayerMode.lowLatency);
      await _stereoPlayer.setAudioContext(
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
      _stereoReady = true;
    } catch (error, stack) {
      throw PriorityAudioStereoException(
        'Failed to configure stereo cue player: $error\n$stack',
      );
    }
  }

  void _ensureAlive() {
    if (_disposed) {
      throw const PriorityAudioConfigException(
        'PriorityAudio has been disposed.',
      );
    }
  }
}
