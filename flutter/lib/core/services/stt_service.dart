abstract class SpeechToTextService {
  Future<String> listen();
}

class MockSpeechToTextService implements SpeechToTextService {
  @override
  Future<String> listen() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return 'Emergency';
  }
}
