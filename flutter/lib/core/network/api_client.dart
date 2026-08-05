import 'dart:convert';

import 'package:http/http.dart' as http;

import '../exceptions/app_exception.dart';

class ApiClient {
  const ApiClient({required this.baseUrl});

  final String baseUrl;

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...?headers,
      },
      body: body == null ? null : jsonEncode(body),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw AppException(
      'Request failed with status ${response.statusCode}',
      code: 'HTTP_${response.statusCode}',
    );
  }
}
