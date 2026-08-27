import '../../../core/services/tts_service.dart';
import '../domain/guide_models.dart';

class VoiceAnnouncementQueue {
  VoiceAnnouncementQueue(this._tts);

  final TextToSpeechService _tts;
  bool _playing = false;
  String _lastSpoken = '';
  DateTime? _lastAt;

  bool get isPlaying => _playing;

  Future<void> submit(GuideAnnouncement next) async {
    final now = DateTime.now();
    if (_lastSpoken == next.spoken &&
        _lastAt != null &&
        now.difference(_lastAt!) < const Duration(seconds: 4)) {
      return;
    }
    if (_playing) {
      if (next.safetyOverride || next.speechPriority == SpeechPriority.critical) {
        if (_lastAt != null &&
            now.difference(_lastAt!) < const Duration(milliseconds: 2200)) {
          return;
        }
        await _tts.stop();
      } else {
        return;
      }
    }
    await _play(next);
  }

  Future<void> _play(GuideAnnouncement item) async {
    _playing = true;
    try {
      await _tts.speak(item.spoken);
      _lastSpoken = item.spoken;
      _lastAt = DateTime.now();
    } finally {
      _playing = false;
    }
  }

  Future<void> stop() => _tts.stop();
}
