import 'dart:convert';
import 'dart:io';

import 'package:escape_room/core/ai/ai_errors.dart';
import 'package:escape_room/core/ai/image_generator.dart';
import 'package:escape_room/core/ai/pipeline/scene_artist.dart';
import 'package:escape_room/domain/game_spec.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  // 1x1 PNG
  final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

  group('GeminiImageGenerator', () {
    test('sends IMAGE modality request and decodes inlineData', () async {
      late http.Request seen;
      final client = MockClient((req) async {
        seen = req;
        return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'Here is your image'},
                      {'inlineData': {'mimeType': 'image/png', 'data': base64Encode(png)}},
                    ]
                  }
                }
              ]
            }),
            200);
      });
      final g = GeminiImageGenerator(apiKey: 'k', client: client);
      final bytes = await g.generate('a lighthouse');
      expect(bytes, png);
      expect(seen.url.path, contains('gemini-3.1-flash-lite-image:generateContent'));
      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body['generationConfig']['responseModalities'], ['IMAGE']);
      expect(body['generationConfig']['imageConfig']['aspectRatio'], '16:9');
      expect(body['contents'][0]['parts'][0]['text'], 'a lighthouse');
    });

    test('maps errors', () async {
      Future<AiErrorKind> kindFor(http.Response r) async {
        final g = GeminiImageGenerator(apiKey: 'k', client: MockClient((_) async => r));
        try {
          await g.generate('x');
        } on AiException catch (e) {
          return e.kind;
        }
        fail('expected exception');
      }

      expect(await kindFor(http.Response('{}', 403)), AiErrorKind.unauthorized);
      expect(await kindFor(http.Response(jsonEncode({'candidates': <Object>[]}), 200)),
          AiErrorKind.badJson);
      expect(
          await kindFor(http.Response(
              jsonEncode({'promptFeedback': {'blockReason': 'SAFETY'}}), 200)),
          AiErrorKind.refusal);
    });
  });

  group('SceneArtist', () {
    test('writes one PNG per stage and records paths; failures are non-fatal',
        () async {
      final tmp = await Directory.systemTemp.createTemp('artist');
      addTearDown(() async {
        try {
          await tmp.delete(recursive: true);
        } catch (_) {}
      });
      final raw = File('assets/gamespecs/latarnia_w_sztormie.json').readAsStringSync();
      // Strip bundled assets so the artist has to paint everything.
      final j = jsonDecode(raw) as Map<String, dynamic>;
      for (final st in j['stages'] as List) {
        final scene = st['scene'] as Map<String, dynamic>;
        scene.remove('imageAsset');
        for (final p in scene['props'] as List) {
          (p as Map<String, dynamic>).remove('spriteAsset');
        }
      }
      final spec = GameSpec.fromJson(j);
      var calls = 0;
      final prompts = <String>[];
      final client = MockClient((req) async {
        calls++;
        prompts.add((jsonDecode(req.body)['contents'][0]['parts'][0]['text']) as String);
        if (calls == 2) return http.Response('{}', 500); // one stage fails
        return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'inlineData': {'mimeType': 'image/png', 'data': base64Encode(png)}}
                    ]
                  }
                }
              ]
            }),
            200);
      });
      final artist = SceneArtist(GeminiImageGenerator(apiKey: 'k', client: client), root: tmp);
      final statuses = <String>[];
      final r = await artist.illustrate(spec, onStatus: statuses.add);
      // 4 scenes + 1 custom-prop sprite (lighthouse lens)
      expect(calls, 5);
      expect(r.failures, hasLength(1));
      expect(r.failures.keys.first, spec.stages[1].title);
      expect(r.spec.stages[0].scene.imagePath, isNotNull);
      expect(File(r.spec.stages[0].scene.imagePath!).existsSync(), isTrue);
      expect(r.spec.stages[1].scene.imagePath, isNull);
      final lens = r.spec.stages[2].scene.props.firstWhere((p) => p.isCustom);
      expect(lens.spritePath, isNotNull);
      expect(File(lens.spritePath!).existsSync(), isTrue);
      expect(prompts.first, contains(spec.stages[0].scene.imagePrompt));
      expect(prompts.first, contains('No people, no text'));
      expect(statuses.first, contains('Maluję scenę 1/4'));

      // second pass only repaints the missing one
      calls = 0;
      final r2 = await artist.illustrate(r.spec);
      expect(calls, 1);
      expect(r2.spec.stages.every((s) => s.scene.imagePath != null), isTrue);
      // round-trips through JSON
      final again = GameSpec.fromJson(r2.spec.toJson());
      expect(again.stages[1].scene.imagePath, r2.spec.stages[1].scene.imagePath);
    });
  });
}
