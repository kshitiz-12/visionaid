import '../../../core/services/tts_service.dart';
import '../domain/guide_models.dart';

class VoiceAnnouncementQueue {
  VoiceAnnouncementQueue(this._tts);

  final TextToSpeechService _tts;
  bool _playing = false;

  bool get isPlaying => _playing;

  Future<void> submit(GuideAnnouncement next) async {
    if (_playing) {
      if (next.safetyOverride || next.speechPriority == SpeechPriority.critical) {
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
    } finally {
      _playing = false;
    }
  }

  Future<void> stop() => _tts.stop();
}
