import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../exceptions/app_exception.dart';
import '../services/sentence_buffer.dart';
import '../services/speech_sanitizer.dart';

class CompanionReply {
  const CompanionReply({
    required this.text,
    required this.provider,
    required this.naturalVoice,
  });

  final String text;
  final String provider;
  final bool naturalVoice;
}

class CompanionClient {
  CompanionClient({String? baseUrl, http.Client? httpClient})
      : _baseUrl = (baseUrl ?? AppConfig.apiBaseUrl).replaceAll(RegExp(r'/$'), ''),
        _http = httpClient ?? http.Client();

  final String _baseUrl;
  final http.Client _http;
  DateTime? _lastWakeOk;
  DateTime? _skipCloudTtsUntil;
  Timer? _keepAlive;

  void startKeepAlive() {
    _keepAlive?.cancel();
    unawaited(wake(timeout: const Duration(seconds: 12)));
    _keepAlive = Timer.periodic(const Duration(minutes: 9), (_) {
      unawaited(wake(timeout: const Duration(seconds: 8)));
    });
  }

  void dispose() {
    _keepAlive?.cancel();
    _keepAlive = null;
  }

  /// Hits a cheap health route so Render is less likely to stall the first chat.
  Future<bool> wake({Duration timeout = const Duration(seconds: 8)}) async {
    if (_lastWakeOk != null &&
        DateTime.now().difference(_lastWakeOk!) < const Duration(minutes: 4)) {
      return true;
    }
    try {
      final response = await _http
          .get(Uri.parse('$_baseUrl/ping'))
          .timeout(timeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _lastWakeOk = DateTime.now();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<http.Response> _postChat(Map<String, dynamic> body, Duration timeout) {
    return _http
        .post(
          Uri.parse('$_baseUrl/api/assistant/chat'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(timeout);
  }

  Map<String, dynamic> _chatBody({
    required String message,
    required String language,
    required String userName,
    required String sceneSummary,
    required List<Map<String, String>> history,
    required String imageBase64,
  }) {
    return {
      'message': message,
      'language': language,
      'userName': userName,
      'sceneSummary': sceneSummary,
      'history': history.length > 4 ? history.sublist(history.length - 4) : history,
      if (imageBase64.isNotEmpty) 'imageBase64': imageBase64,
    };
  }

  Future<CompanionReply> chatStream({
    required String message,
    required String language,
    String userName = '',
    String sceneSummary = '',
    List<Map<String, String>> history = const [],
    String imageBase64 = '',
    void Function(String sentence)? onSentence,
  }) async {
    final body = _chatBody(
      message: message,
      language: language,
      userName: userName,
      sceneSummary: sceneSummary,
      history: history,
      imageBase64: imageBase64,
    );
    // Keep-alive already pings; never block the chat request on a second wake.
    unawaited(wake(timeout: const Duration(seconds: 8)));
    try {
      final request = http.Request(
        'POST',
        Uri.parse('$_baseUrl/api/assistant/chat/stream'),
      );
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
      });
      request.body = jsonEncode(body);
      final streamed = await _http.send(request).timeout(
            imageBase64.isNotEmpty
                ? const Duration(seconds: 26)
                : const Duration(seconds: 18),
          );
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        return chat(
          message: message,
          language: language,
          userName: userName,
          sceneSummary: sceneSummary,
          history: history,
          imageBase64: imageBase64,
        );
      }

      final sentences = SentenceBuffer();
      final full = StringBuffer();
      var buffer = '';
      try {
        await for (final chunk in streamed.stream
            .timeout(const Duration(seconds: 14))
            .transform(utf8.decoder)) {
          buffer += chunk;
          final blocks = buffer.split('\n\n');
          buffer = blocks.removeLast();
          for (final block in blocks) {
            final line = block
                .split('\n')
                .firstWhere((row) => row.startsWith('data:'), orElse: () => '');
            if (line.isEmpty) {
              continue;
            }
            final raw = line.substring(5).trim();
            if (raw.isEmpty) {
              continue;
            }
            Map<String, dynamic> event;
            try {
              event = jsonDecode(raw) as Map<String, dynamic>;
            } catch (_) {
              continue;
            }
            final err = event['error'] as String?;
            if (err != null && err.isNotEmpty) {
              throw AppException(err, code: 'AI_UPSTREAM');
            }
            final piece = event['text'] as String? ?? '';
            if (piece.isNotEmpty) {
              full.write(piece);
              for (final sentence in sentences.add(piece)) {
                onSentence?.call(SpeechSanitizer.clean(sentence));
              }
            }
          }
        }
      } on TimeoutException {
        if (full.isEmpty) {
          return chat(
            message: message,
            language: language,
            userName: userName,
            sceneSummary: sceneSummary,
            history: history,
            imageBase64: imageBase64,
          );
        }
      }
      final leftover = sentences.flush();
      if (leftover.isNotEmpty) {
        onSentence?.call(SpeechSanitizer.clean(leftover));
      }
      final text = SpeechSanitizer.clean(full.toString());
      if (text.isEmpty) {
        return chat(
          message: message,
          language: language,
          userName: userName,
          sceneSummary: sceneSummary,
          history: history,
          imageBase64: imageBase64,
        );
      }
      return CompanionReply(text: text, provider: 'gemini', naturalVoice: false);
    } on AppException {
      rethrow;
    } catch (_) {
      return chat(
        message: message,
        language: language,
        userName: userName,
        sceneSummary: sceneSummary,
        history: history,
        imageBase64: imageBase64,
      );
    }
  }

  Future<CompanionReply> chat({
    required String message,
    required String language,
    String userName = '',
    String sceneSummary = '',
    List<Map<String, String>> history = const [],
    String imageBase64 = '',
  }) async {
    final body = {
      'message': message,
      'language': language,
      'userName': userName,
      'sceneSummary': sceneSummary,
      'history': history.length > 4 ? history.sublist(history.length - 4) : history,
      if (imageBase64.isNotEmpty) 'imageBase64': imageBase64,
    };
    late http.Response response;
    unawaited(wake(timeout: const Duration(seconds: 8)));
    Future<http.Response> send(Duration timeout) => _postChat(body, timeout);
    final firstTimeout = imageBase64.isNotEmpty
        ? const Duration(seconds: 26)
        : const Duration(seconds: 18);
    try {
      response = await send(firstTimeout);
    } on TimeoutException {
      unawaited(wake(timeout: const Duration(seconds: 12)));
      try {
        response = await send(firstTimeout);
      } on TimeoutException {
        throw const AppException(
          'The assistant is slow right now. Call, emergency, and look ahead still work.',
          code: 'NETWORK_ERROR',
        );
      }
    } catch (error) {
      if (error is AppException) {
        rethrow;
      }
      unawaited(wake(timeout: const Duration(seconds: 10)));
      try {
        response = await send(firstTimeout);
      } catch (retryError) {
        if (retryError is AppException) {
          rethrow;
        }
        throw const AppException(
          'No internet to the assistant. Call, emergency, and look ahead still work.',
          code: 'NETWORK_ERROR',
        );
      }
    }

    Map<String, dynamic>? payload;
    if (response.body.isNotEmpty) {
      try {
        payload = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        payload = null;
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final messageText = payload?['message'] as String? ??
          'I could not reach the assistant.';
      final code = (payload?['error'] as Map<String, dynamic>?)?['code'] as String? ??
          'HTTP_${response.statusCode}';
      throw AppException(messageText, code: code);
    }

    final data = payload?['data'] as Map<String, dynamic>? ?? {};
    final text = (data['reply'] as String? ?? '').trim();
    if (text.isEmpty) {
      throw const AppException('Empty assistant reply', code: 'AI_EMPTY');
    }
    return CompanionReply(
      text: SpeechSanitizer.clean(text),
      provider: data['provider'] as String? ?? '',
      naturalVoice: data['naturalVoice'] as bool? ?? false,
    );
  }

  Future<Uint8List?> speakAudio({
    required String text,
    required String language,
  }) async {
    if (_skipCloudTtsUntil != null &&
        DateTime.now().isBefore(_skipCloudTtsUntil!)) {
      return null;
    }
    final uri = Uri.parse('$_baseUrl/api/assistant/speak');
    try {
      final response = await _http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'audio/mpeg',
            },
            body: jsonEncode({'text': text, 'language': language}),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 503) {
        _skipCloudTtsUntil = DateTime.now().add(const Duration(seconds: 45));
        return null;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      if (response.bodyBytes.isEmpty) {
        return null;
      }
      return response.bodyBytes;
    } catch (_) {
      _skipCloudTtsUntil = DateTime.now().add(const Duration(seconds: 20));
      return null;
    }
  }
}
