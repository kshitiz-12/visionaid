import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

abstract class SpeechToTextService {
  Future<bool> initialize();
  Future<String> listen({
    Duration timeout = const Duration(seconds: 6),
    String? localeId,
  });
  Future<void> stop();
}

class AndroidSpeechToTextService implements SpeechToTextService {
  AndroidSpeechToTextService({SpeechToText? speech})
      : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  bool _initialized = false;
  String _lastError = '';
  String? _cachedLocale;

  @override
  Future<bool> initialize() async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      throw StateError(
        'Microphone permission is required. Enable it in settings, then try again.',
      );
    }

    if (_initialized && _speech.isAvailable) {
      return true;
    }

    _initialized = await _speech.initialize(
      onError: (error) {
        _lastError = error.errorMsg;
        debugPrintStt('STT error: ${error.errorMsg}');
      },
      onStatus: (status) => debugPrintStt('STT status: $status'),
    );
    return _initialized && _speech.isAvailable;
  }

  @override
  Future<String> listen({
    Duration timeout = const Duration(seconds: 6),
    String? localeId,
  }) async {
    final ready = await initialize();
    if (!ready) {
      _initialized = false;
      throw StateError(
        'Speech recognition is not available. Install Google Speech and check the microphone.',
      );
    }

    if (_speech.isListening) {
      await _speech.stop();
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }

    final locale = _cachedLocale ?? localeId;
    final heard = await _listenOnce(timeout: timeout, localeId: locale);
    if (heard.isNotEmpty) {
      _cachedLocale = locale;
      return heard;
    }

    final hint = _lastError.toLowerCase();
    if (hint.contains('permission')) {
      throw StateError(
        'I cannot use the microphone. Allow microphone permission and try again.',
      );
    }
    if (hint.contains('network') || hint.contains('client')) {
      throw StateError(
        'Speech needs a brief internet connection on this phone. Check data or Wi‑Fi.',
      );
    }
    throw StateError('I could not hear you. Tap the mic and speak clearly.');
  }

  Future<String> _listenOnce({
    required Duration timeout,
    required String? localeId,
  }) async {
    _lastError = '';
    var transcript = '';
    var lastHeardAt = DateTime.now();
    var gotFinal = false;

    try {
      await _speech.listen(
        onResult: (result) {
          final words = result.recognizedWords.trim();
          if (words.isEmpty) {
            return;
          }
          transcript = words;
          lastHeardAt = DateTime.now();
          if (result.finalResult) {
            gotFinal = true;
          }
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
          listenFor: timeout,
          pauseFor: const Duration(milliseconds: 900),
          localeId: localeId,
        ),
      );
    } catch (_) {
      if (_speech.isListening) {
        await _speech.cancel();
      }
      throw StateError('I could not start listening. Try again.');
    }

    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (gotFinal && transcript.isNotEmpty) {
        break;
      }
      if (transcript.isNotEmpty &&
          DateTime.now().difference(lastHeardAt) >=
              const Duration(milliseconds: 450)) {
        break;
      }
      if (!_speech.isListening && transcript.isNotEmpty) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }

    if (_speech.isListening) {
      await _speech.stop();
    }

    return transcript.trim();
  }

  @override
  Future<void> stop() => _speech.stop();
}

void debugPrintStt(String message) {
  // ignore: avoid_print
  print(message);
}

class MockSpeechToTextService implements SpeechToTextService {
  @override
  Future<bool> initialize() async => true;

  @override
  Future<String> listen({
    Duration timeout = const Duration(seconds: 6),
    String? localeId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return 'Emergency';
  }

  @override
  Future<void> stop() async {}
}
