import 'catalog.dart';
import 'json_utils.dart';

/// A puzzle the app can render and (mostly) check locally.
///
/// Each subtype maps 1:1 to an interactive widget in `features/game/puzzles`.
sealed class Puzzle {
  const Puzzle({required this.prompt});

  /// Text shown to the player above the widget.
  final String prompt;

  String get type;

  Map<String, dynamic> toJson();

  /// Parses a puzzle. Unknown types degrade to [TextAnswerPuzzle] when a
  /// plausible answer field exists, otherwise a [FormatException] is thrown.
  static Puzzle fromJson(Map<String, dynamic> j) {
    final type = jStr(j, 'type').toLowerCase().trim();
    switch (type) {
      case PuzzleTypes.sequenceOrder:
        return SequenceOrderPuzzle.fromJson(j);
      case PuzzleTypes.pinCode:
        return PinCodePuzzle.fromJson(j);
      case PuzzleTypes.multipleChoice:
        return MultipleChoicePuzzle.fromJson(j);
      case PuzzleTypes.textAnswer:
        return TextAnswerPuzzle.fromJson(j);
      case PuzzleTypes.matching:
        return MatchingPuzzle.fromJson(j);
      case PuzzleTypes.toggleGrid:
        return ToggleGridPuzzle.fromJson(j);
      case PuzzleTypes.dialCombination:
        return DialCombinationPuzzle.fromJson(j);
      case PuzzleTypes.openExplanation:
        return OpenExplanationPuzzle.fromJson(j);
      default:
        final answers = <String>[
          ...jStrList(j, 'acceptedAnswers'),
          ...jStrList(j, 'answer'),
          ...jStrList(j, 'solution'),
        ].where((s) => s.trim().isNotEmpty).toList();
        if (answers.isEmpty) {
          throw FormatException('Nieznany typ zagadki: "$type"');
        }
        return TextAnswerPuzzle(
          prompt: jStr(j, 'prompt'),
          acceptedAnswers: answers,
          normalize: true,
        );
    }
  }
}

/// Player drags items into the right order (wires, steps of a procedure).
class SequenceOrderPuzzle extends Puzzle {
  const SequenceOrderPuzzle({
    required super.prompt,
    required this.items,
    required this.correctOrder,
  });

  final List<String> items;
  final List<String> correctOrder;

  @override
  String get type => PuzzleTypes.sequenceOrder;

  factory SequenceOrderPuzzle.fromJson(Map<String, dynamic> j) =>
      SequenceOrderPuzzle(
        prompt: jStr(j, 'prompt'),
        items: jStrList(j, 'items'),
        correctOrder: jStrList(j, 'correctOrder'),
      );

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'prompt': prompt,
        'items': items,
        'correctOrder': correctOrder,
      };
}

/// One failed attempt shown on the safe ("mastermind" style clue).
class PinClue {
  const PinClue({
    required this.code,
    required this.inPlace,
    required this.wrongPlace,
    this.text,
  });

  final String code;

  /// Digits that are correct and in the right position.
  final int inPlace;

  /// Digits that are correct but in the wrong position.
  final int wrongPlace;

  /// Optional human wording; generated from the counts when missing.
  final String? text;

  factory PinClue.fromJson(Map<String, dynamic> j) => PinClue(
        code: jStr(j, 'code').replaceAll(RegExp(r'\D'), ''),
        inPlace: jInt(j, 'inPlace'),
        wrongPlace: jInt(j, 'wrongPlace'),
        text: jStrOrNull(j, 'text'),
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'inPlace': inPlace,
        'wrongPlace': wrongPlace,
        'text': text ?? describe(),
      };

  String describe() {
    if (inPlace == 0 && wrongPlace == 0) {
      return 'Żadna cyfra nie jest poprawna.';
    }
    final parts = <String>[];
    if (inPlace > 0) {
      parts.add(
          '${_count(inPlace)} na właściwym miejscu');
    }
    if (wrongPlace > 0) {
      parts.add(
          '${_count(wrongPlace)} na niewłaściwym miejscu');
    }
    return '${parts.join(', ')}.';
  }

  static String _count(int n) {
    if (n == 1) return 'jedna cyfra poprawna,';
    if (n >= 2 && n <= 4) return '$n cyfry poprawne,';
    return '$n cyfr poprawnych,';
  }
}

/// Numeric keypad with a list of failed attempts as clues.
class PinCodePuzzle extends Puzzle {
  const PinCodePuzzle({
    required super.prompt,
    required this.codeLength,
    required this.answer,
    required this.clues,
  });

  final int codeLength;
  final String answer;
  final List<PinClue> clues;

  @override
  String get type => PuzzleTypes.pinCode;

  factory PinCodePuzzle.fromJson(Map<String, dynamic> j) {
    final answer = jStr(j, 'answer').replaceAll(RegExp(r'\D'), '');
    final len = jInt(j, 'codeLength', fallback: answer.length);
    return PinCodePuzzle(
      prompt: jStr(j, 'prompt'),
      codeLength: len == 0 ? answer.length : len,
      answer: answer,
      clues: jMapList(j, 'clues').map(PinClue.fromJson).toList(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'prompt': prompt,
        'codeLength': codeLength,
        'answer': answer,
        'clues': clues.map((c) => c.toJson()).toList(),
      };
}

class MultipleChoicePuzzle extends Puzzle {
  const MultipleChoicePuzzle({
    required super.prompt,
    required this.options,
    required this.correctIndex,
  });

  final List<String> options;
  final int correctIndex;

  @override
  String get type => PuzzleTypes.multipleChoice;

  factory MultipleChoicePuzzle.fromJson(Map<String, dynamic> j) =>
      MultipleChoicePuzzle(
        prompt: jStr(j, 'prompt'),
        options: jStrList(j, 'options'),
        correctIndex: jInt(j, 'correctIndex'),
      );

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'prompt': prompt,
        'options': options,
        'correctIndex': correctIndex,
      };
}

/// Free text answer: password, riddle solution, decoded cipher.
class TextAnswerPuzzle extends Puzzle {
  const TextAnswerPuzzle({
    required super.prompt,
    required this.acceptedAnswers,
    this.normalize = true,
  });

  final List<String> acceptedAnswers;

  /// When true, compare case-insensitively, ignoring diacritics/punctuation.
  final bool normalize;

  @override
  String get type => PuzzleTypes.textAnswer;

  factory TextAnswerPuzzle.fromJson(Map<String, dynamic> j) => TextAnswerPuzzle(
        prompt: jStr(j, 'prompt'),
        acceptedAnswers: jStrList(j, 'acceptedAnswers'),
        normalize: jBool(j, 'normalize', fallback: true),
      );

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'prompt': prompt,
        'acceptedAnswers': acceptedAnswers,
        'normalize': normalize,
      };
}

/// Pair every left item with exactly one right item (labels ↔ boxes).
class MatchingPuzzle extends Puzzle {
  const MatchingPuzzle({
    required super.prompt,
    required this.leftItems,
    required this.rightItems,
    required this.correctPairs,
  });

  final List<String> leftItems;
  final List<String> rightItems;

  /// left → right
  final Map<String, String> correctPairs;

  @override
  String get type => PuzzleTypes.matching;

  factory MatchingPuzzle.fromJson(Map<String, dynamic> j) {
    final pairs = <String, String>{};
    final raw = j['correctPairs'];
    if (raw is List) {
      for (final p in raw) {
        if (p is List && p.length >= 2) {
          pairs[p[0].toString()] = p[1].toString();
        } else if (p is Map) {
          final m = p.map((k, v) => MapEntry(k.toString(), v));
          final l = m['left'] ?? m['l'];
          final r = m['right'] ?? m['r'];
          if (l != null && r != null) pairs[l.toString()] = r.toString();
        }
      }
    } else if (raw is Map) {
      raw.forEach((k, v) => pairs[k.toString()] = v.toString());
    }
    return MatchingPuzzle(
      prompt: jStr(j, 'prompt'),
      leftItems: jStrList(j, 'leftItems'),
      rightItems: jStrList(j, 'rightItems'),
      correctPairs: pairs,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'prompt': prompt,
        'leftItems': leftItems,
        'rightItems': rightItems,
        'correctPairs':
            correctPairs.entries.map((e) => [e.key, e.value]).toList(),
      };
}

/// Grid of switches/levers; the player must reproduce [targetState].
class ToggleGridPuzzle extends Puzzle {
  const ToggleGridPuzzle({
    required super.prompt,
    required this.rows,
    required this.cols,
    required this.labels,
    required this.targetState,
  });

  final int rows;
  final int cols;

  /// One label per cell (row-major). May be empty.
  final List<String> labels;
  final List<bool> targetState;

  @override
  String get type => PuzzleTypes.toggleGrid;

  factory ToggleGridPuzzle.fromJson(Map<String, dynamic> j) => ToggleGridPuzzle(
        prompt: jStr(j, 'prompt'),
        rows: jInt(j, 'rows', fallback: 1),
        cols: jInt(j, 'cols', fallback: 1),
        labels: jStrList(j, 'labels'),
        targetState: jBoolList(j, 'targetState'),
      );

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'prompt': prompt,
        'rows': rows,
        'cols': cols,
        'labels': labels,
        'targetState': targetState,
      };
}

class Dial {
  const Dial({required this.label, required this.min, required this.max});

  final String label;
  final int min;
  final int max;

  factory Dial.fromJson(Map<String, dynamic> j) => Dial(
        label: jStr(j, 'label'),
        min: jInt(j, 'min'),
        max: jInt(j, 'max', fallback: 9),
      );

  Map<String, dynamic> toJson() => {'label': label, 'min': min, 'max': max};
}

/// Several dials/sliders that must be set to the right values.
class DialCombinationPuzzle extends Puzzle {
  const DialCombinationPuzzle({
    required super.prompt,
    required this.dials,
    required this.answer,
  });

  final List<Dial> dials;
  final List<int> answer;

  @override
  String get type => PuzzleTypes.dialCombination;

  factory DialCombinationPuzzle.fromJson(Map<String, dynamic> j) =>
      DialCombinationPuzzle(
        prompt: jStr(j, 'prompt'),
        dials: jMapList(j, 'dials').map(Dial.fromJson).toList(),
        answer: jIntList(j, 'answer'),
      );

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'prompt': prompt,
        'dials': dials.map((d) => d.toJson()).toList(),
        'answer': answer,
      };
}

/// Player explains a method in prose; an AI judge grades it against [rubric].
class OpenExplanationPuzzle extends Puzzle {
  const OpenExplanationPuzzle({
    required super.prompt,
    required this.rubric,
    required this.exampleSolution,
  });

  /// What a correct answer must contain (for the AI judge, never shown).
  final String rubric;
  final String exampleSolution;

  @override
  String get type => PuzzleTypes.openExplanation;

  factory OpenExplanationPuzzle.fromJson(Map<String, dynamic> j) =>
      OpenExplanationPuzzle(
        prompt: jStr(j, 'prompt'),
        rubric: jStr(j, 'rubric'),
        exampleSolution: jStr(j, 'exampleSolution'),
      );

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'prompt': prompt,
        'rubric': rubric,
        'exampleSolution': exampleSolution,
      };
}
