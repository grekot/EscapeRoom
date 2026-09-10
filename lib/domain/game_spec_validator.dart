import 'catalog.dart';
import 'game_spec.dart';
import 'puzzle.dart';
import 'puzzle_validator.dart';

/// Validates a whole [GameSpec]. Issues are Polish sentences suitable for
/// feeding back to the AI designer on retry.
class GameSpecValidator {
  const GameSpecValidator._();

  static List<String> validate(GameSpec spec) {
    final issues = <String>[];
    if (spec.title.trim().isEmpty) issues.add('Brak tytułu gry.');
    if (spec.stages.length < 2) issues.add('Gra musi mieć co najmniej 2 etapy.');
    if (spec.stages.length > 8) issues.add('Gra ma za dużo etapów (max 8).');
    if (spec.intro.trim().isEmpty) issues.add('Brak intro.');

    for (var i = 0; i < spec.stages.length; i++) {
      final s = spec.stages[i];
      final n = i + 1;
      if (s.narrative.trim().isEmpty) issues.add('Etap $n: brak narrative.');
      if (s.hints.length != 3) {
        issues.add('Etap $n: hints musi mieć dokładnie 3 podpowiedzi (jest ${s.hints.length}).');
      }
      if (s.scene.objects.isEmpty) {
        issues.add('Etap $n: scena bez obiektów – dodaj 2–5 obiektów.');
      }
      if (s.scene.objects.length > 8) {
        issues.add('Etap $n: za dużo obiektów w scenie (max 8).');
      }
      if (s.scene.props.length > 8) {
        issues.add('Etap $n: za dużo rekwizytów (props, max 8).');
      }
      final ids = s.scene.objects.map((o) => o.id).toSet();
      for (final o in s.scene.objects) {
        if (!o.isChained) continue;
        if (o.requires == o.id) {
          issues.add('Etap $n: obiekt "${o.id}" wymaga (requires) samego siebie.');
        } else if (!ids.contains(o.requires)) {
          issues.add('Etap $n: obiekt "${o.id}" ma requires="${o.requires}", a takiego obiektu nie ma w scenie.');
        } else if (_hasCycle(s.scene, o)) {
          issues.add('Etap $n: obiekty "${o.id}" i "${o.requires}" blokują się nawzajem (cykl requires) – żadnego nie da się odczytać.');
        }
      }
      for (final p in s.scene.props) {
        if (p.objectId != null && p.objectId!.isNotEmpty && !ids.contains(p.objectId)) {
          issues.add('Etap $n: rekwizyt ${p.type} wskazuje nieistniejący objectId "${p.objectId}".');
        }
      }
      for (final p in PuzzleValidator.validate(s.puzzle)) {
        issues.add('Etap $n: $p.');
      }
      if (s.puzzle is PinCodePuzzle &&
          (s.puzzle as PinCodePuzzle).clues.isEmpty &&
          !s.scene.hasClueChain) {
        issues.add('Etap $n: pin_code bez wskazówek (clues) i bez odkryć w obiektach sceny – kodu nie da się wydedukować. Dodaj logi błędnych prób w clues albo rozłóż dane na clue co najmniej 2 obiektów.');
      }
    }
    return issues;
  }

  static bool _hasCycle(Scene scene, SceneObject start) {
    var cur = start;
    for (var i = 0; i <= scene.objects.length; i++) {
      if (!cur.isChained) return false;
      final next = scene.objectById(cur.requires);
      if (next == null) return false;
      if (next.id == start.id) return true;
      cur = next;
    }
    return true;
  }

  /// Non-fatal: puzzles that hand the answer to the player. Skipped for
  /// `easy` games aimed at small children, where literal tasks are fine.
  static List<String> quality(GameSpec spec) {
    if (spec.difficulty == Difficulty.easy && spec.targetAge <= 7) return const [];
    final issues = <String>[];
    for (var i = 0; i < spec.stages.length; i++) {
      final st = spec.stages[i];
      final where = 'Etap ${i + 1} („${st.title}”)';
      for (final q in PuzzleValidator.qualityIssues(st.puzzle, sceneClues: st.scene.hasClueChain)) {
        issues.add('$where: $q');
      }
      if (spec.difficulty == Difficulty.easy) continue;
      // The room must be explored: findings spread over objects, linked.
      final clues = st.scene.clueObjects;
      if (clues.length < 2) {
        issues.add('$where: brak łańcucha wskazówek – tylko ${clues.length} obiekt(y) sceny ma pole clue. Rozłóż dane zagadki na co najmniej 2 obiekty (clue = konkretne odkrycie: liczby, reguła, klucz szyfru), w puzzle.prompt zostaw sam cel i mechanizm, a jeden obiekt niech odblokowuje odczyt drugiego (requires).');
      } else if (!st.scene.objects.any((o) => o.isChained) && spec.difficulty == Difficulty.hard) {
        issues.add('$where: odkrycia nie są powiązane – dodaj zależność requires (np. klucz z jednego obiektu pozwala odczytać symbole na drugim), aby rozwiązanie jednej części naprowadzało na drugą.');
      }
      final idle = st.scene.objects.where((o) => !o.hasClue).length;
      if (idle > 2) {
        issues.add('$where: $idle obiektów sceny nie ma żadnej roli (puste clue). Dozwolony jest mechanizm zagadki i najwyżej jeden fałszywy trop; resztę usuń albo daj im odkrycia.');
      }
    }
    return issues;
  }
}
