import 'package:flutter_test/flutter_test.dart';
import 'package:visionaid/core/services/sentence_speech_queue.dart';
import 'package:visionaid/core/services/tts_service.dart';

class _OrderTts extends MockTextToSpeechService {
  final spoken = <String>[];

  @override
  Future<void> speak(
    String text, {
    bool interrupt = true,
    bool natural = false,
  }) async {
    spoken.add(text);
    await super.speak(text, interrupt: interrupt, natural: natural);
  }
}

void main() {
  test('FIFO queue speaks full sentences in order', () async {
    final tts = _OrderTts();
    final queue = SentenceSpeechQueue(tts);
    queue.enqueue('Chair ahead.');
    queue.enqueue('Person left.');
    await queue.waitIdle();
    expect(tts.spoken, ['Chair ahead.', 'Person left.']);
  });
}
