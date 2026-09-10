@Tags(['live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:escape_room/core/ai/gemini_provider.dart';
import 'package:escape_room/core/ai/image_generator.dart';
import 'package:escape_room/core/ai/pipeline/game_designer.dart';
import 'package:escape_room/core/ai/pipeline/playtester.dart';
import 'package:escape_room/core/ai/pipeline/scenario_writer.dart';
import 'package:escape_room/core/ai/pipeline/scene_artist.dart';
import 'package:escape_room/domain/catalog.dart';
import 'package:escape_room/domain/game_spec.dart';
import 'package:escape_room/domain/game_spec_validator.dart';
import 'package:escape_room/domain/scenario.dart';
import 'package:flutter_test/flutter_test.dart';

/// Real API calls (Gemini). Skipped unless GEMINI_API_KEY is set.
///
/// ILLUSTRATE_BUILTINS=1 additionally paints the bundled games and writes
/// the PNGs into `assets/images/<gameId>/` (run once, then commit).
void main() {
  final key = Platform.environment['GEMINI_API_KEY'] ?? '';
  final skip = key.isEmpty ? 'GEMINI_API_KEY not set' : null;

  test('playtester solves the bundled lighthouse game from player-visible data only', () async {
    final spec = GameSpec.fromJson(jsonDecode(
        File('assets/gamespecs/latarnia_w_sztormie.json').readAsStringSync()) as Map<String, dynamic>);
    final issues = await Playtester(GeminiProvider(apiKey: key)).run(spec, onStatus: (s) => print('  $s')); // ignore: avoid_print
    // ignore: avoid_print
    print('PLAYTEST ISSUES: $issues');
    expect(issues, isEmpty);
  }, skip: skip, timeout: const Timeout(Duration(minutes: 5)));

  test('designer upgrades a trivial scenario puzzle into a deductive one', () async {
    final ai = GeminiProvider(apiKey: key);
    final scenario = Scenario(
      id: 'triv',
      title: 'Dworzec Czasu',
      theme: 'dworzec z zegarem',
      language: 'pl',
      targetAge: 10,
      difficulty: Difficulty.medium,
      intro: 'Zegar dworcowy szaleje.',
      stages: const [
        ScenarioStage(
          title: 'Wielki zegar',
          place: 'Hala z ogromnym zegarem i trzema pokrętłami.',
          puzzle: 'Ustawcie czas na 12 godzin, 15 minut i 30 sekund.',
          solution: '12:15:30.',
          hints: ['Popatrz na pokrętła.', 'Godzina 12.', '12, 15, 30.'],
          suggestedType: 'dial_combination',
        ),
        ScenarioStage(
          title: 'Sejf kasjera',
          place: 'Kasa z sejfem.',
          puzzle: 'Na kartce napisano kod: 485. Wpiszcie go.',
          solution: '485.',
          hints: ['Kartka.', 'Trzy cyfry.', '485.'],
          suggestedType: 'pin_code',
        ),
      ],
      outro: 'Zegar staje.',
      source: ScenarioSource.prompt,
      createdAt: DateTime.now(),
    );
    final spec = await GameDesigner(ai, playerNames: '').design(scenario, id: 'triv_game', onStatus: (s) => print('  $s')); // ignore: avoid_print
    for (final st in spec.stages) {
      // ignore: avoid_print
      print('  - ${st.title} [${st.puzzle.type}]: ${st.puzzle.prompt}');
    }
    final quality = GameSpecValidator.quality(spec);
    // ignore: avoid_print
    print('QUALITY ISSUES AFTER GATE: $quality');
    expect(quality, isEmpty);
    expect(GameSpecValidator.validate(spec), isEmpty);
  }, skip: skip, timeout: const Timeout(Duration(minutes: 10)));

  test('writer → designer produces a valid game with props and prompts', () async {
    final ai = GeminiProvider(apiKey: key);
    final scenario = await ScenarioWriter(ai, playerNames: 'Zuzanna i Tata').write(
      const ScenarioRequest(
        theme: 'pracownia zegarmistrza pełna mechanicznych ptaków',
        age: 10,
        difficulty: Difficulty.medium,
        stages: 3,
      ),
      id: 'live_scn',
    );
    // ignore: avoid_print
    print('SCENARIO: ${scenario.title} / ${scenario.stages.map((s) => s.suggestedType).join(',')}');
    final spec = await GameDesigner(ai, playerNames: 'Zuzanna i Tata')
        .design(scenario, id: 'live_game', onStatus: (s) => print('  $s')); // ignore: avoid_print
    final issues = GameSpecValidator.validate(spec);
    // ignore: avoid_print
    print('GAME: ${spec.title} theme=${spec.visualTheme.wire} issues=$issues');
    for (final st in spec.stages) {
      // ignore: avoid_print
      print('  - ${st.title}: ${st.puzzle.type}, props=${st.scene.props.map((p) => p.type).join('/')}, '
          'backdrop=${st.scene.backdrop}, prompt="${st.scene.imagePrompt.substring(0, st.scene.imagePrompt.length.clamp(0, 70))}…"');
      expect(st.scene.props, isNotEmpty, reason: st.title);
      expect(st.scene.imagePrompt.trim(), isNotEmpty, reason: st.title);
    }
    expect(issues, isEmpty);
    final out = File('${Directory.systemTemp.path}${Platform.pathSeparator}live_game.json');
    await out.writeAsString(const JsonEncoder.withIndent('  ').convert(spec.toJson()));
  }, skip: skip, timeout: const Timeout(Duration(minutes: 10)));

  test('illustrate built-in games into assets/', () async {
    final assets = Directory('assets/images');
    final only = Platform.environment['ILLUSTRATE_ONLY'];
    for (final entry in const [
      ('builtin_warsztat_wynalazcy', 'assets/gamespecs/warsztat_wynalazcy.json'),
      ('builtin_latarnia', 'assets/gamespecs/latarnia_w_sztormie.json'),
    ]) {
      if (only != null && only.isNotEmpty && only != entry.$1) continue;
      final f = File(entry.$2);
      final spec = GameSpec.fromJson(jsonDecode(f.readAsStringSync()) as Map<String, dynamic>, id: entry.$1);
      final tmp = await Directory.systemTemp.createTemp('illus');
      final artist = SceneArtist(GeminiImageGenerator(apiKey: key), root: tmp);
      final r = await artist.illustrate(spec, onStatus: (s) => print('  $s')); // ignore: avoid_print
      expect(r.failures, isEmpty, reason: r.failures.toString());
      final dir = Directory('${assets.path}/${entry.$1}');
      await dir.create(recursive: true);
      final stages = <Map<String, dynamic>>[];
      for (final st in r.spec.stages) {
        final j = st.toJson();
        final scene = j['scene'] as Map<String, dynamic>;
        if (st.scene.imagePath != null) {
          await File(st.scene.imagePath!).copy('${dir.path}/${st.id}.png');
          scene['imageAsset'] = 'assets/images/${entry.$1}/${st.id}.png';
        }
        scene.remove('imagePath');
        // generated sprites of custom props become bundled assets too
        final props = scene['props'] as List;
        for (var k = 0; k < props.length; k++) {
          final sp = r.spec.stages.firstWhere((s) => s.id == st.id).scene.props[k].spritePath;
          final pj = props[k] as Map<String, dynamic>;
          if (sp != null && File(sp).existsSync()) {
            final name = '${st.id}_prop$k.png';
            await File(sp).copy('${dir.path}/$name');
            pj['spriteAsset'] = 'assets/images/${entry.$1}/$name';
          }
          pj.remove('spritePath');
        }
        stages.add(j);
      }
      final specJson = spec.toJson()..['stages'] = stages;
      specJson.remove('imagePath');
      await f.writeAsString(const JsonEncoder.withIndent('  ').convert(specJson));
      // ignore: avoid_print
      print('BUNDLED ${entry.$1}: ${stages.length} images');
    }
  },
      skip: skip ?? (Platform.environment['ILLUSTRATE_BUILTINS'] == '1' ? null : 'set ILLUSTRATE_BUILTINS=1'),
      timeout: const Timeout(Duration(minutes: 15)));
}
