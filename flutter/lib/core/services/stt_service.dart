import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

abstract class SpeechToTextService {
  Future<bool> initialize();
  Future<String> listen({
    Duration timeout = const Duration(seconds: 12),
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
  String? _resolvedLocale;

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
      options: [SpeechToText.androidNoBluetooth],
    );
    return _initialized && _speech.isAvailable;
  }

  @override
  Future<String> listen({
    Duration timeout = const Duration(seconds: 12),
    String? localeId,
  }) async {
    final ready = await initialize();
    if (!ready) {
      _initialized = false;
      throw StateError(
        'Speech recognition is not available. Install Google Speech Services and try again.',
      );
    }

    if (_speech.isListening) {
      await _speech.stop();
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    final locale = await _resolveLocale(localeId);
    var heard = await _listenOnce(timeout: timeout, localeId: locale);
    if (heard.isNotEmpty) {
      _resolvedLocale = locale;
      return heard;
    }

    if (_shouldRetry(_lastError)) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (_speech.isListening) {
        await _speech.stop();
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      heard = await _listenOnce(timeout: timeout, localeId: locale);
      if (heard.isNotEmpty) {
        _resolvedLocale = locale;
        return heard;
      }
    }

    throw StateError(_messageForError(_lastError));
  }

  bool _shouldRetry(String error) {
    final hint = error.toLowerCase();
    return hint.isEmpty ||
        hint.contains('no_match') ||
        hint.contains('speech_timeout') ||
        hint.contains('busy') ||
        hint.contains('client') ||
        hint.contains('error_retry');
  }

  String _messageForError(String error) {
    final hint = error.toLowerCase();
    if (hint.contains('permission')) {
      return 'I cannot use the microphone. Allow microphone permission and try again.';
    }
    if (hint.contains('network') || hint.contains('server')) {
      return 'Speech needs a brief internet connection on this phone. Check data or Wi‑Fi.';
    }
    if (hint.contains('busy')) {
      return 'The microphone was busy. Tap the mic and speak after a short pause.';
    }
    if (hint.contains('language')) {
      return 'This phone is missing that speech language. Install it in system settings, then try again.';
    }
    return 'I missed that. Tap the mic, wait a moment, then speak.';
  }

  Future<String?> _resolveLocale(String? preferred) async {
    if (_resolvedLocale != null &&
        (preferred == null || _sameLanguage(_resolvedLocale!, preferred))) {
      return _resolvedLocale;
    }
    try {
      final available = await _speech.locales();
      if (available.isEmpty) {
        return (await _speech.systemLocale())?.localeId ?? preferred;
      }
      if (preferred != null) {
        final wanted = _normalize(preferred);
        for (final item in available) {
          if (_normalize(item.localeId) == wanted) {
            return item.localeId;
          }
        }
        final prefix = wanted.split('_').first;
        for (final item in available) {
          if (_normalize(item.localeId).startsWith('${prefix}_') ||
              _normalize(item.localeId) == prefix) {
            return item.localeId;
          }
        }
      }
      return (await _speech.systemLocale())?.localeId ??
          available.first.localeId;
    } catch (_) {
      return preferred;
    }
  }

  String _normalize(String id) =>
      id.trim().toLowerCase().replaceAll('-', '_');

  bool _sameLanguage(String a, String b) =>
      _normalize(a).split('_').first == _normalize(b).split('_').first;

  Future<String> _listenOnce({
    required Duration timeout,
    required String? localeId,
  }) async {
    _lastError = '';
    var transcript = '';
    var lastHeardAt = DateTime.now();
    var gotFinal = false;
    var shortenedPause = false;

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
          } else if (!shortenedPause) {
            shortenedPause = true;
            try {
              _speech.changePauseFor(const Duration(milliseconds: 1400));
            } catch (_) {}
          }
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.confirmation,
          partialResults: true,
          cancelOnError: false,
          listenFor: timeout,
          pauseFor: const Duration(seconds: 4),
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
              const Duration(milliseconds: 700)) {
        break;
      }
      if (!_speech.isListening && transcript.isNotEmpty) {
        break;
      }
      if (!_speech.isListening &&
          transcript.isEmpty &&
          _lastError.isNotEmpty) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
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
    Duration timeout = const Duration(seconds: 12),
    String? localeId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return 'Emergency';
  }

  @override
  Future<void> stop() async {}
}
