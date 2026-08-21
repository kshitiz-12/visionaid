import 'package:speech_to_text/speech_to_text.dart';

abstract class SpeechToTextService {
  Future<bool> initialize();
  Future<String> listen({Duration timeout = const Duration(seconds: 8)});
  Future<void> stop();
}

class AndroidSpeechToTextService implements SpeechToTextService {
  AndroidSpeechToTextService({SpeechToText? speech})
      : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  bool _initialized = false;

  @override
  Future<bool> initialize() async {
    if (_initialized) {
      return _speech.isAvailable;
    }
    _initialized = await _speech.initialize();
    return _initialized;
  }

  @override
  Future<String> listen({Duration timeout = const Duration(seconds: 8)}) async {
    final ready = await initialize();
    if (!ready) {
      throw StateError('Speech recognition is not available on this device.');
    }

    var transcript = '';
    await _speech.listen(
      onResult: (result) {
        transcript = result.recognizedWords;
      },
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.confirmation,
        partialResults: true,
        cancelOnError: true,
      ),
      listenFor: timeout,
      pauseFor: const Duration(seconds: 3),
    );

    final deadline = DateTime.now().add(timeout + const Duration(seconds: 2));
    while (_speech.isListening && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    await _speech.stop();

    final text = transcript.trim();
    if (text.isEmpty) {
      throw StateError('I did not catch that. Please try again.');
    }
    return text;
  }

  @override
  Future<void> stop() => _speech.stop();
}

class MockSpeechToTextService implements SpeechToTextService {
  @override
  Future<bool> initialize() async => true;

  @override
  Future<String> listen({Duration timeout = const Duration(seconds: 8)}) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return 'Emergency';
  }

  @override
  Future<void> stop() async {}
}
