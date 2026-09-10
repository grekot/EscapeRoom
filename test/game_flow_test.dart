import 'dart:convert';
import 'dart:io';

import 'package:escape_room/app/providers.dart';
import 'package:escape_room/core/storage/json_file_store.dart';
import 'package:escape_room/core/storage/repositories.dart';
import 'package:escape_room/core/storage/settings_repository.dart';
import 'package:escape_room/domain/game_save.dart';
import 'package:escape_room/domain/game_spec.dart';
import 'package:escape_room/features/game/game_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drives the built-in game end to end through the controller, offline
/// (no API key → fallback texts, parent self-judgement for the open stage).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late ProviderContainer container;
  late GameSpec spec;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('escape_test');
    // Serve assets from disk for rootBundle.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final key = utf8.decode(message!.buffer.asUint8List());
      final f = File(key);
      if (!f.existsSync()) return null;
      return f.readAsBytes().then((b) => b.buffer.asByteData());
    });
    // Secure storage plugin is unavailable in tests → no keys → offline mode.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => call.method == 'read' ? null : null,
    );

    final saveRepo =
        SaveRepository(store: JsonFileStore('saves', root: tmp));
    container = ProviderContainer(overrides: [
      saveRepoProvider.overrideWithValue(saveRepo),
      gameSpecRepoProvider.overrideWithValue(
          GameSpecRepository(store: JsonFileStore('games', root: tmp))),
      scenarioRepoProvider.overrideWithValue(
          ScenarioRepository(store: JsonFileStore('scenarios', root: tmp))),
      settingsProvider.overrideWith(_FixedSettings.new),
      keysProvider.overrideWith(_NoKeys.new),
    ]);
    spec = await container.read(gameSpecRepoProvider).builtin();
    final save = GameSave.start(
        id: 'save1', gameSpecId: spec.id, stageCount: spec.stages.length);
    await saveRepo.save(save);
  });

  tearDown(() async {
    container.dispose();
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

  test('play the built-in room offline from start to victory', () async {
    final provider = gameControllerProvider('save1');
    final sub = container.listen(provider, (_, _) {});
    var s = await container.read(provider.future);
    final ctrl = container.read(provider.notifier);
    expect(s.stageIndex, 0);
    expect(s.reaction?.text, spec.stages[0].narrative);
    expect(ctrl.liveGm, isFalse);

    // Stage 1: wrong then right order.
    await ctrl.submitAnswer(
        ['Czerwony', 'Biały', 'Zielony', 'Czarny'], 'zła kolejność');
    s = container.read(provider).requireValue;
    expect(s.stageSolved, isFalse);
    expect(s.attempts, 1);
    expect(s.reaction?.text, contains(spec.stages[0].fallbackTexts.failure));

    await ctrl.submitAnswer(
        ['Zielony', 'Czarny', 'Czerwony', 'Biały'], 'dobra kolejność');
    s = container.read(provider).requireValue;
    expect(s.stageSolved, isTrue);
    expect(s.effect, isNotNull);
    // solved state is persisted so a restart resumes at "Dalej"
    expect((await container.read(saveRepoProvider).byId('save1'))!.stageSolved, isTrue);
    ctrl.effectDone();
    expect(await ctrl.nextStage(), isFalse);
    s = container.read(provider).requireValue;
    expect(s.stageIndex, 1);

    // Stage 2: hint then PIN.
    final hint = await ctrl.revealHint();
    expect(hint, spec.stages[1].hints[0]);
    expect(container.read(provider).requireValue.hintsRevealed, 1);
    await ctrl.submitAnswer('042', '042');
    expect(container.read(provider).requireValue.stageSolved, isTrue);
    await ctrl.nextStage();

    // Stage 3: multiple choice.
    await ctrl.submitAnswer(2, 'Mieszane');
    expect(container.read(provider).requireValue.stageSolved, isTrue);
    await ctrl.nextStage();

    // Stage 4: matching.
    await ctrl.submitAnswer({
      'Pudełko ze starą etykietą „Tylko Czerwone”': 'Mieszane diody',
      'Pudełko ze starą etykietą „Tylko Zielone”': 'Tylko czerwone diody',
      'Pudełko ze starą etykietą „Mieszane”': 'Tylko zielone diody',
    }, 'pary');
    expect(container.read(provider).requireValue.stageSolved, isTrue);
    await ctrl.nextStage();

    // Stage 5: open explanation → no AI → parent judges.
    await ctrl.submitAnswer('dzielimy na 3 grupy…', 'dzielimy na 3 grupy…');
    s = container.read(provider).requireValue;
    expect(s.pendingSelfJudge, isNotNull);
    expect(s.stageSolved, isFalse);
    await ctrl.selfJudge(true);
    s = container.read(provider).requireValue;
    expect(s.stageSolved, isTrue);
    expect(s.isLastStage, isTrue);
    expect(await ctrl.nextStage(), isTrue);
    s = container.read(provider).requireValue;
    expect(s.finished, isTrue);

    // Persisted.
    final saved = await container.read(saveRepoProvider).byId('save1');
    expect(saved!.completed, isTrue);
    expect(saved.totalHints, 1);
    expect(saved.totalAttempts, 1);
    expect(saved.history, isNotEmpty);
    sub.close();
  });
}

class _FixedSettings extends SettingsNotifier {
  @override
  Future<Settings> build() async => const Settings(liveGm: true);
}

class _NoKeys extends KeysNotifier {
  @override
  Future<ApiKeys> build() async => const ApiKeys(anthropic: '', gemini: '');
}
