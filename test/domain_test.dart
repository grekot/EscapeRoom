import 'dart:convert';
import 'dart:io';

import 'package:escape_room/core/ai/ai_provider.dart';
import 'package:escape_room/core/ai/pipeline/scenario_importer.dart';
import 'package:escape_room/domain/catalog.dart';
import 'package:escape_room/domain/game_spec.dart';
import 'package:escape_room/domain/game_spec_validator.dart';
import 'package:escape_room/domain/prop_binding.dart';
import 'package:escape_room/domain/puzzle.dart';
import 'package:escape_room/domain/puzzle_validator.dart';
import 'package:escape_room/domain/scenario_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('built-in assets', () {
    test('markdown scenario parses with 5 stages and round-trips', () {
      final md = File('assets/scenarios/warsztat_wynalazcy.md')
          .readAsStringSync();
      final s = ScenarioMarkdown.tryParse(md, id: 'x')!;
      expect(s.title, 'Warsztat Wynalazcy');
      expect(s.targetAge, 11);
      expect(s.difficulty, Difficulty.medium);
      expect(s.stages, hasLength(5));
      expect(s.intro, contains('stalowe drzwi'));
      expect(s.outro, contains('Jesteście wolni'));
      final st = s.stages[1];
      expect(st.title, 'Sejf z logami');
      expect(st.hints, hasLength(3));
      expect(st.suggestedType, PuzzleTypes.pinCode);
      expect(st.puzzle, contains('6 8 2'));
      expect(s.validate(), isEmpty);

      final again = ScenarioMarkdown.tryParse(ScenarioMarkdown.toMarkdown(s),
          id: 'y')!;
      expect(again.stages.length, s.stages.length);
      for (var i = 0; i < s.stages.length; i++) {
        expect(again.stages[i].title, s.stages[i].title);
        expect(again.stages[i].solution, s.stages[i].solution);
        expect(again.stages[i].hints, s.stages[i].hints);
        expect(again.stages[i].suggestedType, s.stages[i].suggestedType);
      }
    });

    test('game spec JSON parses and validates clean', () {
      final raw = File('assets/gamespecs/warsztat_wynalazcy.json')
          .readAsStringSync();
      final spec = GameSpec.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      expect(spec.stages, hasLength(5));
      expect(spec.visualTheme, VisualTheme.laboratory);
      expect(GameSpecValidator.validate(spec), isEmpty);
      // round trip
      final again = GameSpec.fromJson(spec.toJson());
      expect(GameSpecValidator.validate(again), isEmpty);
      expect(again.stages[1].puzzle, isA<PinCodePuzzle>());
    });

    test('lighthouse game: props, prompts and puzzles are sound', () {
      final raw = File('assets/gamespecs/latarnia_w_sztormie.json')
          .readAsStringSync();
      final spec = GameSpec.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      expect(spec.stages, hasLength(4));
      expect(GameSpecValidator.validate(spec), isEmpty);
      for (final st in spec.stages) {
        expect(st.scene.props.length, greaterThanOrEqualTo(3), reason: st.title);
        expect(st.scene.imagePrompt, isNotEmpty, reason: st.title);
        for (final p in st.scene.props) {
          expect(PropTypes.all.containsKey(p.type), isTrue, reason: p.type);
          expect(p.x, inInclusiveRange(0, 1));
          expect(p.y, inInclusiveRange(0, 1));
        }
      }
      final pin = spec.stages[3].puzzle as PinCodePuzzle;
      expect(PuzzleValidator.pinCandidates(pin), ['593']);
      final seq = spec.stages[2].puzzle as SequenceOrderPuzzle;
      expect(seq.correctOrder.first, 'Włącz pompę oleju');
      // round trip keeps props and prompts
      final again = GameSpec.fromJson(spec.toJson());
      expect(again.stages[0].scene.props.length, spec.stages[0].scene.props.length);
      expect(again.stages[0].scene.imagePrompt, spec.stages[0].scene.imagePrompt);
      expect(again.hasImages, isTrue); // bundled illustrations

      final md = File('assets/scenarios/latarnia_w_sztormie.md').readAsStringSync();
      final sc = ScenarioMarkdown.tryParse(md, id: 'l')!;
      expect(sc.stages, hasLength(4));
      expect(sc.validate(), isEmpty);
    });

    test('bundled games: every object is reachable on the picture and props depict their objects', () {
      for (final path in [
        'assets/gamespecs/warsztat_wynalazcy.json',
        'assets/gamespecs/latarnia_w_sztormie.json',
      ]) {
        final spec = GameSpec.fromJson(
            jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>);
        for (final st in spec.stages) {
          final fixed = PropBinding.fix(st);
          expect(fixed.scene.props.map((p) => p.type).toList(),
              st.scene.props.map((p) => p.type).toList(),
              reason: '$path / ${st.title}: prop type mismatch');
          final depicted = st.scene.props.map((p) => p.objectId).whereType<String>().toSet();
          for (final o in st.scene.objects) {
            expect(depicted.contains(o.id) || o.hasHotspot, isTrue,
                reason: '$path / ${st.title}: "${o.label}" has no prop and no hotspot');
          }
        }
      }
    });

    test('quality check flags puzzles that hand over the answer', () {
      expect(
        PuzzleValidator.qualityIssues(const DialCombinationPuzzle(
          prompt: 'Ustawcie czas na 12 godzin, 15 minut i 30 sekund.',
          dials: [Dial(label: 'h', min: 0, max: 23), Dial(label: 'm', min: 0, max: 59), Dial(label: 's', min: 0, max: 59)],
          answer: [12, 15, 30],
        )).join(),
        contains('podane wprost'),
      );
      expect(
        PuzzleValidator.qualityIssues(const DialCombinationPuzzle(
          prompt: 'Godzina to liczba peronów (tablica: 12), minuty to kwadrans, sekundy to połowa minuty.',
          dials: [Dial(label: 'h', min: 0, max: 23), Dial(label: 'm', min: 0, max: 59), Dial(label: 's', min: 0, max: 59)],
          answer: [12, 15, 30],
        )),
        isEmpty,
      );
      expect(
        PuzzleValidator.qualityIssues(const SequenceOrderPuzzle(
          prompt: 'Ułóżcie pociągi w kolejności: Ekspres 102, Podmiejski 204, Towarowy 301.',
          items: ['Towarowy 301', 'Ekspres 102', 'Podmiejski 204'],
          correctOrder: ['Ekspres 102', 'Podmiejski 204', 'Towarowy 301'],
        )).join(),
        contains('wypisana wprost'),
      );
      expect(
        PuzzleValidator.qualityIssues(const TextAnswerPuzzle(prompt: 'Hasło to sowa. Wpisz hasło.', acceptedAnswers: ['sowa'])).join(),
        contains('dosłownie'),
      );
      expect(
        PuzzleValidator.qualityIssues(const PinCodePuzzle(prompt: 'Wpisz kod 485.', codeLength: 3, answer: '485', clues: [])).join(),
        contains('wprost'),
      );
      // bundled games are not trivial
      for (final path in ['assets/gamespecs/warsztat_wynalazcy.json', 'assets/gamespecs/latarnia_w_sztormie.json']) {
        final spec = GameSpec.fromJson(jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>);
        expect(GameSpecValidator.quality(spec), isEmpty, reason: path);
      }
    });

    test('props bound to objects are re-typed to depict them', () {
      final stage = GameStage(
        id: 's',
        title: 't',
        narrative: 'n',
        scene: const Scene(
          backdrop: 'workshop',
          ambientColor: '#000000',
          lighting: Lighting.dark,
          objects: [
            SceneObject(id: 'parchment', label: 'Pergamin', icon: 'note', description: 'd'),
            SceneObject(id: 'boiler', label: 'Kocioł', icon: 'flask', description: 'd'),
            SceneObject(id: 'table', label: 'Stół', icon: 'table', description: 'd'),
          ],
          props: [
            SceneProp(type: 'candle', x: 0.5, y: 0.5, objectId: 'parchment'),
            SceneProp(type: 'valve', x: 0.2, y: 0.5, objectId: 'boiler'),
            SceneProp(type: 'steam', x: 0.2, y: 0.3, objectId: 'boiler'),
            SceneProp(type: 'crystal', x: 0.8, y: 0.5, objectId: 'table'),
            SceneProp(type: 'candle', x: 0.9, y: 0.9),
          ],
        ),
        puzzle: const TextAnswerPuzzle(prompt: 'p', acceptedAnswers: ['a']),
        hints: const ['1', '2', '3'],
        fallbackTexts: const FallbackTexts(success: 's', failure: 'f', stuck: 'k'),
        effectOnSuccess: SuccessEffect.none,
      );
      final fixed = PropBinding.fix(stage).scene.props.map((p) => p.type).toList();
      // candle on a parchment → scroll; valve on a flask-cauldron stays;
      // steam is an effect; icons without a counterpart and unbound props stay.
      expect(fixed, ['scroll', 'valve', 'steam', 'crystal', 'candle']);
      expect(PropBinding.replacementFor('note', 'candle'), 'scroll');
      expect(PropBinding.replacementFor('lock', 'chest'), isNull);
    });

    test('prop json tolerates percentages and unknown types', () {
      final p = SceneProp.fromJson({'type': 'hologram', 'x': 40, 'y': '0.7', 'size': 0.9});
      expect(p.type, 'lamp');
      expect(p.x, 0.4);
      expect(p.y, 0.7);
      expect(p.size, 0.6);
    });

    test('importer recognises markdown and json locally', () {
      final md = File('assets/scenarios/warsztat_wynalazcy.md')
          .readAsStringSync();
      final r1 = ScenarioImporter.parseLocal(md, id: 'a')!;
      expect(r1.method, ImportMethod.markdown);
      final json = jsonEncode(r1.scenario.toJson());
      final r2 = ScenarioImporter.parseLocal(json, id: 'b')!;
      expect(r2.method, ImportMethod.json);
      expect(r2.scenario.stages.length, 5);
      expect(ScenarioImporter.parseLocal('to nie jest scenariusz', id: 'c'),
          isNull);
    });
  });

  group('pin code logic', () {
    const p = PinCodePuzzle(
      prompt: 'x',
      codeLength: 3,
      answer: '042',
      clues: [
        PinClue(code: '682', inPlace: 1, wrongPlace: 0),
        PinClue(code: '614', inPlace: 0, wrongPlace: 1),
        PinClue(code: '206', inPlace: 0, wrongPlace: 2),
        PinClue(code: '738', inPlace: 0, wrongPlace: 0),
        PinClue(code: '380', inPlace: 0, wrongPlace: 1),
      ],
    );

    test('feedback counts', () {
      expect(PuzzleValidator.pinFeedback('682', '042'), (1, 0));
      expect(PuzzleValidator.pinFeedback('206', '042'), (0, 2));
      expect(PuzzleValidator.pinFeedback('738', '042'), (0, 0));
      expect(PuzzleValidator.pinFeedback('1122', '2211'), (0, 4));
      expect(PuzzleValidator.pinFeedback('1123', '1133'), (3, 0));
    });

    test('clues determine exactly one code', () {
      expect(PuzzleValidator.pinCandidates(p), ['042']);
      expect(PuzzleValidator.validate(p), isEmpty);
    });

    test('inconsistent clue is reported', () {
      final bad = PinCodePuzzle(
        prompt: 'x',
        codeLength: 3,
        answer: '042',
        clues: const [PinClue(code: '682', inPlace: 0, wrongPlace: 1)],
      );
      expect(PuzzleValidator.validate(bad).join(), contains('sprzeczna'));
    });

    test('ambiguous clues are reported', () {
      final amb = PinCodePuzzle(
        prompt: 'x',
        codeLength: 3,
        answer: '042',
        clues: const [PinClue(code: '738', inPlace: 0, wrongPlace: 0)],
      );
      expect(PuzzleValidator.validate(amb).join(), contains('dopuszczają'));
    });

    test('check answer', () {
      expect((PuzzleValidator.check(p, '042') as LocalResult).correct, isTrue);
      expect((PuzzleValidator.check(p, '0 4 2') as LocalResult).correct, isTrue);
      expect((PuzzleValidator.check(p, '024') as LocalResult).correct, isFalse);
    });
  });

  group('other puzzles', () {
    test('sequence order', () {
      const p = SequenceOrderPuzzle(
        prompt: 'x',
        items: ['Czerwony', 'Biały', 'Zielony', 'Czarny'],
        correctOrder: ['Zielony', 'Czarny', 'Czerwony', 'Biały'],
      );
      expect(PuzzleValidator.validate(p), isEmpty);
      final ok = PuzzleValidator.check(
          p, ['zielony', 'czarny', 'czerwony', 'bialy']) as LocalResult;
      expect(ok.correct, isTrue);
      final bad = PuzzleValidator.check(
          p, ['Zielony', 'Czerwony', 'Czarny', 'Biały']) as LocalResult;
      expect(bad.correct, isFalse);
      expect(bad.detail, contains('2 z 4'));
      const broken = SequenceOrderPuzzle(
          prompt: 'x', items: ['a', 'b'], correctOrder: ['a', 'c']);
      expect(PuzzleValidator.validate(broken).join(), contains('permutacją'));
    });

    test('text answer normalisation', () {
      const p = TextAnswerPuzzle(prompt: 'x', acceptedAnswers: ['Żółw']);
      expect(PuzzleValidator.normalizeText('  ŻÓŁW! '), 'zolw');
      expect((PuzzleValidator.check(p, 'zolw') as LocalResult).correct, isTrue);
      expect((PuzzleValidator.check(p, 'żółwik') as LocalResult).correct,
          isFalse);
    });

    test('matching', () {
      const p = MatchingPuzzle(
        prompt: 'x',
        leftItems: ['A', 'B'],
        rightItems: ['1', '2'],
        correctPairs: {'A': '2', 'B': '1'},
      );
      expect(PuzzleValidator.validate(p), isEmpty);
      expect(
          (PuzzleValidator.check(p, {'A': '2', 'B': '1'}) as LocalResult)
              .correct,
          isTrue);
      expect(
          (PuzzleValidator.check(p, {'A': '1', 'B': '2'}) as LocalResult)
              .correct,
          isFalse);
      const dup = MatchingPuzzle(
        prompt: 'x',
        leftItems: ['A', 'B'],
        rightItems: ['1', '2'],
        correctPairs: {'A': '1', 'B': '1'},
      );
      expect(PuzzleValidator.validate(dup).join(), contains('wielokrotnie'));
    });

    test('toggle grid and dials', () {
      const g = ToggleGridPuzzle(
          prompt: 'x',
          rows: 2,
          cols: 2,
          labels: [],
          targetState: [true, false, false, true]);
      expect(PuzzleValidator.validate(g), isEmpty);
      expect(
          (PuzzleValidator.check(g, [true, false, false, true]) as LocalResult)
              .correct,
          isTrue);
      const d = DialCombinationPuzzle(
          prompt: 'x',
          dials: [Dial(label: 'a', min: 0, max: 9), Dial(label: 'b', min: 1, max: 5)],
          answer: [7, 3]);
      expect(PuzzleValidator.validate(d), isEmpty);
      expect((PuzzleValidator.check(d, [7, 3]) as LocalResult).correct, isTrue);
      const out = DialCombinationPuzzle(
          prompt: 'x', dials: [Dial(label: 'a', min: 0, max: 9)], answer: [12]);
      expect(PuzzleValidator.validate(out).join(), contains('poza zakresem'));
    });

    test('open explanation needs AI', () {
      const p = OpenExplanationPuzzle(
          prompt: 'x', rubric: 'r', exampleSolution: 'e');
      expect(PuzzleValidator.check(p, 'blah'), isA<NeedsAiJudgement>());
    });

    test('unknown type degrades to text_answer', () {
      final p = Puzzle.fromJson({
        'type': 'riddle',
        'prompt': 'Co to?',
        'answer': 'cień',
      });
      expect(p, isA<TextAnswerPuzzle>());
      expect(() => Puzzle.fromJson({'type': 'weird', 'prompt': 'x'}),
          throwsFormatException);
    });
  });

  group('json extraction', () {
    test('handles fences and prose', () {
      expect(parseJsonObject('```json\n{"a":1}\n```')['a'], 1);
      expect(parseJsonObject('Oto wynik: {"a":{"b":[1,2]}} koniec')['a']['b'],
          [1, 2]);
      expect(() => parseJsonObject('nic tu nie ma'), throwsA(anything));
    });
  });
}
