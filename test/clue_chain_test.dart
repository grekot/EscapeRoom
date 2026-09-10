import 'dart:convert';

import 'package:escape_room/app/theme.dart';
import 'package:escape_room/core/ai/pipeline/game_master.dart';
import 'package:escape_room/domain/catalog.dart';
import 'package:escape_room/domain/game_save.dart';
import 'package:escape_room/domain/game_spec.dart';
import 'package:escape_room/domain/game_spec_validator.dart';
import 'package:escape_room/domain/puzzle.dart';
import 'package:escape_room/domain/puzzle_repair.dart';
import 'package:escape_room/features/game/widgets/scene_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _pin = PinCodePuzzle(
  prompt: 'Wpiszcie kod zamka.',
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

GameStage _stage(List<SceneObject> objects, {Puzzle puzzle = _pin}) => GameStage(
      id: 's1',
      title: 'Krypta',
      narrative: 'n',
      scene: Scene(backdrop: 'vault', ambientColor: '#334455', lighting: Lighting.dark, objects: objects),
      puzzle: puzzle,
      hints: const ['h1', 'h2', 'h3'],
      fallbackTexts: const FallbackTexts(success: 's', failure: 'f', stuck: 'st'),
      effectOnSuccess: SuccessEffect.none,
    );

GameSpec _spec(List<GameStage> stages, {Difficulty difficulty = Difficulty.medium}) => GameSpec(
      id: 'g',
      scenarioId: 'sc',
      title: 'T',
      intro: 'i',
      outro: 'o',
      difficulty: difficulty,
      targetAge: 10,
      visualTheme: VisualTheme.castle,
      stages: stages,
      createdAt: DateTime(2026),
      designedBy: 'test',
    );

const _plaque = SceneObject(
    id: 'plaque', label: 'Tabliczka', icon: 'note', description: 'Mosiężna tabliczka.',
    clue: 'Klucz: trójkąt = 4, koło = 2, kwadrat = 0.');
const _chest = SceneObject(
    id: 'chest', label: 'Skrzynia', icon: 'box', description: 'Na wieku trzy symbole.',
    clue: 'Symbole: kwadrat, trójkąt, koło.', requires: 'plaque',
    lockedText: 'Symbole nic Wam jeszcze nie mówią.');
const _lock = SceneObject(id: 'lock', label: 'Zamek', icon: 'lock', description: 'Trzy cyfry.');

void main() {
  test('scene object keeps clue chain fields through JSON', () {
    final o = SceneObject.fromJson(jsonDecode(jsonEncode(_chest.toJson())) as Map<String, dynamic>, 0);
    expect(o.clue, _chest.clue);
    expect(o.requires, 'plaque');
    expect(o.lockedText, _chest.lockedText);
    expect(o.hasClue, isTrue);
    expect(o.isChained, isTrue);
    expect(_lock.hasClue, isFalse);
    final scene = _stage([_plaque, _chest, _lock]).scene;
    expect(scene.hasClueChain, isTrue);
    expect(scene.objectById('chest')!.requires, 'plaque');
  });

  test('validator rejects broken requires links and clue-less pin without a chain', () {
    final missing = _stage([_plaque, const SceneObject(id: 'x', label: 'X', icon: 'box', description: 'd', clue: 'c', requires: 'ghost')]);
    expect(GameSpecValidator.validate(_spec([missing, missing])).join(), contains('requires="ghost"'));

    final a = const SceneObject(id: 'a', label: 'A', icon: 'box', description: 'd', clue: 'c', requires: 'b');
    final b = const SceneObject(id: 'b', label: 'B', icon: 'box', description: 'd', clue: 'c', requires: 'a');
    expect(GameSpecValidator.validate(_spec([_stage([a, b]), _stage([a, b])])).join(), contains('cykl'));

    const noClues = PinCodePuzzle(prompt: 'Wpiszcie kod.', codeLength: 3, answer: '042', clues: []);
    final bare = _stage([_lock], puzzle: noClues);
    expect(GameSpecValidator.validate(_spec([bare, bare])).join(), contains('pin_code bez wskazówek'));
    final chained = _stage([_plaque, _chest, _lock], puzzle: noClues);
    expect(GameSpecValidator.validate(_spec([chained, chained])), isEmpty);
  });

  test('quality demands findings spread over objects for medium/hard', () {
    final flat = _stage([_lock, const SceneObject(id: 'c', label: 'Świeca', icon: 'candle', description: 'Płonie.')]);
    final issues = GameSpecValidator.quality(_spec([flat, flat]));
    expect(issues.join(), contains('brak łańcucha wskazówek'));

    final good = _stage([_plaque, _chest, _lock]);
    expect(GameSpecValidator.quality(_spec([good, good])).where((i) => i.contains('łańcucha')), isEmpty);
    // hard wants at least one dependency
    final unlinked = _stage([_plaque, const SceneObject(id: 'd', label: 'D', icon: 'box', description: 'd', clue: 'c'), _lock]);
    expect(GameSpecValidator.quality(_spec([unlinked, unlinked], difficulty: Difficulty.hard)).join(), contains('requires'));
    // easy games are exempt
    expect(GameSpecValidator.quality(_spec([flat, flat], difficulty: Difficulty.easy)).where((i) => i.contains('łańcucha')), isEmpty);
  });

  test('pin repair leaves an empty clue list alone when the scene carries the data', () {
    const p = PinCodePuzzle(prompt: 'x', codeLength: 3, answer: '042', clues: []);
    final kept = PuzzleRepair.repair(p, addPinClues: false) as PinCodePuzzle;
    expect(kept.clues, isEmpty);
    final filled = PuzzleRepair.repair(p) as PinCodePuzzle;
    expect(filled.clues.length, greaterThanOrEqualTo(3));
  });

  test('save remembers examined objects per stage', () {
    var save = GameSave.start(id: 's', gameSpecId: 'g', stageCount: 2)
        .withDiscovered(0, 'plaque')
        .withDiscovered(0, 'plaque')
        .withDiscovered(1, 'lamp');
    save = GameSave.fromJson(jsonDecode(jsonEncode(save.toJson())) as Map<String, dynamic>);
    expect(save.discovered, ['0:plaque', '1:lamp']);
    expect(save.discoveredIn(0), {'plaque'});
    expect(save.discoveredIn(1), {'lamp'});
  });

  test('inspect event tells the GM about locked findings', () {
    const locked = ObjectInspected(_chest, locked: true);
    expect(locked.describe(), contains('ZABLOKOWANY'));
    expect(locked.describe(), contains('plaque'));
    expect(locked.describe(), isNot(contains('Symbole: kwadrat')));
    expect(locked.fallbackText, _chest.lockedText);
    const open = ObjectInspected(_chest);
    expect(open.describe(), contains('Symbole: kwadrat'));
    expect(open.fallbackText, contains('Symbole: kwadrat'));
  });

  testWidgets('close-up shows the finding once its prerequisite was examined', (tester) async {
    final discovered = <String>{};
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            child: SceneView(
              stage: _stage([_plaque, _chest, _lock]),
              palette: ThemePalette.of(VisualTheme.castle),
              enabled: true,
              discovered: discovered,
              onInspect: (o) {
                final locked = o.isChained && !discovered.contains(o.requires);
                if (!locked) setState(() => discovered.add(o.id));
              },
            ),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    // chips carry an "unexplored" dot until examined
    expect(find.text('Skrzynia'), findsWidgets);

    await tester.tap(find.widgetWithText(InkWell, 'Skrzynia'));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text(_chest.lockedText), findsOneWidget);
    expect(find.textContaining('Symbole: kwadrat'), findsNothing);

    // leave the close-up, examine the plaque, then the chest again
    await tester.tap(find.text('Wróć'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.widgetWithText(InkWell, 'Tabliczka'));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.textContaining('Odkrycie: Klucz'), findsOneWidget);
    await tester.tap(find.text('Wróć'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.widgetWithText(InkWell, 'Skrzynia'));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.textContaining('Odkrycie: Symbole'), findsOneWidget);
    expect(discovered, {'plaque', 'chest'});
  });
}
