import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'ai_errors.dart';
import 'ai_provider.dart';

/// Raw HTTP client for the Gemini API (`generateContent`).
class GeminiProvider implements AiProvider {
  GeminiProvider({
    required this.apiKey,
    this.model = defaultModel,
    http.Client? client,
    this.baseUrl = 'https://generativelanguage.googleapis.com/v1beta',
  }) : _client = client ?? http.Client();

  static const defaultModel = 'gemini-3.8-flash';

  static const models = <String, String>{
    'gemini-3.8-flash': 'Gemini 3.8 Flash (domyślny, darmowy tier)',
    'gemini-3.1-pro-preview': 'Gemini 3.1 Pro (mocniejszy, preview)',
    'gemini-3.5-flash-lite': 'Gemini 3.5 Flash Lite (najtańszy)',
  };

  final String apiKey;
  @override
  final String model;
  final String baseUrl;
  final http.Client _client;

  @override
  String get id => 'gemini';

  Map<String, String> _headers() => {
        'content-type': 'application/json',
        'x-goog-api-key': apiKey,
      };

  @override
  Future<Map<String, dynamic>> completeJson({
    required String system,
    required String user,
    required Map<String, dynamic> schema,
    int maxTokens = 16000,
    Duration timeout = const Duration(seconds: 180),
  }) async {
    final body = <String, dynamic>{
      'systemInstruction': {
        'parts': [
          {'text': system},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': user},
          ],
        },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseJsonSchema': schema,
        'maxOutputTokens': maxTokens,
      },
    };
    final text = await withRetry(() => _generate(body, timeout));
    return parseJsonObject(text);
  }

  @override
  Future<String> chat({
    required String system,
    required List<ChatMessage> history,
    int maxTokens = 1024,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final body = <String, dynamic>{
      'systemInstruction': {
        'parts': [
          {'text': system},
        ],
      },
      'contents': [
        for (final m in history)
          {
            'role': m.role == 'assistant' ? 'model' : 'user',
            'parts': [
              {'text': m.text},
            ],
          },
      ],
      'generationConfig': {'maxOutputTokens': maxTokens},
    };
    return withRetry(() => _generate(body, timeout));
  }

  /// Minimal real request to the selected model, so a bad key *or* a retired
  /// model is reported right away.
  @override
  Future<void> ping() async {
    if (apiKey.trim().isEmpty) {
      throw AiException(AiErrorKind.noApiKey, 'Brak klucza Gemini.');
    }
    await _generate({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': 'Odpowiedz jednym słowem: OK'},
          ],
        },
      ],
      'generationConfig': {'maxOutputTokens': 8},
    }, const Duration(seconds: 30));
  }

  Future<String> _generate(Map<String, dynamic> body, Duration timeout) async {
    if (apiKey.trim().isEmpty) {
      throw AiException(AiErrorKind.noApiKey, 'Brak klucza Gemini.');
    }
    final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse('$baseUrl/models/$model:generateContent'),
            headers: _headers(),
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw AiException(AiErrorKind.timeout, 'Przekroczono czas oczekiwania.');
    } on SocketException catch (e) {
      throw AiException(AiErrorKind.network, e.message);
    } on http.ClientException catch (e) {
      throw AiException(AiErrorKind.network, e.message);
    }
    if (res.statusCode != 200) _throwForStatus(res);

    final Map<String, dynamic> j;
    try {
      j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      throw AiException(AiErrorKind.badJson, 'Niepoprawna odpowiedź serwera.',
          body: res.body);
    }
    final feedback = j['promptFeedback'];
    if (feedback is Map && feedback['blockReason'] != null) {
      throw AiException(
          AiErrorKind.refusal, 'Zablokowano: ${feedback['blockReason']}');
    }
    final candidates = j['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw AiException(AiErrorKind.refusal, 'Model nie zwrócił odpowiedzi.',
          body: res.body);
    }
    final c = candidates.first as Map;
    final finish = c['finishReason']?.toString();
    final sb = StringBuffer();
    final content = c['content'];
    if (content is Map && content['parts'] is List) {
      for (final p in content['parts'] as List) {
        if (p is Map && p['text'] != null && p['thought'] != true) {
          sb.write(p['text']);
        }
      }
    }
    if (finish == 'SAFETY' || finish == 'PROHIBITED_CONTENT' ||
        finish == 'BLOCKLIST' || finish == 'SPII') {
      throw AiException(AiErrorKind.refusal, 'Zablokowano: $finish');
    }
    if (finish == 'MAX_TOKENS') {
      throw AiException(AiErrorKind.truncated, 'Odpowiedź ucięta (MAX_TOKENS).',
          body: sb.toString());
    }
    return sb.toString();
  }

  Never _throwForStatus(http.Response res) {
    String msg = res.reasonPhrase ?? 'HTTP ${res.statusCode}';
    try {
      final j = jsonDecode(utf8.decode(res.bodyBytes));
      if (j is Map && j['error'] is Map) {
        msg = (j['error'] as Map)['message']?.toString() ?? msg;
      }
    } catch (_) {}
    final kind = switch (res.statusCode) {
      401 || 403 => AiErrorKind.unauthorized,
      429 => AiErrorKind.rateLimited,
      400 || 404 => AiErrorKind.badRequest,
      >= 500 => AiErrorKind.server,
      _ => AiErrorKind.unknown,
    };
    throw AiException(kind, msg, statusCode: res.statusCode, body: res.body);
  }
}
