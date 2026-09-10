import 'dart:math';

import '../../../domain/catalog.dart';
import '../../../domain/scenario.dart';
import '../ai_errors.dart';
import '../ai_provider.dart';
import 'prompts/scenario_prompts.dart';
import 'schemas/scenario_schema.dart';

class ScenarioRequest {
  const ScenarioRequest({
    required this.theme,
    required this.age,
    required this.difficulty,
    required this.stages,
    this.userPrompt,
    this.seedObjects = const [],
    this.twist,
    this.source = ScenarioSource.prompt,
    this.avoid = const [],
    this.suggestedMechanisms = const [],
  });

  /// Recent games/scenarios in the player's library ("do not repeat").
  final List<String> avoid;

  /// Fresh mechanism ideas picked by the app to steer variety.
  final List<String> suggestedMechanisms;

  ScenarioRequest copyWith(
          {List<String>? avoid, List<String>? suggestedMechanisms}) =>
      ScenarioRequest(
        theme: theme,
        age: age,
        difficulty: difficulty,
        stages: stages,
        userPrompt: userPrompt,
        seedObjects: seedObjects,
        twist: twist,
        source: source,
        avoid: avoid ?? this.avoid,
        suggestedMechanisms: suggestedMechanisms ?? this.suggestedMechanisms,
      );

  final String theme;
  final int age;
  final Difficulty difficulty;
  final int stages;
  final String? userPrompt;
  final List<String> seedObjects;
  final String? twist;
  final ScenarioSource source;

  /// Random parameters for the "surprise me" mode.
  factory ScenarioRequest.random({
    required int age,
    required Difficulty difficulty,
    required int stages,
    Random? rng,
  }) {
    final r = rng ?? Random();
    final objects = List.of(ScenarioPrompts.randomObjects)..shuffle(r);
    return ScenarioRequest(
      theme: ScenarioPrompts
          .randomThemes[r.nextInt(ScenarioPrompts.randomThemes.length)],
      age: age,
      difficulty: difficulty,
      stages: stages,
      seedObjects: objects.take(2).toList(),
      twist: ScenarioPrompts
          .randomTwists[r.nextInt(ScenarioPrompts.randomTwists.length)],
      source: ScenarioSource.random,
    );
  }
}

/// Asks the model to write a [Scenario] from parameters or a short prompt.
class ScenarioWriter {
  ScenarioWriter(this.ai, {required this.playerNames});

  final AiProvider ai;
  final String playerNames;

  Future<Scenario> write(ScenarioRequest req, {required String id}) async {
    final json = await ai.completeJson(
      system: ScenarioPrompts.writerSystem(
          age: req.age, playerNames: playerNames),
      user: ScenarioPrompts.writerUser(
        theme: req.theme,
        age: req.age,
        difficulty: req.difficulty,
        stages: req.stages,
        userPrompt: req.userPrompt,
        seedObjects: req.seedObjects,
        twist: req.twist,
        avoid: req.avoid,
        suggestedMechanisms: req.suggestedMechanisms,
      ),
      schema: scenarioJsonSchema(),
    );
    final s = Scenario.fromJson(json, id: id, source: req.source)
        .copyWith(createdAt: DateTime.now());
    final issues = s.validate();
    if (issues.isNotEmpty) {
      throw AiException(
          AiErrorKind.badJson, 'Scenariusz niekompletny: ${issues.join(' ')}');
    }
    return s;
  }
}
