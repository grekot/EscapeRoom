import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'ai_errors.dart';
import 'ai_provider.dart';

/// Raw HTTP client for the Anthropic Messages API.
///
/// No official Dart SDK exists, so this speaks the wire format directly:
/// `POST /v1/messages` with `x-api-key` + `anthropic-version` headers.
class AnthropicProvider implements AiProvider {
  AnthropicProvider({
    required this.apiKey,
    this.model = defaultModel,
    http.Client? client,
    this.baseUrl = 'https://api.anthropic.com',
  }) : _client = client ?? http.Client();

  static const defaultModel = 'claude-opus-5';

  /// Models offered in settings (id → label).
  static const models = <String, String>{
    'claude-opus-5': 'Claude Opus 5 (domyślny)',
    'claude-sonnet-5': 'Claude Sonnet 5 (tańszy, szybszy)',
    'claude-fable-5-1': 'Claude Fable 5.1 (najmocniejszy, drogi)',
    'claude-haiku-4-5': 'Claude Haiku 4.5 (najtańszy)',
  };

  final String apiKey;
  @override
  final String model;
  final String baseUrl;
  final http.Client _client;

  @override
  String get id => 'anthropic';

  bool get _supportsEffort =>
      model.startsWith('claude-opus-5') ||
      model.startsWith('claude-sonnet-5') ||
      model.startsWith('claude-fable') ||
      model.startsWith('claude-opus-4-') ||
      model.startsWith('claude-sonnet-4-6');

  /// Server-side refusal fallbacks are only defined for Opus 5 / Fable.
  bool get _useFallbacks =>
      model.startsWith('claude-opus-5') || model.startsWith('claude-fable');

  Map<String, String> _headers() => {
        'content-type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        if (_useFallbacks) 'anthropic-beta': 'server-side-fallback-2026-07-01',
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
      'model': model,
      'max_tokens': maxTokens,
      'system': system,
      'messages': [
        {'role': 'user', 'content': user},
      ],
      'output_config': {
        'format': {'type': 'json_schema', 'schema': schema},
        if (_supportsEffort) 'effort': 'medium',
      },
      if (_useFallbacks) 'fallbacks': 'default',
    };
    final text = await withRetry(() => _messages(body, timeout));
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
      'model': model,
      'max_tokens': maxTokens,
      'system': system,
      'messages': [
        for (final m in history) {'role': m.role, 'content': m.text},
      ],
      if (_supportsEffort) 'output_config': {'effort': 'low'},
      if (_useFallbacks) 'fallbacks': 'default',
    };
    return withRetry(() => _messages(body, timeout));
  }

  /// Minimal real request to the selected model, so a bad key *or* a retired
  /// model is reported right away.
  @override
  Future<void> ping() async {
    if (apiKey.trim().isEmpty) {
      throw AiException(AiErrorKind.noApiKey, 'Brak klucza Anthropic.');
    }
    await _messages({
      'model': model,
      'max_tokens': 8,
      'messages': [
        {'role': 'user', 'content': 'Odpowiedz jednym słowem: OK'},
      ],
    }, const Duration(seconds: 30));
  }

  /// Sends one Messages request and returns concatenated text blocks.
  Future<String> _messages(Map<String, dynamic> body, Duration timeout) async {
    if (apiKey.trim().isEmpty) {
      throw AiException(AiErrorKind.noApiKey, 'Brak klucza Anthropic.');
    }
    final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse('$baseUrl/v1/messages'),
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
    final stop = j['stop_reason']?.toString();
    if (stop == 'refusal') {
      final details = j['stop_details'];
      final why = details is Map ? details['explanation']?.toString() : null;
      throw AiException(AiErrorKind.refusal, why ?? 'Model odmówił.');
    }
    final content = j['content'];
    final sb = StringBuffer();
    if (content is List) {
      for (final block in content) {
        if (block is Map && block['type'] == 'text') {
          sb.write(block['text'] ?? '');
        }
      }
    }
    if (stop == 'max_tokens') {
      throw AiException(AiErrorKind.truncated, 'Odpowiedź ucięta (max_tokens).',
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
      400 || 404 || 413 || 422 => AiErrorKind.badRequest,
      529 => AiErrorKind.rateLimited,
      >= 500 => AiErrorKind.server,
      _ => AiErrorKind.unknown,
    };
    throw AiException(kind, msg, statusCode: res.statusCode, body: res.body);
  }
}
