import 'package:flutter/services.dart';

/// Immediate close-range cue. No network. No TTS wait.
class HazardCue {
  DateTime? _last;

  Future<void> pingIfWithinMetre(double? metres) async {
    if (metres == null || metres > 1.0) {
      return;
    }
    final now = DateTime.now();
    if (_last != null && now.difference(_last!) < const Duration(milliseconds: 750)) {
      return;
    }
    _last = now;
    await HapticFeedback.heavyImpact();
    await SystemSound.play(SystemSoundType.click);
    if (metres <= 0.6) {
      await HapticFeedback.vibrate();
    }
  }
}
