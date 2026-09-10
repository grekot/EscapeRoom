import 'dart:math';

import 'package:escape_room/domain/puzzle.dart';
import 'package:escape_room/domain/puzzle_repair.dart';
import 'package:escape_room/domain/puzzle_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pin repair', () {
    test('recomputes wrong clue counts and keeps the code unique', () {
      // The model claimed "345" has 0 in place; against 385 it is actually 2.
      const broken = PinCodePuzzle(
        prompt: 'x',
        codeLength: 3,
        answer: '385',
        clues: [
          PinClue(code: '345', inPlace: 0, wrongPlace: 2, text: 'zle'),
          PinClue(code: '712', inPlace: 0, wrongPlace: 0, text: 'Nic.'),
        ],
      );
      final fixed = PuzzleRepair.repairPin(broken, rng: Random(1));
      expect(PuzzleValidator.validate(fixed), isEmpty);
      expect(PuzzleValidator.pinCandidates(fixed), ['385']);
      final c345 = fixed.clues.firstWhere((c) => c.code == '345');
      expect(c345.inPlace, 2);
      expect(c345.wrongPlace, 0);
      expect(c345.text, isNot('zle')); // regenerated wording
      final c712 = fixed.clues.firstWhere((c) => c.code == '712');
      expect(c712.text, 'Nic.'); // correct clue keeps its wording
      expect(fixed.clues.length, inInclusiveRange(3, 6));
    });

    test('adds clues to a puzzle with none', () {
      const p = PinCodePuzzle(prompt: 'x', codeLength: 4, answer: '2071', clues: []);
      final fixed = PuzzleRepair.repairPin(p, rng: Random(3));
      expect(PuzzleValidator.pinCandidates(fixed), ['2071']);
      expect(fixed.clues.length, inInclusiveRange(3, 6));
      expect(fixed.clues.any((c) => c.code == '2071'), isFalse);
    });

    test('leaves an already sound puzzle unchanged', () {
      const p = PinCodePuzzle(
        prompt: 'x',
        codeLength: 3,
        answer: '042',
        clues: [
          PinClue(code: '682', inPlace: 1, wrongPlace: 0, text: 'a'),
          PinClue(code: '614', inPlace: 0, wrongPlace: 1, text: 'b'),
          PinClue(code: '206', inPlace: 0, wrongPlace: 2, text: 'c'),
          PinClue(code: '738', inPlace: 0, wrongPlace: 0, text: 'd'),
          PinClue(code: '380', inPlace: 0, wrongPlace: 1, text: 'e'),
        ],
      );
      final fixed = PuzzleRepair.repairPin(p);
      expect(fixed.clues.map((c) => c.code), p.clues.map((c) => c.code));
      expect(fixed.clues.map((c) => c.text), ['a', 'b', 'c', 'd', 'e']);
    });
  });

  test('sequence repair aligns spelling and rebuilds missing items', () {
    const p = SequenceOrderPuzzle(
      prompt: 'x',
      items: ['zapal palnik', 'Zamknij okiennice'],
      correctOrder: ['Zamknij okiennice', 'Zapal palnik', 'Otwórz przesłonę'],
    );
    final fixed = PuzzleRepair.repair(p) as SequenceOrderPuzzle;
    expect(PuzzleValidator.validate(fixed), isEmpty);
    expect(fixed.correctOrder, p.correctOrder);
    expect(fixed.items.toSet(), p.correctOrder.toSet());
    expect(fixed.items, isNot(p.correctOrder)); // shuffled
  });

  test('dial repair widens ranges; toggle repair pads state; matching repair fills rights', () {
    final d = PuzzleRepair.repair(const DialCombinationPuzzle(
      prompt: 'x',
      dials: [Dial(label: 'a', min: 0, max: 9), Dial(label: 'b', min: 5, max: 5)],
      answer: [12, 3],
    )) as DialCombinationPuzzle;
    expect(PuzzleValidator.validate(d), isEmpty);
    expect(d.dials[0].max, 12);
    expect(d.dials[1].min, 3);

    final t = PuzzleRepair.repair(const ToggleGridPuzzle(
      prompt: 'x', rows: 2, cols: 2, labels: ['a', 'b', 'c'], targetState: [true],
    )) as ToggleGridPuzzle;
    expect(PuzzleValidator.validate(t), isEmpty);
    expect(t.targetState, [true, false, false, false]);
    expect(t.labels.length, 4);

    final m = PuzzleRepair.repair(const MatchingPuzzle(
      prompt: 'x',
      leftItems: ['A', 'B'],
      rightItems: ['jeden'],
      correctPairs: {'A': 'Jeden', 'B': 'dwa'},
    )) as MatchingPuzzle;
    expect(PuzzleValidator.validate(m), isEmpty);
    expect(m.correctPairs['A'], 'jeden');
    expect(m.rightItems, ['jeden', 'dwa']);
  });
}
