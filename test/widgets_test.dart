import 'dart:convert';
import 'dart:io';

import 'package:escape_room/app/providers.dart';
import 'package:escape_room/app/theme.dart';
import 'package:escape_room/core/storage/json_file_store.dart';
import 'package:escape_room/core/storage/repositories.dart';
import 'package:escape_room/core/storage/settings_repository.dart';
import 'package:escape_room/domain/game_save.dart';
import 'package:escape_room/domain/game_spec.dart';
import 'package:escape_room/domain/puzzle.dart';
import 'package:escape_room/features/create/create_screen.dart';
import 'package:escape_room/features/game/game_screen.dart';
import 'package:escape_room/features/game/puzzles/puzzle_view.dart';
import 'package:escape_room/features/library/library_screen.dart';
import 'package:escape_room/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Renders every screen and puzzle widget of the built-in game to catch
/// layout/build exceptions (no device available in CI).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late List<Override> overrides;
  late GameSpec spec;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('escape_widgets');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final key = utf8.decode(message!.buffer.asUint8List());
      final f = File(key);
      if (!f.existsSync()) return null;
      return f.readAsBytes().then((b) => b.buffer.asByteData());
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('pl.escaperoom/incoming'),
      (call) async => null,
    );
    final saveRepo = SaveRepository(store: JsonFileStore('saves', root: tmp));
    final gameRepo = GameSpecRepository(store: JsonFileStore('games', root: tmp));
    overrides = [
      saveRepoProvider.overrideWithValue(saveRepo),
      gameSpecRepoProvider.overrideWithValue(gameRepo),
      scenarioRepoProvider.overrideWithValue(
          ScenarioRepository(store: JsonFileStore('scenarios', root: tmp))),
      settingsRepoProvider.overrideWithValue(
          SettingsRepository(store: JsonFileStore('settings', root: tmp))),
      settingsProvider.overrideWith(_FixedSettings.new),
      keysProvider.overrideWith(_NoKeys.new),
    ];
    spec = await gameRepo.builtin();
    await saveRepo.save(GameSave.start(
        id: 'w1', gameSpecId: spec.id, stageCount: spec.stages.length));
  });

  tearDown(() async {
    // Windows may still hold a handle for a moment after the last write.
    for (var i = 0; i < 5; i++) {
      try {
        await tmp.delete(recursive: true);
        break;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
  });

  Widget app(Widget home, {List<GoRoute> extraRoutes = const []}) {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => home),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/create', builder: (_, _) => const CreateScreen()),
      GoRoute(
          path: '/game/:id',
          builder: (_, s) => GameScreen(saveId: s.pathParameters['id']!)),
      GoRoute(
          path: '/victory/:id',
          builder: (_, s) => Scaffold(body: Text('victory ${s.pathParameters['id']}'))),
      GoRoute(path: '/scenario/:id', builder: (_, s) => const Scaffold(body: Text('scenario'))),
      ...extraRoutes,
    ]);
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
    );
  }

  testWidgets('every puzzle widget renders and accepts a submit', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final puzzles = <Puzzle>[
      ...spec.stages.map((s) => s.puzzle),
      const TextAnswerPuzzle(prompt: 'Hasło?', acceptedAnswers: ['sowa']),
      const ToggleGridPuzzle(
          prompt: 'Przełączniki', rows: 2, cols: 3,
          labels: ['A', 'B', 'C', 'D', 'E', 'F'],
          targetState: [true, false, true, false, true, false]),
      const DialCombinationPuzzle(
          prompt: 'Pokrętła',
          dials: [Dial(label: 'Ciśnienie', min: 0, max: 9), Dial(label: 'Temp', min: 10, max: 30)],
          answer: [4, 20]),
    ];
    for (final p in puzzles) {
      Object? got;
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: ListView(children: [
            PuzzleView(
              puzzle: p,
              enabled: true,
              accent: Colors.cyan,
              onSubmit: (a, _) => got = a,
            ),
          ]),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text(p.prompt), findsOneWidget, reason: p.type);
      expect(tester.takeException(), isNull, reason: p.type);

      switch (p) {
        case PinCodePuzzle():
          for (final k in ['0', '4', '2', 'OK']) {
            await tester.tap(find.text(k));
            await tester.pump();
          }
          expect(got, '042');
        case MultipleChoicePuzzle():
          await tester.tap(find.text('A'));
          await tester.pump();
          await tester.tap(find.text('Wybieram'));
          expect(got, 0);
        case SequenceOrderPuzzle():
          await tester.tap(find.text('Zatwierdź kolejność'));
          expect(got, isA<List<String>>());
        case TextAnswerPuzzle():
          await tester.enterText(find.byType(TextField), 'sowa');
          await tester.pump();
          await tester.tap(find.text('Sprawdź'));
          expect(got, 'sowa');
        case MatchingPuzzle m:
          for (var i = 0; i < m.leftItems.length; i++) {
            await tester.tap(find.text(m.leftItems[i]));
            await tester.pump();
            await tester.tap(find.text(m.rightItems[i]));
            await tester.pump();
          }
          await tester.tap(find.text('Sprawdź dopasowania'));
          expect(got, isA<Map<String, String>>());
          expect((got as Map).length, m.leftItems.length);
        case ToggleGridPuzzle():
          await tester.tap(find.text('A'));
          await tester.pump();
          await tester.tap(find.text('Zatwierdź ustawienie'));
          expect((got as List<bool>).first, isTrue);
        case DialCombinationPuzzle():
          await tester.tap(find.byIcon(Icons.add_circle_outline).first);
          await tester.pump();
          await tester.tap(find.text('Ustaw'));
          expect((got as List<int>).first, 1);
        case OpenExplanationPuzzle():
          await tester.enterText(find.byType(TextField), 'Dzielimy koła na trzy grupy po trzy.');
          await tester.pump();
          await tester.tap(find.text('Wyślij Mistrzowi Gry'));
          expect(got, isA<String>());
      }
      expect(tester.takeException(), isNull, reason: '${p.type} submit');
    }
  });

  /// Inside [WidgetTester.runAsync] real I/O needs real time: wait a little,
  /// then advance the widget clock.
  Future<void> settle(WidgetTester tester, {int frames = 25}) async {
    for (var i = 0; i < frames; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('game screen renders stage 1, reacts to a wrong answer and opens sheets',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    // Real file I/O behind the providers → runAsync; scenes animate forever →
    // pump a bounded number of frames instead of pumpAndSettle.
    await tester.runAsync(() async {
      await tester.pumpWidget(app(const GameScreen(saveId: 'w1')));
      await settle(tester);
      expect(find.text(spec.stages[0].title), findsWidgets);
      expect(find.text('Zatwierdź kolejność'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Inspect an object → GM describes it (fallback description).
      // label appears both as a tag on the picture and as a chip; tap the chip
      await tester.tap(find.text(spec.stages[0].scene.objects[1].label).last);
      await settle(tester, frames: 80);
      expect(find.textContaining('Czarny nigdy pierwszy'), findsWidgets);

      // Wrong order (items are shuffled by design) → failure text.
      await tester.scrollUntilVisible(find.text('Zatwierdź kolejność'), 200,
          scrollable: find.byType(Scrollable).first);
      await settle(tester, frames: 5);
      await tester.tap(find.text('Zatwierdź kolejność'));
      await settle(tester, frames: 80);
      expect(find.textContaining('Iskra przeskakuje'), findsOneWidget);

      // Hint sheet.
      await tester.tap(find.byIcon(Icons.lightbulb_outline));
      await settle(tester);
      await tester.tap(find.text('Odsłoń podpowiedź 1'));
      await settle(tester);
      expect(find.text(spec.stages[0].hints[0]), findsOneWidget);
      await tester.tapAt(const Offset(10, 10)); // dismiss sheet
      await settle(tester);

      // GM chat sheet.
      await tester.tap(find.byIcon(Icons.forum_outlined));
      await settle(tester);
      expect(find.text('Rozmowa z Mistrzem Gry'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('library, create and settings screens build', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(app(const LibraryScreen()));
      await settle(tester);
      expect(find.text('Warsztat Wynalazcy'), findsOneWidget);
      expect(find.textContaining('Kontynuuj'), findsOneWidget);
      await tester.tap(find.text('Scenariusze'));
      await settle(tester);
      expect(find.text('Warsztat Wynalazcy'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byType(FloatingActionButton));
      await settle(tester);
      expect(find.text('Parametry gry'), findsOneWidget);
      expect(find.text('Wylosuj pokój zagadek'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Import scenariusza'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Import scenariusza'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(app(const SettingsScreen()));
      await settle(tester);
      expect(find.text('Testuj połączenie'), findsOneWidget);
      await tester.tap(find.text('Google (Gemini)'));
      await settle(tester);
      expect(find.textContaining('Klucz API Gemini'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

class _FixedSettings extends SettingsNotifier {
  @override
  Future<Settings> build() async => const Settings();
}

class _NoKeys extends KeysNotifier {
  @override
  Future<ApiKeys> build() async => const ApiKeys(anthropic: '', gemini: '');
}
