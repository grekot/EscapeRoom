import 'dart:math';

import 'puzzle.dart';
import 'puzzle_validator.dart';

/// Deterministic fixes for mechanical mistakes the AI designer makes, applied
/// before validation so a game is not rejected for things the app can
/// compute itself (mastermind counts, permutations, dial ranges).
class PuzzleRepair {
  const PuzzleRepair._();

  /// [addPinClues] = false when the stage spreads the code's data over scene
  /// objects, so the widget must not get a mastermind log generated for it.
  static Puzzle repair(Puzzle p, {Random? rng, bool addPinClues = true}) => switch (p) {
        PinCodePuzzle x => repairPin(x, rng: rng, addClues: addPinClues),
        SequenceOrderPuzzle x => _repairSequence(x, rng: rng),
        DialCombinationPuzzle x => _repairDials(x),
        ToggleGridPuzzle x => _repairToggle(x),
        MatchingPuzzle x => _repairMatching(x),
        _ => p,
      };

  /// Recomputes inPlace/wrongPlace for every clue from the real answer, drops
  /// malformed clues, and adds clues until they pin down exactly one code.
  static PinCodePuzzle repairPin(PinCodePuzzle p, {Random? rng, bool addClues = true}) {
    final answer = p.answer.replaceAll(RegExp(r'\D'), '');
    final len = answer.isEmpty ? p.codeLength : answer.length;
    if (answer.isEmpty || len < 2 || len > 6) return p;
    final random = rng ?? Random(answer.hashCode);

    final clues = <PinClue>[];
    for (final c in p.clues) {
      final code = c.code.replaceAll(RegExp(r'\D'), '');
      if (code.length != len || code == answer) continue;
      if (clues.any((k) => k.code == code)) continue;
      final (ip, wp) = PuzzleValidator.pinFeedback(code, answer);
      // Keep the model's wording only when it was right; otherwise regenerate.
      final keepText = ip == c.inPlace && wp == c.wrongPlace && (c.text ?? '').trim().isNotEmpty;
      clues.add(PinClue(code: code, inPlace: ip, wrongPlace: wp, text: keepText ? c.text : null));
    }

    PinCodePuzzle build() => PinCodePuzzle(
          prompt: p.prompt,
          codeLength: len,
          answer: answer,
          clues: [for (final c in clues) PinClue(code: c.code, inPlace: c.inPlace, wrongPlace: c.wrongPlace, text: c.text ?? c.describe())],
        );

    if (!addClues && clues.isEmpty) return build();
    var candidates = PuzzleValidator.pinCandidates(build());
    var guard = 0;
    while ((candidates.length > 1 || clues.length < 3) && clues.length < 6 && guard++ < 12) {
      final best = _bestClue(answer, len, clues, candidates, random);
      if (best == null) break;
      final (ip, wp) = PuzzleValidator.pinFeedback(best, answer);
      clues.add(PinClue(code: best, inPlace: ip, wrongPlace: wp));
      candidates = PuzzleValidator.pinCandidates(build());
    }
    return build();
  }

  /// Picks a wrong code whose feedback eliminates the most remaining
  /// candidates (while never eliminating the answer, which is always consistent).
  static String? _bestClue(String answer, int len, List<PinClue> clues, List<String> candidates, Random random) {
    final pool = <String>{};
    for (final c in candidates.take(60)) {
      if (c != answer) pool.add(c);
    }
    final total = _pow10(len);
    for (var i = 0; i < 120; i++) {
      final code = random.nextInt(total).toString().padLeft(len, '0');
      if (code != answer) pool.add(code);
    }
    // For 3-digit codes with all-distinct digits a "nothing right" clue is
    // very informative; include a few such probes.
    for (var i = 0; i < 30; i++) {
      final digits = List.generate(10, (d) => '$d').where((d) => !answer.contains(d)).toList()..shuffle(random);
      if (digits.length >= len) pool.add(digits.take(len).join());
    }
    pool.removeWhere((c) => clues.any((k) => k.code == c));
    if (pool.isEmpty) return null;

    String? best;
    var bestLeft = 1 << 30;
    for (final code in pool) {
      final (ip, wp) = PuzzleValidator.pinFeedback(code, answer);
      var left = 0;
      for (final cand in candidates) {
        final (cip, cwp) = PuzzleValidator.pinFeedback(code, cand);
        if (cip == ip && cwp == wp) left++;
      }
      // Prefer clues that are informative but not "all right in place".
      final penalty = ip == len ? 1000 : 0;
      if (left + penalty < bestLeft) {
        bestLeft = left + penalty;
        best = code;
      }
    }
    return best;
  }

  static int _pow10(int n) {
    var r = 1;
    for (var i = 0; i < n; i++) {
      r *= 10;
    }
    return r;
  }

  /// Aligns items and correctOrder: matches by normalized text and, when the
  /// item list is incomplete, rebuilds it as a shuffled copy of the order.
  static SequenceOrderPuzzle _repairSequence(SequenceOrderPuzzle p, {Random? rng}) {
    if (p.correctOrder.length < 2) return p;
    final byNorm = {for (final it in p.items) PuzzleValidator.normalizeText(it): it};
    final aligned = <String>[];
    var ok = true;
    for (final o in p.correctOrder) {
      final hit = byNorm[PuzzleValidator.normalizeText(o)];
      if (hit == null) {
        ok = false;
        break;
      }
      aligned.add(hit);
    }
    if (ok && aligned.toSet().length == p.items.length && aligned.length == p.items.length) {
      return SequenceOrderPuzzle(prompt: p.prompt, items: p.items, correctOrder: aligned);
    }
    // Items do not match the order: the order is the source of truth.
    final order = p.correctOrder.toSet().toList();
    final items = List.of(order)..shuffle(rng ?? Random(order.join().hashCode));
    if (items.length > 1 && _sameOrder(items, order)) {
      items.add(items.removeAt(0));
    }
    return SequenceOrderPuzzle(prompt: p.prompt, items: items, correctOrder: order);
  }

  static bool _sameOrder(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Widens dial ranges so the answer fits.
  static DialCombinationPuzzle _repairDials(DialCombinationPuzzle p) {
    if (p.dials.length != p.answer.length) return p;
    final dials = <Dial>[];
    for (var i = 0; i < p.dials.length; i++) {
      final d = p.dials[i];
      final v = p.answer[i];
      var lo = min(d.min, d.max), hi = max(d.min, d.max);
      if (lo == hi) hi = lo + 9;
      if (v < lo) lo = v;
      if (v > hi) hi = v;
      dials.add(Dial(label: d.label, min: lo, max: hi));
    }
    return DialCombinationPuzzle(prompt: p.prompt, dials: dials, answer: p.answer);
  }

  /// Pads/trims targetState and labels to rows*cols.
  static ToggleGridPuzzle _repairToggle(ToggleGridPuzzle p) {
    final cells = p.rows * p.cols;
    if (cells < 2) return p;
    var state = List<bool>.of(p.targetState);
    if (state.length > cells) state = state.sublist(0, cells);
    while (state.length < cells) {
      state.add(false);
    }
    var labels = List<String>.of(p.labels);
    if (labels.isNotEmpty) {
      if (labels.length > cells) labels = labels.sublist(0, cells);
      while (labels.length < cells) {
        labels.add('${labels.length + 1}');
      }
    }
    return ToggleGridPuzzle(prompt: p.prompt, rows: p.rows, cols: p.cols, labels: labels, targetState: state);
  }

  /// Fills rightItems from the pairs when the designer forgot some, and maps
  /// pair values onto the closest existing right item.
  static MatchingPuzzle _repairMatching(MatchingPuzzle p) {
    final rights = List<String>.of(p.rightItems);
    final byNorm = {for (final r in rights) PuzzleValidator.normalizeText(r): r};
    final pairs = <String, String>{};
    for (final e in p.correctPairs.entries) {
      final hit = byNorm[PuzzleValidator.normalizeText(e.value)];
      if (hit != null) {
        pairs[e.key] = hit;
      } else {
        rights.add(e.value);
        byNorm[PuzzleValidator.normalizeText(e.value)] = e.value;
        pairs[e.key] = e.value;
      }
    }
    final lefts = List<String>.of(p.leftItems);
    for (final l in pairs.keys) {
      if (!lefts.contains(l)) lefts.add(l);
    }
    return MatchingPuzzle(prompt: p.prompt, leftItems: lefts, rightItems: rights, correctPairs: pairs);
  }
}
