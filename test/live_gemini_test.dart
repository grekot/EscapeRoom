@Tags(['live'])
library;

import 'dart:io';

import 'package:escape_room/core/ai/gemini_provider.dart';
import 'package:escape_room/core/ai/image_generator.dart';
import 'package:escape_room/core/ai/model_catalog.dart';
import 'package:escape_room/core/ai/pipeline/schemas/scenario_schema.dart';
import 'package:escape_room/core/ai/pipeline/scene_artist.dart';
import 'package:escape_room/domain/scenario.dart';
import 'package:flutter_test/flutter_test.dart';

/// Real API calls. Skipped unless GEMINI_API_KEY is set:
///   GEMINI_API_KEY=... flutter test test/live_gemini_test.dart --tags live
void main() {
  final key = Platform.environment['GEMINI_API_KEY'] ?? '';
  final outDir = Platform.environment['LIVE_OUT_DIR'] ?? Directory.systemTemp.path;
  final skip = key.isEmpty ? 'GEMINI_API_KEY not set' : null;

  test('ping', () async {
    await GeminiProvider(apiKey: key).ping();
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));

  test('model catalogue lists text and image models', () async {
    final models = await ModelCatalog().gemini(key);
    // ignore: avoid_print
    print('TEXT: ${models.where((m) => !m.isImage).map((m) => m.id).join(', ')}');
    // ignore: avoid_print
    print('IMAGE: ${models.where((m) => m.isImage).map((m) => m.id).join(', ')}');
    expect(models.where((m) => !m.isImage), isNotEmpty);
    expect(models.where((m) => m.isImage), isNotEmpty);
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));

  test('text model returns a scenario JSON matching the schema', () async {
    final p = GeminiProvider(apiKey: key);
    final json = await p.completeJson(
      system: 'Jesteś autorem escape roomów dla dzieci. Odpowiadasz JSON-em zgodnym ze schematem.',
      user: 'Napisz krótki scenariusz: motyw "opuszczona stacja polarna", wiek 9, trudność easy, 2 etapy, po polsku.',
      schema: scenarioJsonSchema(),
    );
    final s = Scenario.fromJson(json, id: 'live');
    // ignore: avoid_print
    print('TITLE: ${s.title}\nSTAGES: ${s.stages.map((e) => '${e.title} [${e.suggestedType}]').join(' | ')}');
    expect(s.validate(), isEmpty);
    expect(s.stages.length, greaterThanOrEqualTo(2));
  }, skip: skip, timeout: const Timeout(Duration(minutes: 4)));

  test('image model paints a lighthouse engine room', () async {
    final g = GeminiImageGenerator(apiKey: key);
    final bytes = await g.generate(
        'Cramped engine room at the base of an old stone lighthouse during a storm: a large silent brass-and-iron generator in the centre, cracked steam pipe on the left wall, a fuse box and a big main lever on the right wall, wet stone floor, a single swinging oil lamp, rain visible through a small round window.\n\n$illustrationStyle');
    expect(bytes.length, greaterThan(10000));
    final f = File('$outDir${Platform.pathSeparator}live_lighthouse.png');
    await f.writeAsBytes(bytes);
    // ignore: avoid_print
    print('IMAGE: ${f.path} (${bytes.length} bytes)');
  }, skip: skip, timeout: const Timeout(Duration(minutes: 4)));
}
