import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../exceptions/app_exception.dart';

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

  /// Hits a cheap health route so Render is less likely to stall the first chat.
  Future<bool> wake({Duration timeout = const Duration(seconds: 8)}) async {
    if (_lastWakeOk != null &&
        DateTime.now().difference(_lastWakeOk!) < const Duration(minutes: 4)) {
      return true;
    }
    try {
      final response = await _http
          .get(Uri.parse('$_baseUrl/api/health'))
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
    try {
      response = await _postChat(
        body,
        imageBase64.isNotEmpty
            ? const Duration(seconds: 18)
            : const Duration(seconds: 10),
      );
    } on TimeoutException {
      throw const AppException(
        'The assistant is slow right now. Call, emergency, and look ahead still work.',
        code: 'NETWORK_ERROR',
      );
    } catch (error) {
      if (error is AppException) {
        rethrow;
      }
      throw const AppException(
        'No internet to the assistant. Call, emergency, and look ahead still work.',
        code: 'NETWORK_ERROR',
      );
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
      text: text,
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
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 503) {
        _skipCloudTtsUntil = DateTime.now().add(const Duration(minutes: 5));
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
      _skipCloudTtsUntil = DateTime.now().add(const Duration(minutes: 3));
      return null;
    }
  }
}
