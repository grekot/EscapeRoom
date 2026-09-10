import 'dart:convert';

import '../../../domain/game_spec.dart';
import '../../../domain/game_spec_validator.dart';
import '../../../domain/prop_binding.dart';
import '../../../domain/puzzle_repair.dart';
import 'playtester.dart';
import '../../../domain/scenario.dart';
import '../ai_errors.dart';
import '../ai_provider.dart';
import 'prompts/designer_prompts.dart';
import 'schemas/game_spec_schema.dart';

/// Turns a [Scenario] into a playable [GameSpec] using the AI designer,
/// validating the result and retrying once with the list of problems.
class GameDesigner {
  GameDesigner(this.ai, {required this.playerNames});

  final AiProvider ai;
  final String playerNames;

  Future<GameSpec> design(
    Scenario scenario, {
    required String id,
    void Function(String status)? onStatus,
  }) async {
    onStatus?.call('Projektuję pokoje i zagadki…');
    final system = DesignerPrompts.system(
        age: scenario.targetAge, playerNames: playerNames);
    var json = await ai.completeJson(
      system: system,
      user: DesignerPrompts.user(scenario),
      schema: gameSpecJsonSchema(),
    );
    var spec = _build(json, scenario, id);
    onStatus?.call('Sprawdzam logikę zagadek…');
    var issues = GameSpecValidator.validate(spec);

    if (issues.isNotEmpty) {
      onStatus?.call('Poprawiam ${issues.length} problem(y)…');
      json = await ai.completeJson(
        system: system,
        user: DesignerPrompts.user(
          scenario,
          previousIssues: issues,
          previousJson: jsonEncode(json),
        ),
        schema: gameSpecJsonSchema(),
      );
      spec = _build(json, scenario, id);
      issues = GameSpecValidator.validate(spec);
      if (issues.isNotEmpty) {
        // Accept minor issues (hint counts etc.) but reject broken puzzles.
        final fatal = issues.where(_isFatal).toList();
        if (fatal.isNotEmpty) {
          throw AiException(AiErrorKind.badJson,
              'Projekt gry ma błędy: ${fatal.take(3).join(' ')}');
        }
      }
    }

    // Quality gate: the answer must not be handed to the player literally,
    // and a player who sees only the screen must be able to solve it.
    if (playtest) {
      final unsolvable = [
        ...GameSpecValidator.quality(spec),
        ...await Playtester(ai).run(spec, onStatus: onStatus, difficulty: scenario.difficulty),
      ];
      if (unsolvable.isNotEmpty) {
        onStatus?.call('Poprawiam ${unsolvable.length} słabe zagadki…');
        final fixedJson = await ai.completeJson(
          system: system,
          user: DesignerPrompts.user(
            scenario,
            previousIssues: unsolvable,
            previousJson: jsonEncode(json),
          ),
          schema: gameSpecJsonSchema(),
        );
        final fixed = _build(fixedJson, scenario, id);
        final fatal = GameSpecValidator.validate(fixed).where(_isFatal).toList();
        // Keep the corrected version only if it did not break the puzzles.
        if (fatal.isEmpty) spec = fixed;
      }
    }
    return spec;
  }

  /// Run the AI test player after designing (one extra request per stage).
  bool playtest = true;

  static bool _isFatal(String issue) =>
      issue.contains('sprzeczna') ||
      issue.contains('permutacją') ||
      issue.contains('poza zakresem') ||
      issue.contains('dopuszczają') ||
      issue.contains('brak pary') ||
      issue.contains('inną długość') ||
      issue.contains('brak acceptedAnswers') ||
      issue.contains('brak rubric');

  GameSpec _build(Map<String, dynamic> json, Scenario scenario, String id) {
    final GameSpec raw;
    try {
      raw = GameSpec.fromJson(
        json,
        id: id,
        scenarioId: scenario.id,
        designedBy: '${ai.id}/${ai.model}',
      );
    } on FormatException catch (e) {
      throw AiException(AiErrorKind.badJson, e.message);
    }
    return _normalize(raw, scenario);
  }

  /// Fixes small, mechanical defects without another model call.
  GameSpec _normalize(GameSpec spec, Scenario scenario) {
    final stages = <GameStage>[];
    for (var i = 0; i < spec.stages.length; i++) {
      final s = spec.stages[i];
      var hints = s.hints.where((h) => h.trim().isNotEmpty).toList();
      if (hints.length < 3 && i < scenario.stages.length) {
        for (final h in scenario.stages[i].hints) {
          if (hints.length >= 3) break;
          if (!hints.contains(h)) hints.add(h);
        }
      }
      while (hints.length < 3) {
        hints.add('Przyjrzyjcie się jeszcze raz wszystkim danym w zagadce.');
      }
      if (hints.length > 3) hints = hints.take(3).toList();

      // Mechanical mistakes (mastermind counts, permutations, ranges) are
      // fixed locally instead of bouncing the whole design back to the model.
      final puzzle = PuzzleRepair.repair(s.puzzle, addPinClues: !s.scene.hasClueChain);
      // A prop bound to an object must look like that object.
      stages.add(PropBinding.fix(GameStage(
        id: s.id,
        title: s.title,
        narrative: s.narrative,
        scene: s.scene,
        puzzle: puzzle,
        hints: hints,
        fallbackTexts: s.fallbackTexts,
        effectOnSuccess: s.effectOnSuccess,
      )));
    }
    return GameSpec(
      id: spec.id,
      scenarioId: spec.scenarioId,
      title: spec.title.trim().isEmpty ? scenario.title : spec.title,
      intro: spec.intro.trim().isEmpty ? scenario.intro : spec.intro,
      outro: spec.outro.trim().isEmpty ? scenario.outro : spec.outro,
      difficulty: spec.difficulty,
      targetAge: spec.targetAge,
      visualTheme: spec.visualTheme,
      stages: stages,
      createdAt: DateTime.now(),
      designedBy: spec.designedBy,
      gmPersona: spec.gmPersona.isEmpty ? scenario.gmPersona : spec.gmPersona,
    );
  }
}
