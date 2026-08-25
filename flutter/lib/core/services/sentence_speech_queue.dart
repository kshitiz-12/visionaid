import 'dart:async';
import 'dart:collection';

import 'speech_sanitizer.dart';
import 'tts_service.dart';

/// FIFO spoken-sentence queue. Never pass raw SSE tokens into TTS.
class SentenceSpeechQueue {
  SentenceSpeechQueue(this._tts);

  final TextToSpeechService _tts;
  final Queue<String> _pending = Queue<String>();
  bool _draining = false;
  bool _stopped = false;
  Completer<void>? _idle;

  bool get isSpeaking => _draining || _pending.isNotEmpty;

  void enqueue(String sentence) {
    final spoken = SpeechSanitizer.clean(sentence);
    if (spoken.isEmpty || _stopped) {
      return;
    }
    _pending.add(spoken);
    _idle ??= Completer<void>();
    unawaited(_pump());
  }

  Future<void> waitIdle() async {
    final idle = _idle;
    if (idle == null || idle.isCompleted) {
      if (!_draining && _pending.isEmpty) {
        return;
      }
    }
    await (_idle?.future ?? Future<void>.value());
  }

  Future<void> stop() async {
    _stopped = true;
    _pending.clear();
    await _tts.stop();
    _finishIdle();
    _stopped = false;
  }

  Future<void> _pump() async {
    if (_draining) {
      return;
    }
    _draining = true;
    try {
      while (_pending.isNotEmpty && !_stopped) {
        final next = _pending.removeFirst();
        await _tts.speak(next, interrupt: false, natural: false);
      }
    } finally {
      _draining = false;
      if (_pending.isEmpty || _stopped) {
        _finishIdle();
      } else {
        unawaited(_pump());
      }
    }
  }

  void _finishIdle() {
    final idle = _idle;
    _idle = null;
    if (idle != null && !idle.isCompleted) {
      idle.complete();
    }
  }
}
