import 'catalog.dart';
import 'json_utils.dart';

/// Where a scenario came from.
enum ScenarioSource {
  builtin('builtin'),
  imported('imported'),
  prompt('prompt'),
  random('random');

  const ScenarioSource(this.wire);
  final String wire;

  static ScenarioSource parse(String? s) => values.firstWhere(
        (d) => d.wire == (s ?? '').toLowerCase().trim(),
        orElse: () => ScenarioSource.imported,
      );
}

/// One stage of an authored scenario: prose only, no widget decisions yet.
class ScenarioStage {
  const ScenarioStage({
    required this.title,
    required this.place,
    required this.puzzle,
    required this.solution,
    required this.hints,
    this.suggestedType,
    this.mechanism = '',
    this.designNotes = '',
    this.uniquenessCheck = '',
  });

  final String title;

  /// The idea behind the puzzle (e.g. "szyfr z kluczem"), for variety checks.
  final String mechanism;

  /// Who built this puzzle in the story and why; links to other stages.
  final String designNotes;

  /// The author's own check that no second answer fits.
  final String uniquenessCheck;

  /// Description of the room / situation: material for the scene design.
  final String place;

  /// Full puzzle text exactly as the player should see it.
  final String puzzle;

  /// Unambiguous answer plus short reasoning.
  final String solution;

  /// From vague to almost explicit.
  final List<String> hints;

  /// Optional hint for the game designer (one of [PuzzleTypes.all]).
  final String? suggestedType;

  factory ScenarioStage.fromJson(Map<String, dynamic> j) => ScenarioStage(
        title: jStr(j, 'title'),
        place: jStr(j, 'place'),
        puzzle: jStr(j, 'puzzle'),
        solution: jStr(j, 'solution'),
        hints: jStrList(j, 'hints'),
        suggestedType: () {
          final t = jStrOrNull(j, 'suggestedType')?.toLowerCase().trim();
          return t != null && PuzzleTypes.all.contains(t) ? t : null;
        }(),
        mechanism: jStr(j, 'mechanism').trim(),
        designNotes: jStr(j, 'designNotes').trim(),
        uniquenessCheck: jStr(j, 'uniquenessCheck').trim(),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'place': place,
        'puzzle': puzzle,
        'solution': solution,
        'hints': hints,
        'suggestedType': suggestedType,
        'mechanism': mechanism,
        'designNotes': designNotes,
        'uniquenessCheck': uniquenessCheck,
      };
}

/// Authored scenario, format `escape-room-scenario/1`.
///
/// Can be written by a human, by an external AI chat, or by the in-app
/// scenario writer. The game designer turns it into a [GameSpec].
class Scenario {
  const Scenario({
    required this.id,
    required this.title,
    required this.theme,
    required this.language,
    required this.targetAge,
    required this.difficulty,
    required this.intro,
    required this.stages,
    required this.outro,
    required this.source,
    required this.createdAt,
    this.throughline = '',
    this.gmPersona = '',
  });

  static const format = 'escape-room-scenario/1';

  /// The story's driving question and its answer (revealed in the finale).
  final String throughline;

  /// Who talks to the players in the world of the game (the GM's persona).
  final String gmPersona;

  final String id;
  final String title;
  final String theme;
  final String language;
  final int targetAge;
  final Difficulty difficulty;
  final String intro;
  final List<ScenarioStage> stages;
  final String outro;
  final ScenarioSource source;
  final DateTime createdAt;

  factory Scenario.fromJson(Map<String, dynamic> j,
      {String? id, ScenarioSource? source}) {
    return Scenario(
      id: id ?? jStrOrNull(j, 'id') ?? '',
      title: jStr(j, 'title', fallback: 'Bez tytułu'),
      theme: jStr(j, 'theme'),
      language: jStr(j, 'language', fallback: 'pl'),
      targetAge: jInt(j, 'targetAge', fallback: 10),
      difficulty: Difficulty.parse(jStrOrNull(j, 'difficulty')),
      intro: jStr(j, 'intro'),
      stages: jMapList(j, 'stages').map(ScenarioStage.fromJson).toList(),
      outro: jStr(j, 'outro'),
      source: source ?? ScenarioSource.parse(jStrOrNull(j, 'source')),
      createdAt: jDate(j, 'createdAt'),
      throughline: jStr(j, 'throughline').trim(),
      gmPersona: jStr(j, 'gmPersona').trim(),
    );
  }

  Map<String, dynamic> toJson() => {
        'format': format,
        'id': id,
        'title': title,
        'theme': theme,
        'language': language,
        'targetAge': targetAge,
        'difficulty': difficulty.wire,
        'intro': intro,
        'stages': stages.map((s) => s.toJson()).toList(),
        'outro': outro,
        'source': source.wire,
        'createdAt': createdAt.toIso8601String(),
        'throughline': throughline,
        'gmPersona': gmPersona,
      };

  Scenario copyWith({
    String? id,
    String? title,
    int? targetAge,
    Difficulty? difficulty,
    ScenarioSource? source,
    DateTime? createdAt,
  }) =>
      Scenario(
        id: id ?? this.id,
        title: title ?? this.title,
        theme: theme,
        language: language,
        targetAge: targetAge ?? this.targetAge,
        difficulty: difficulty ?? this.difficulty,
        intro: intro,
        stages: stages,
        outro: outro,
        source: source ?? this.source,
        createdAt: createdAt ?? this.createdAt,
        throughline: throughline,
        gmPersona: gmPersona,
      );

  /// Structural problems that make a scenario unusable for game design.
  List<String> validate() {
    final issues = <String>[];
    if (title.trim().isEmpty) issues.add('Brak tytułu.');
    if (stages.isEmpty) issues.add('Scenariusz nie ma żadnego etapu.');
    for (var i = 0; i < stages.length; i++) {
      final s = stages[i];
      final n = i + 1;
      if (s.puzzle.trim().isEmpty) issues.add('Etap $n: brak treści zagadki.');
      if (s.solution.trim().isEmpty) issues.add('Etap $n: brak rozwiązania.');
    }
    return issues;
  }
}
