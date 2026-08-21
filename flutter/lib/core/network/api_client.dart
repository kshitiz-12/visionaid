import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../exceptions/app_exception.dart';
import '../services/supabase_service.dart';

class ApiClient {
  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final String baseUrl;

  Future<Map<String, dynamic>> get(String path) {
    return _request('GET', path);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) {
    return _request('PATCH', path, body: body);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) {
    return _request('POST', path, body: body);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final token = await _accessToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    late http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await http.get(uri, headers: headers);
          break;
        case 'PATCH':
          response = await http.patch(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          );
          break;
        case 'POST':
          response = await http.post(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          );
          break;
        default:
          throw const AppException('Unsupported HTTP method', code: 'HTTP_METHOD');
      }
    } catch (error) {
      if (error is AppException) {
        rethrow;
      }
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

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return payload ?? <String, dynamic>{};
    }

    final message = payload?['message'] as String? ??
        'Request failed with status ${response.statusCode}';
    final code = (payload?['error'] as Map<String, dynamic>?)?['code'] as String? ??
        'HTTP_${response.statusCode}';

    throw AppException(message, code: code);
  }

  Future<String?> _accessToken() async {
    if (!AppConfig.isSupabaseConfigured) {
      return null;
    }
    return SupabaseService.client.auth.currentSession?.accessToken;
  }
}
