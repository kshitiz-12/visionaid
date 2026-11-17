import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class CommandResult {
  CommandResult({
    required this.spoken,
    this.intentType,
    this.pending,
    this.ok = true,
  });

  final String spoken;
  final String? intentType;
  final Map<String, dynamic>? pending;
  final bool ok;
}

class ApiClient {
  ApiClient(this.baseUrl);

  String baseUrl;

  Uri _u(String path) => Uri.parse('$baseUrl$path');

  Future<Map<String, dynamic>> health() async {
    final res = await http.get(_u('/api/health')).timeout(
          const Duration(seconds: 6),
        );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> startBrowser() async {
    await http.post(_u('/api/browser/start')).timeout(
          const Duration(seconds: 90),
        );
  }

  Future<CommandResult> command(String spoken, {String? pdfText}) async {
    final res = await http
        .post(
          _u('/api/command'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'spoken': spoken,
            if (pdfText != null && pdfText.isNotEmpty) 'pdfText': pdfText,
          }),
        )
        .timeout(const Duration(seconds: 180));
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return CommandResult(
      ok: json['ok'] != false && res.statusCode < 400,
      spoken: (json['spoken'] as String?)?.trim().isNotEmpty == true
          ? json['spoken'] as String
          : 'No spoken reply.',
      intentType: (json['intent'] as Map?)?['type'] as String?,
      pending: json['pending'] as Map<String, dynamic>?,
    );
  }

  Future<CommandResult> summarizePdfBytes({
    required List<int> bytes,
    required String filename,
  }) async {
    final req = http.MultipartRequest('POST', _u('/api/pdf/summarize'));
    req.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: filename.toLowerCase().endsWith('.pdf')
            ? MediaType('application', 'pdf')
            : MediaType('text', 'plain'),
      ),
    );
    final streamed = await req.send().timeout(const Duration(seconds: 180));
    final body = await streamed.stream.bytesToString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    return CommandResult(
      ok: json['ok'] == true,
      spoken: (json['spoken'] as String?) ?? 'No summary.',
    );
  }

  Uri screenshotUri(int tick) => _u('/api/screenshot').replace(
        queryParameters: {'t': '$tick'},
      );
}
