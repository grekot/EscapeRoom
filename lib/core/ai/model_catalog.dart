import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'ai_errors.dart';

/// A model offered by a vendor's `models` endpoint.
class ModelInfo {
  const ModelInfo({required this.id, required this.label, this.isImage = false, this.description = ''});

  final String id;
  final String label;

  /// Generates images (Gemini "image" models) rather than text.
  final bool isImage;
  final String description;

  @override
  String toString() => id;
}

/// Live model lists so the settings screen never offers a retired model.
class ModelCatalog {
  ModelCatalog({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Gemini: `GET /v1beta/models` (paged). Keeps models that support
  /// `generateContent`; classifies image models by name.
  Future<List<ModelInfo>> gemini(String apiKey,
      {String baseUrl = 'https://generativelanguage.googleapis.com/v1beta'}) async {
    if (apiKey.trim().isEmpty) {
      throw AiException(AiErrorKind.noApiKey, 'Brak klucza Gemini.');
    }
    final out = <ModelInfo>[];
    String? token;
    do {
      final uri = Uri.parse('$baseUrl/models').replace(queryParameters: {
        'pageSize': '200',
        'pageToken': ?token,
      });
      final j = await _get(uri, {'x-goog-api-key': apiKey});
      for (final m in (j['models'] as List? ?? const [])) {
        final map = m as Map;
        final methods = (map['supportedGenerationMethods'] as List? ?? const []).cast<String>();
        if (!methods.contains('generateContent')) continue;
        final id = (map['name'] as String).replaceFirst('models/', '');
        final lower = id.toLowerCase();
        if (_excluded.any(lower.contains)) continue;
        final isImage = lower.contains('image') || lower.contains('nano-banana');
        // Text models: the Gemini family only (Gemma etc. lack JSON-schema output).
        if (!isImage && !lower.startsWith('gemini-')) continue;
        out.add(ModelInfo(
          id: id,
          label: (map['displayName'] as String?)?.trim().isNotEmpty == true
              ? map['displayName'] as String
              : id,
          isImage: isImage,
          description: (map['description'] as String?) ?? '',
        ));
      }
      token = j['nextPageToken'] as String?;
    } while (token != null && token.isNotEmpty);
    out.sort(_byRecency);
    return out;
  }

  /// Anthropic: `GET /v1/models` (paged via `after_id`).
  Future<List<ModelInfo>> anthropic(String apiKey,
      {String baseUrl = 'https://api.anthropic.com'}) async {
    if (apiKey.trim().isEmpty) {
      throw AiException(AiErrorKind.noApiKey, 'Brak klucza Anthropic.');
    }
    final out = <ModelInfo>[];
    String? after;
    do {
      final uri = Uri.parse('$baseUrl/v1/models').replace(queryParameters: {
        'limit': '100',
        'after_id': ?after,
      });
      final j = await _get(uri, {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      });
      final data = (j['data'] as List? ?? const []);
      for (final m in data) {
        final map = m as Map;
        final id = map['id'] as String;
        out.add(ModelInfo(id: id, label: (map['display_name'] as String?) ?? id));
      }
      after = (j['has_more'] == true && data.isNotEmpty) ? (j['last_id'] as String?) : null;
    } while (after != null);
    return out; // API already returns newest first
  }

  static const _excluded = [
    'embedding', 'tts', 'veo', 'live', 'audio', 'imagen', 'aqa', 'native-audio',
    'robotics', 'computer-use', 'transcribe', 'omni', 'customtools', 'deep-research',
    'antigravity', 'lyria', '-latest',
  ];

  /// Newest generation first: compares the leading version number in the id.
  static int _byRecency(ModelInfo a, ModelInfo b) {
    double ver(String id) {
      final m = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(id);
      return m == null ? 0 : double.tryParse(m.group(1)!) ?? 0;
    }
    final c = ver(b.id).compareTo(ver(a.id));
    return c != 0 ? c : a.id.compareTo(b.id);
  }

  Future<Map<String, dynamic>> _get(Uri uri, Map<String, String> headers) async {
    final http.Response res;
    try {
      res = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw AiException(AiErrorKind.timeout, 'Przekroczono czas oczekiwania.');
    } on SocketException catch (e) {
      throw AiException(AiErrorKind.network, e.message);
    } on http.ClientException catch (e) {
      throw AiException(AiErrorKind.network, e.message);
    }
    if (res.statusCode != 200) {
      String msg = 'HTTP ${res.statusCode}';
      try {
        final j = jsonDecode(utf8.decode(res.bodyBytes));
        if (j is Map && j['error'] is Map) msg = (j['error'] as Map)['message']?.toString() ?? msg;
      } catch (_) {}
      final kind = switch (res.statusCode) {
        401 || 403 => AiErrorKind.unauthorized,
        429 => AiErrorKind.rateLimited,
        >= 500 => AiErrorKind.server,
        _ => AiErrorKind.badRequest,
      };
      throw AiException(kind, msg, statusCode: res.statusCode, body: res.body);
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }
}
