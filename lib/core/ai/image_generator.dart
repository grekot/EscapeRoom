import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'ai_errors.dart';

/// Text-to-image. Only Gemini offers this; Anthropic models do not generate
/// images, so the Gemini key is used for illustrations regardless of the
/// text vendor.
abstract class ImageGenerator {
  String get model;
  Future<Uint8List> generate(String prompt, {String aspectRatio = '16:9'});
}

class GeminiImageGenerator implements ImageGenerator {
  GeminiImageGenerator({
    required this.apiKey,
    this.model = defaultModel,
    http.Client? client,
    this.baseUrl = 'https://generativelanguage.googleapis.com/v1beta',
  }) : _client = client ?? http.Client();

  static const defaultModel = 'gemini-3.1-flash-lite-image';

  static const models = <String, String>{
    'gemini-3.1-flash-lite-image': 'Nano Banana 2 Lite (najtańszy, szybki)',
    'gemini-3.1-flash-image': 'Nano Banana 2 (lepsza jakość)',
    'gemini-3-pro-image': 'Nano Banana Pro (najlepszy, drogi)',
    'gemini-2.5-flash-image': 'Nano Banana (starszy)',
  };

  final String apiKey;
  @override
  final String model;
  final String baseUrl;
  final http.Client _client;

  @override
  Future<Uint8List> generate(String prompt, {String aspectRatio = '16:9'}) async {
    if (apiKey.trim().isEmpty) {
      throw AiException(AiErrorKind.noApiKey, 'Brak klucza Gemini (grafiki).');
    }
    final body = {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'responseModalities': ['IMAGE'],
        'imageConfig': {'aspectRatio': aspectRatio},
      },
    };
    final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse('$baseUrl/models/$model:generateContent'),
            headers: {'content-type': 'application/json', 'x-goog-api-key': apiKey},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 120));
    } on TimeoutException {
      throw AiException(AiErrorKind.timeout, 'Generowanie obrazu trwało za długo.');
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
        400 || 404 => AiErrorKind.badRequest,
        >= 500 => AiErrorKind.server,
        _ => AiErrorKind.unknown,
      };
      throw AiException(kind, msg, statusCode: res.statusCode, body: res.body);
    }
    final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final candidates = j['candidates'];
    if (candidates is List) {
      for (final c in candidates) {
        final parts = (c as Map)['content']?['parts'];
        if (parts is List) {
          for (final p in parts) {
            final inline = (p as Map)['inlineData'] ?? p['inline_data'];
            if (inline is Map && inline['data'] is String) {
              return base64Decode(inline['data'] as String);
            }
          }
        }
      }
    }
    final feedback = j['promptFeedback'];
    if (feedback is Map && feedback['blockReason'] != null) {
      throw AiException(AiErrorKind.refusal, 'Obraz zablokowany: ${feedback['blockReason']}');
    }
    throw AiException(AiErrorKind.badJson, 'Odpowiedź bez obrazu.', body: res.body);
  }
}
