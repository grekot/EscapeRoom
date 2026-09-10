import 'dart:convert';

import 'package:escape_room/core/ai/ai_errors.dart';
import 'package:escape_room/core/ai/model_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('gemini: keeps generateContent models, splits image models, pages', () async {
    var page = 0;
    final client = MockClient((req) async {
      expect(req.headers['x-goog-api-key'], 'k');
      page++;
      if (req.url.queryParameters['pageToken'] == null) {
        return http.Response(
            jsonEncode({
              'models': [
                {'name': 'models/gemini-3.8-flash', 'displayName': 'Gemini 3.8 Flash', 'supportedGenerationMethods': ['generateContent']},
                {'name': 'models/gemini-3.1-flash-image', 'displayName': 'Nano Banana 2', 'supportedGenerationMethods': ['generateContent']},
                {'name': 'models/text-embedding-004', 'displayName': 'Embedding', 'supportedGenerationMethods': ['embedContent']},
                {'name': 'models/gemini-2.5-flash-preview-tts', 'displayName': 'TTS', 'supportedGenerationMethods': ['generateContent']},
                {'name': 'models/gemma-4-31b-it', 'displayName': 'Gemma', 'supportedGenerationMethods': ['generateContent']},
                {'name': 'models/nano-banana-pro-preview', 'displayName': 'Nano Banana Pro', 'supportedGenerationMethods': ['generateContent']},
                {'name': 'models/lyria-3.5', 'displayName': 'Lyria', 'supportedGenerationMethods': ['generateContent']},
              ],
              'nextPageToken': 'p2',
            }),
            200);
      }
      return http.Response(
          jsonEncode({
            'models': [
              {'name': 'models/gemini-3.1-pro-preview', 'displayName': 'Gemini 3.1 Pro Preview', 'supportedGenerationMethods': ['generateContent']},
            ],
          }),
          200);
    });
    final models = await ModelCatalog(client: client).gemini('k');
    expect(page, 2);
    expect(models.map((m) => m.id),
        ['gemini-3.8-flash', 'gemini-3.1-flash-image', 'gemini-3.1-pro-preview', 'nano-banana-pro-preview']);
    expect(models.where((m) => m.isImage).map((m) => m.id),
        ['gemini-3.1-flash-image', 'nano-banana-pro-preview']);
    expect(models.first.label, 'Gemini 3.8 Flash');
  });

  test('anthropic: reads data list and maps errors', () async {
    final client = MockClient((req) async {
      expect(req.headers['anthropic-version'], '2023-06-01');
      return http.Response(
          jsonEncode({
            'data': [
              {'id': 'claude-opus-5', 'display_name': 'Claude Opus 5'},
              {'id': 'claude-sonnet-5', 'display_name': 'Claude Sonnet 5'},
            ],
            'has_more': false,
          }),
          200);
    });
    final models = await ModelCatalog(client: client).anthropic('k');
    expect(models.map((m) => m.id), ['claude-opus-5', 'claude-sonnet-5']);

    final bad = ModelCatalog(client: MockClient((_) async => http.Response('{}', 401)));
    expect(() => bad.anthropic('k'),
        throwsA(isA<AiException>().having((e) => e.kind, 'kind', AiErrorKind.unauthorized)));
    expect(() => bad.gemini(''),
        throwsA(isA<AiException>().having((e) => e.kind, 'kind', AiErrorKind.noApiKey)));
  });
}
