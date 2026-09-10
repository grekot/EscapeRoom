@Tags(['live'])
library;

import 'dart:io';

import 'package:escape_room/core/ai/ai_errors.dart';
import 'package:escape_room/core/ai/gemini_provider.dart';
import 'package:escape_room/core/ai/pipeline/game_designer.dart';
import 'package:escape_room/core/ai/pipeline/scenario_writer.dart';
import 'package:escape_room/domain/catalog.dart';
import 'package:escape_room/domain/game_spec_validator.dart';
import 'package:escape_room/domain/mechanisms.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reproduces the in-app flow with a chosen model:
///   GEMINI_API_KEY=... GEMINI_MODEL=gemini-3.1-pro-preview flutter test test/live_pro_design_test.dart --tags live
void main() {
  final key = Platform.environment['GEMINI_API_KEY'] ?? '';
  final model = Platform.environment['GEMINI_MODEL'] ?? 'gemini-3.1-pro-preview';
  final skip = key.isEmpty ? 'GEMINI_API_KEY not set' : null;

  test('write + design with $model', () async {
    final ai = GeminiProvider(apiKey: key, model: model);
    try {
      // The same library memory the app builds: recent games' mechanisms.
      final avoid = <String>[
        '„Tajemnica Grobowca Faraona” – logi błędnych prób zamka (mastermind); kolejność z reguł zależności; dopasowanie par; hasło lub szyfr słowny',
        '„Dworzec Cofniętego Czasu” – wzór przełączników wynikający z reguły; wartości pokręteł z obliczeń; logi błędnych prób zamka (mastermind); wybór przez eliminację',
      ];
      final req = ScenarioRequest.random(age: 10, difficulty: Difficulty.medium, stages: 4).copyWith(
        avoid: avoid,
        suggestedMechanisms: Mechanisms.suggest(avoid: avoid, count: 4),
      );
      final scenario = await ScenarioWriter(ai, playerNames: 'Zuzanna i Tata').write(req, id: 'pro_scn');
      // ignore: avoid_print
      print('SCENARIO OK: ${scenario.title}');
      // ignore: avoid_print
      print('  throughline: ${scenario.throughline}');
      // ignore: avoid_print
      print('  gmPersona: ${scenario.gmPersona}');
      for (final st in scenario.stages) {
        // ignore: avoid_print
        print('  # ${st.title} [${st.suggestedType}] mechanism=${st.mechanism}');
        // ignore: avoid_print
        print('    notes: ${st.designNotes}');
        // ignore: avoid_print
        print('    check: ${st.uniquenessCheck}');
      }
      final spec = await GameDesigner(ai, playerNames: 'Zuzanna i Tata')
          .design(scenario, id: 'pro_game', onStatus: (s) => print('  $s')); // ignore: avoid_print
      // ignore: avoid_print
      print('GAME OK: ${spec.title}; gmPersona=${spec.gmPersona}; quality=${GameSpecValidator.quality(spec)}');
      for (final st in spec.stages) {
        // ignore: avoid_print
        print('  - ${st.title} [${st.puzzle.type}]: ${st.puzzle.prompt}');
        for (final o in st.scene.objects) {
          // ignore: avoid_print
          print('      * ${o.label}${o.isChained ? ' (requires ${o.requires}; locked: ${o.lockedText})' : ''}: clue=${o.clue.isEmpty ? '-' : o.clue}');
        }
      }
    } on AiException catch (e) {
      // ignore: avoid_print
      print('AI ERROR kind=${e.kind} msg=${e.message}\nBODY(head)=${(e.body ?? '').substring(0, (e.body ?? '').length.clamp(0, 1500))}');
      rethrow;
    }
  }, skip: skip, timeout: const Timeout(Duration(minutes: 15)));
}
