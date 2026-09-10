import 'puzzle.dart';

/// Result of checking a player's answer.
sealed class CheckResult {
  const CheckResult();
}

/// Decided locally.
class LocalResult extends CheckResult {
  const LocalResult(this.correct, {this.detail});

  final bool correct;

  /// Optional partial feedback (e.g. how many items were in place).
  final String? detail;
}

/// The puzzle is open-ended; an AI judge must grade it.
class NeedsAiJudgement extends CheckResult {
  const NeedsAiJudgement(this.puzzle, this.answer);

  final OpenExplanationPuzzle puzzle;
  final String answer;
}

/// Pure functions for checking answers and for validating puzzle consistency.
class PuzzleValidator {
  const PuzzleValidator._();

  /// [answer] type depends on the puzzle:
  /// - sequence_order: `List<String>`
  /// - pin_code / text_answer / open_explanation: `String`
  /// - multiple_choice: `int`
  /// - matching: `Map<String, String>` (left → right)
  /// - toggle_grid: `List<bool>`
  /// - dial_combination: `List<int>`
  static CheckResult check(Puzzle puzzle, Object answer) {
    switch (puzzle) {
      case SequenceOrderPuzzle p:
        final a = _asStringList(answer);
        final correct = _listEquals(
          a.map(normalizeText).toList(),
          p.correctOrder.map(normalizeText).toList(),
        );
        var inPlace = 0;
        for (var i = 0; i < a.length && i < p.correctOrder.length; i++) {
          if (normalizeText(a[i]) == normalizeText(p.correctOrder[i])) {
            inPlace++;
          }
        }
        return LocalResult(correct,
            detail: correct
                ? null
                : 'Na właściwym miejscu: $inPlace z ${p.correctOrder.length}.');

      case PinCodePuzzle p:
        final a = answer.toString().replaceAll(RegExp(r'\D'), '');
        return LocalResult(a == p.answer);

      case MultipleChoicePuzzle p:
        final idx = answer is int ? answer : int.tryParse(answer.toString());
        return LocalResult(idx == p.correctIndex);

      case TextAnswerPuzzle p:
        final a = answer.toString();
        final ok = p.acceptedAnswers.any((acc) => p.normalize
            ? normalizeText(acc) == normalizeText(a)
            : acc.trim() == a.trim());
        return LocalResult(ok);

      case MatchingPuzzle p:
        final a = _asStringMap(answer);
        if (a.length != p.correctPairs.length) {
          return const LocalResult(false, detail: 'Nie wszystko dopasowane.');
        }
        var good = 0;
        for (final e in p.correctPairs.entries) {
          if (a[e.key] != null &&
              normalizeText(a[e.key]!) == normalizeText(e.value)) {
            good++;
          }
        }
        final correct = good == p.correctPairs.length;
        return LocalResult(correct,
            detail: correct
                ? null
                : 'Poprawnych dopasowań: $good z ${p.correctPairs.length}.');

      case ToggleGridPuzzle p:
        final a = answer is List<bool>
            ? answer
            : (answer as List).map((e) => e == true).toList();
        return LocalResult(_listEquals(a, p.targetState));

      case DialCombinationPuzzle p:
        final a = answer is List<int>
            ? answer
            : (answer as List).map((e) => int.parse(e.toString())).toList();
        return LocalResult(_listEquals(a, p.answer));

      case OpenExplanationPuzzle p:
        return NeedsAiJudgement(p, answer.toString());
    }
  }

  /// Lower-case, strip Polish diacritics, keep letters/digits, collapse spaces.
  static String normalizeText(String s) {
    const from = 'ąćęłńóśźżĄĆĘŁŃÓŚŹŻ';
    const to = 'acelnoszzACELNOSZZ';
    final sb = StringBuffer();
    for (final ch in s.characters) {
      final i = from.indexOf(ch);
      sb.write(i >= 0 ? to[i] : ch);
    }
    return sb
        .toString()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  /// Mastermind-style feedback for [guess] against [answer].
  static (int inPlace, int wrongPlace) pinFeedback(String guess, String answer) {
    var inPlace = 0;
    final gCount = <String, int>{};
    final aCount = <String, int>{};
    for (var i = 0; i < guess.length && i < answer.length; i++) {
      if (guess[i] == answer[i]) {
        inPlace++;
      } else {
        gCount[guess[i]] = (gCount[guess[i]] ?? 0) + 1;
        aCount[answer[i]] = (aCount[answer[i]] ?? 0) + 1;
      }
    }
    var wrongPlace = 0;
    for (final e in gCount.entries) {
      final inAnswer = aCount[e.key] ?? 0;
      wrongPlace += e.value < inAnswer ? e.value : inAnswer;
    }
    return (inPlace, wrongPlace);
  }

  /// All codes of [PinCodePuzzle.codeLength] digits consistent with every clue.
  /// A well-formed puzzle returns exactly `[answer]`. Limited to length ≤ 5.
  static List<String> pinCandidates(PinCodePuzzle p) {
    if (p.codeLength <= 0 || p.codeLength > 5) return [p.answer];
    final total = _pow10(p.codeLength);
    final out = <String>[];
    for (var n = 0; n < total; n++) {
      final code = n.toString().padLeft(p.codeLength, '0');
      var ok = true;
      for (final c in p.clues) {
        if (c.code.length != p.codeLength) continue;
        final (ip, wp) = pinFeedback(c.code, code);
        if (ip != c.inPlace || wp != c.wrongPlace) {
          ok = false;
          break;
        }
      }
      if (ok) out.add(code);
    }
    return out;
  }

  /// Structural / logical problems of a single puzzle, in Polish (fed back to
  /// the AI designer on retry). Empty list means the puzzle is sound.
  static List<String> validate(Puzzle puzzle) {
    final issues = <String>[];
    if (puzzle.prompt.trim().isEmpty) issues.add('brak treści (prompt)');
    switch (puzzle) {
      case SequenceOrderPuzzle p:
        if (p.items.length < 2) issues.add('sequence_order: mniej niż 2 elementy');
        final a = p.items.map(normalizeText).toList()..sort();
        final b = p.correctOrder.map(normalizeText).toList()..sort();
        if (!_listEquals(a, b)) {
          issues.add('sequence_order: correctOrder nie jest permutacją items');
        }
        if (a.toSet().length != a.length) {
          issues.add('sequence_order: elementy items się powtarzają');
        }
      case PinCodePuzzle p:
        if (p.answer.length != p.codeLength) {
          issues.add('pin_code: answer ma inną długość niż codeLength');
        }
        if (p.codeLength < 2 || p.codeLength > 6) {
          issues.add('pin_code: codeLength musi być 2–6');
        }
        for (final c in p.clues) {
          if (c.code.length != p.codeLength) {
            issues.add('pin_code: wskazówka "${c.code}" ma złą długość');
            continue;
          }
          final (ip, wp) = pinFeedback(c.code, p.answer);
          if (ip != c.inPlace || wp != c.wrongPlace) {
            issues.add(
                'pin_code: wskazówka "${c.code}" jest sprzeczna z answer (powinno być inPlace=$ip, wrongPlace=$wp)');
          }
        }
        if (issues.isEmpty && p.clues.isNotEmpty) {
          final cands = pinCandidates(p);
          if (cands.length != 1) {
            issues.add(
                'pin_code: wskazówki dopuszczają ${cands.length} kodów (np. ${cands.take(4).join(', ')}) – musi być dokładnie jeden');
          }
        }
        // An empty clue list is allowed when the scene carries the code's data; GameSpecValidator checks that.
      case MultipleChoicePuzzle p:
        if (p.options.length < 2) issues.add('multiple_choice: mniej niż 2 opcje');
        if (p.correctIndex < 0 || p.correctIndex >= p.options.length) {
          issues.add('multiple_choice: correctIndex poza zakresem opcji');
        }
      case TextAnswerPuzzle p:
        if (p.acceptedAnswers.where((s) => s.trim().isNotEmpty).isEmpty) {
          issues.add('text_answer: brak acceptedAnswers');
        }
      case MatchingPuzzle p:
        if (p.leftItems.length < 2) issues.add('matching: mniej niż 2 pary');
        if (p.leftItems.length != p.rightItems.length) {
          issues.add('matching: leftItems i rightItems mają różną długość');
        }
        final rights = p.rightItems.map(normalizeText).toSet();
        for (final l in p.leftItems) {
          final r = p.correctPairs[l];
          if (r == null) {
            issues.add('matching: brak pary dla "$l"');
          } else if (!rights.contains(normalizeText(r))) {
            issues.add('matching: "$r" nie występuje w rightItems');
          }
        }
        final usedRights = p.correctPairs.values.map(normalizeText).toSet();
        if (usedRights.length != p.correctPairs.length) {
          issues.add('matching: ten sam element prawy użyty wielokrotnie');
        }
      case ToggleGridPuzzle p:
        final cells = p.rows * p.cols;
        if (cells < 2 || cells > 25) issues.add('toggle_grid: siatka 2–25 pól');
        if (p.targetState.length != cells) {
          issues.add('toggle_grid: targetState ma ${p.targetState.length} pól, siatka $cells');
        }
        if (p.labels.isNotEmpty && p.labels.length != cells) {
          issues.add('toggle_grid: labels musi mieć $cells elementów albo być puste');
        }
      case DialCombinationPuzzle p:
        if (p.dials.isEmpty || p.dials.length > 6) issues.add('dial_combination: 1–6 pokręteł');
        if (p.answer.length != p.dials.length) {
          issues.add('dial_combination: answer ma inną długość niż dials');
        }
        for (var i = 0; i < p.dials.length && i < p.answer.length; i++) {
          final d = p.dials[i];
          if (d.min >= d.max) issues.add('dial_combination: pokrętło "${d.label}" ma min ≥ max');
          if (p.answer[i] < d.min || p.answer[i] > d.max) {
            issues.add('dial_combination: wartość ${p.answer[i]} poza zakresem pokrętła "${d.label}"');
          }
        }
      case OpenExplanationPuzzle p:
        if (p.rubric.trim().isEmpty) issues.add('open_explanation: brak rubric');
    }
    return issues;
  }

  /// Non-fatal quality problems: the answer is handed to the player literally,
  /// so no reasoning is needed. Fed back to the AI designer.
  ///
  /// [sceneClues]: the stage spreads its data over scene objects (clue chain),
  /// so a widget without its own clue list is fine.
  static List<String> qualityIssues(Puzzle puzzle, {bool sceneClues = false}) {
    final issues = <String>[];
    final prompt = normalizeText(puzzle.prompt);
    final numbersInPrompt = RegExp(r'\d+').allMatches(puzzle.prompt).map((m) => m.group(0)!).toList();
    switch (puzzle) {
      case DialCombinationPuzzle p:
        // Every target value appears as a number in the prompt, in order.
        var pos = 0;
        var all = true;
        for (final v in p.answer) {
          final i = numbersInPrompt.indexOf('$v', pos);
          if (i < 0) {
            all = false;
            break;
          }
          pos = i + 1;
        }
        if (all && p.answer.isNotEmpty) {
          issues.add('dial_combination: wszystkie docelowe wartości (${p.answer.join(', ')}) są podane wprost w treści – gracz tylko przepisuje liczby. Ukryj je za wnioskowaniem (policz coś z danych w scenie, działanie na liczbach z fabuły, odczyt z tabelki).');
        }
      case PinCodePuzzle p:
        if (puzzle.prompt.replaceAll(RegExp(r'\s'), '').contains(p.answer)) {
          issues.add('pin_code: kod ${p.answer} pojawia się wprost w treści zagadki.');
        }
        if (p.clues.length < 3 && !sceneClues) {
          issues.add('pin_code: tylko ${p.clues.length} wskazówki – daj 3–5 logów błędnych prób albo rozłóż dane o kodzie na odkrycia (clue) obiektów sceny, aby kod trzeba było wydedukować.');
        }
      case TextAnswerPuzzle p:
        for (final a in p.acceptedAnswers) {
          final n = normalizeText(a);
          if (n.length >= 3 && RegExp('(^| )${RegExp.escape(n)}( |\$)').hasMatch(prompt)) {
            issues.add('text_answer: odpowiedź „$a” występuje dosłownie w treści zagadki.');
            break;
          }
        }
      case SequenceOrderPuzzle p:
        // The correct order spelled out in the prompt, in order.
        var pos = 0;
        var all = true;
        for (final item in p.correctOrder) {
          final i = prompt.indexOf(normalizeText(item), pos);
          if (i < 0) {
            all = false;
            break;
          }
          pos = i + 1;
        }
        if (all) {
          issues.add('sequence_order: poprawna kolejność jest wypisana wprost w treści – gracz tylko ją przepisuje. Podaj reguły/zależności, z których kolejność trzeba wywnioskować.');
        }
      case MultipleChoicePuzzle p:
        if (p.options.length < 3) {
          issues.add('multiple_choice: tylko ${p.options.length} opcje – daj co najmniej 3, aby wybór wymagał namysłu.');
        }
      case ToggleGridPuzzle p:
        final onLabels = [for (var i = 0; i < p.targetState.length && i < p.labels.length; i++) if (p.targetState[i]) normalizeText(p.labels[i])];
        // Single letters/digits ("A", "3") legitimately appear in the prompt.
        if (onLabels.isNotEmpty &&
            onLabels.every((l) => l.length >= 3 && RegExp('(^| )${RegExp.escape(l)}( |\$)').hasMatch(prompt))) {
          issues.add('toggle_grid: etykiety właściwych przełączników są wymienione wprost w treści – gracz tylko je odnajduje. Podaj regułę, z której wynika, które włączyć.');
        }
      case MatchingPuzzle _:
      case OpenExplanationPuzzle _:
        break;
    }
    return issues;
  }

  static List<String> _asStringList(Object a) =>
      a is List<String> ? a : (a as List).map((e) => e.toString()).toList();

  static Map<String, String> _asStringMap(Object a) => a is Map<String, String>
      ? a
      : (a as Map).map((k, v) => MapEntry(k.toString(), v.toString()));

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static int _pow10(int n) {
    var r = 1;
    for (var i = 0; i < n; i++) {
      r *= 10;
    }
    return r;
  }
}

extension on String {
  Iterable<String> get characters => runes.map(String.fromCharCode);
}
