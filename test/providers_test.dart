import 'dart:convert';

import 'package:escape_room/core/ai/ai_errors.dart';
import 'package:escape_room/core/ai/ai_provider.dart';
import 'package:escape_room/core/ai/anthropic_provider.dart';
import 'package:escape_room/core/ai/gemini_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('AnthropicProvider', () {
    test('builds a structured-output request and parses text block', () async {
      late http.Request seen;
      final client = MockClient((req) async {
        seen = req;
        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': '{"title":"Ok"}'}
            ],
            'stop_reason': 'end_turn',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final p = AnthropicProvider(apiKey: 'k', client: client);
      final out = await p.completeJson(
        system: 'sys',
        user: 'usr',
        schema: {'type': 'object'},
      );
      expect(out['title'], 'Ok');
      expect(seen.url.path, '/v1/messages');
      expect(seen.headers['x-api-key'], 'k');
      expect(seen.headers['anthropic-version'], '2023-06-01');
      expect(seen.headers['anthropic-beta'], contains('server-side-fallback'));
      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body['model'], 'claude-opus-5');
      expect(body['system'], 'sys');
      expect(body['output_config']['format']['type'], 'json_schema');
      expect(body['fallbacks'], 'default');
      expect(body.containsKey('thinking'), isFalse);
    });

    test('haiku omits effort and fallbacks', () async {
      late http.Request seen;
      final client = MockClient((req) async {
        seen = req;
        return http.Response(
            jsonEncode({
              'content': [
                {'type': 'text', 'text': 'hi'}
              ],
              'stop_reason': 'end_turn'
            }),
            200);
      });
      final p = AnthropicProvider(
          apiKey: 'k', client: client, model: 'claude-haiku-4-5');
      await p.chat(system: 's', history: const [ChatMessage.user('x')]);
      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body.containsKey('output_config'), isFalse);
      expect(body.containsKey('fallbacks'), isFalse);
      expect(seen.headers.containsKey('anthropic-beta'), isFalse);
    });

    test('maps status codes and stop reasons', () async {
      Future<AiErrorKind> kindFor(http.Response r) async {
        final p = AnthropicProvider(
            apiKey: 'k', client: MockClient((_) async => r));
        try {
          await p.chat(system: 's', history: const [ChatMessage.user('x')]);
        } on AiException catch (e) {
          return e.kind;
        }
        fail('expected exception');
      }

      expect(
          await kindFor(http.Response(
              jsonEncode({'error': {'message': 'bad key'}}), 401)),
          AiErrorKind.unauthorized);
      expect(await kindFor(http.Response('{}', 400)), AiErrorKind.badRequest);
      expect(
          await kindFor(http.Response(
              jsonEncode({
                'content': <Object>[],
                'stop_reason': 'refusal',
                'stop_details': {'explanation': 'nope'}
              }),
              200)),
          AiErrorKind.refusal);
      expect(
          await kindFor(http.Response(
              jsonEncode({
                'content': [
                  {'type': 'text', 'text': '{"a":'}
                ],
                'stop_reason': 'max_tokens'
              }),
              200)),
          AiErrorKind.truncated);
    });

    test('retries on 429 then succeeds', () async {
      var calls = 0;
      final client = MockClient((req) async {
        calls++;
        if (calls == 1) return http.Response('{}', 429);
        return http.Response(
            jsonEncode({
              'content': [
                {'type': 'text', 'text': 'ok'}
              ],
              'stop_reason': 'end_turn'
            }),
            200);
      });
      final p = AnthropicProvider(apiKey: 'k', client: client);
      final out = await p.chat(system: 's', history: const [ChatMessage.user('x')]);
      expect(out, 'ok');
      expect(calls, 2);
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('empty key fails fast', () async {
      final p = AnthropicProvider(apiKey: '', client: MockClient((_) async {
        fail('should not call');
      }));
      expect(() => p.ping(), throwsA(isA<AiException>()
          .having((e) => e.kind, 'kind', AiErrorKind.noApiKey)));
    });
  });

  group('GeminiProvider', () {
    test('builds generateContent request and parses candidate', () async {
      late http.Request seen;
      final client = MockClient((req) async {
        seen = req;
        return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': '{"title":"G"}'}
                    ]
                  },
                  'finishReason': 'STOP'
                }
              ]
            }),
            200);
      });
      final p = GeminiProvider(apiKey: 'gk', client: client);
      final out = await p.completeJson(
          system: 'sys', user: 'usr', schema: {'type': 'object'});
      expect(out['title'], 'G');
      expect(seen.url.path, contains('/models/gemini-3.8-flash:generateContent'));
      expect(seen.headers['x-goog-api-key'], 'gk');
      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body['systemInstruction']['parts'][0]['text'], 'sys');
      expect(body['generationConfig']['responseMimeType'], 'application/json');
      expect(body['generationConfig']['responseJsonSchema'], isNotNull);
    });

    test('chat maps assistant role to model', () async {
      late http.Request seen;
      final client = MockClient((req) async {
        seen = req;
        return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'hej'}
                    ]
                  },
                  'finishReason': 'STOP'
                }
              ]
            }),
            200);
      });
      final p = GeminiProvider(apiKey: 'gk', client: client);
      await p.chat(system: 's', history: const [
        ChatMessage.user('a'),
        ChatMessage.assistant('b'),
      ]);
      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body['contents'][1]['role'], 'model');
    });

    test('safety block → refusal, MAX_TOKENS → truncated', () async {
      Future<AiErrorKind> kindFor(Map<String, dynamic> j) async {
        final p = GeminiProvider(
            apiKey: 'k',
            client: MockClient((_) async => http.Response(jsonEncode(j), 200)));
        try {
          await p.chat(system: 's', history: const [ChatMessage.user('x')]);
        } on AiException catch (e) {
          return e.kind;
        }
        fail('expected exception');
      }

      expect(
          await kindFor({
            'promptFeedback': {'blockReason': 'SAFETY'}
          }),
          AiErrorKind.refusal);
      expect(
          await kindFor({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'x'}
                  ]
                },
                'finishReason': 'MAX_TOKENS'
              }
            ]
          }),
          AiErrorKind.truncated);
    });
  });
}
