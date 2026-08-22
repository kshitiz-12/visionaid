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

  Future<CompanionReply> chat({
    required String message,
    required String language,
    String userName = '',
    String sceneSummary = '',
    List<Map<String, String>> history = const [],
  }) async {
    final uri = Uri.parse('$_baseUrl/api/assistant/chat');
    late http.Response response;
    try {
      response = await _http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'message': message,
              'language': language,
              'userName': userName,
              'sceneSummary': sceneSummary,
              'history': history,
            }),
          )
          .timeout(const Duration(seconds: 90));
    } on TimeoutException {
      throw const AppException(
        'The server is waking up. Wait a few seconds and ask again.',
        code: 'NETWORK_ERROR',
      );
    } catch (_) {
      throw const AppException(
        'Network request failed. Check your connection.',
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
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 503) {
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
      return null;
    }
  }
}
