import '../../../core/services/tts_service.dart';
import '../domain/guide_models.dart';

class VoiceAnnouncementQueue {
  VoiceAnnouncementQueue(this._tts);

  final TextToSpeechService _tts;
  bool _playing = false;
  GuideAnnouncement? _pending;

  bool get isPlaying => _playing;

  Future<void> submit(GuideAnnouncement next) async {
    if (_playing) {
      if (next.safetyOverride || next.speechPriority == SpeechPriority.critical) {
        await _tts.stop();
        _pending = null;
      } else {
        final pending = _pending;
        if (pending == null || _rank(next) > _rank(pending)) {
          _pending = next;
        }
        return;
      }
    }
    await _play(next);
  }

  Future<void> _play(GuideAnnouncement item) async {
    _playing = true;
    try {
      await _tts.speak(item.spoken);
    } finally {
      _playing = false;
      final pending = _pending;
      _pending = null;
      if (pending != null) {
        await submit(pending);
      }
    }
  }

  int _rank(GuideAnnouncement a) {
    return switch (a.speechPriority) {
      SpeechPriority.critical => 4,
      SpeechPriority.high => 3,
      SpeechPriority.medium => 2,
      SpeechPriority.low => 1,
    };
  }

  Future<void> stop() => _tts.stop();
}
