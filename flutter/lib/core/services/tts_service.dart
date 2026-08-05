abstract class TextToSpeechService {
  Future<void> speak(String text);
}

class MockTextToSpeechService implements TextToSpeechService {
  @override
  Future<void> speak(String text) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // In production this would call Android TTS or a platform channel.
    // Intentionally no console output to keep production logs clean.
    if (text.isEmpty) {
      throw StateError('Text to speak cannot be empty');
    }
  }
}
