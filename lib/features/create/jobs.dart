import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/ai/ai_errors.dart';
import '../../core/ai/ai_provider.dart';
import '../../core/ai/image_generator.dart';
import '../../core/ai/pipeline/game_designer.dart';
import '../../core/ai/pipeline/scene_artist.dart';
import '../../domain/game_spec.dart';
import '../../domain/mechanisms.dart';
import '../../core/ai/pipeline/scenario_importer.dart';
import '../../core/ai/pipeline/scenario_writer.dart';
import '../../domain/scenario.dart';
import '../game/start_game.dart';
import 'generation_screen.dart';

Future<AiProvider> _requireAi(WidgetRef ref) async {
  final ai = await ref.read(aiProviderProvider.future);
  if (ai == null) {
    throw AiException(AiErrorKind.noApiKey, 'Brak klucza API.');
  }
  return ai;
}

/// Write a scenario from a prompt / random parameters, save it, open preview.
GenerationJob writeScenarioJob(ScenarioRequest req) => GenerationJob(
      title: req.source == ScenarioSource.random
          ? 'Losuję pokój zagadek'
          : 'Piszę scenariusz',
      run: (ref, status) async {
        final ai = await _requireAi(ref);
        final settings = await ref.read(settingsProvider.future);
        status('Mistrz Gry wymyśla historię: ${req.theme}…');
        final id = newId();
        final s = await ScenarioWriter(ai, playerNames: settings.playerNames)
            .write(await withLibraryMemory(ref, req), id: id);
        await ref.read(scenarioRepoProvider).save(s);
        ref.invalidate(libraryProvider);
        return '/scenario/$id';
      },
    );

/// Tells the writer what the library already holds (titles + mechanisms of
/// the most recent games) and proposes fresh mechanisms, so consecutive games
/// do not all end up as "guess the PIN from the wrong attempts".
Future<ScenarioRequest> withLibraryMemory(WidgetRef ref, ScenarioRequest req) async {
  try {
    final lib = await ref.read(libraryProvider.future);
    final games = [...lib.games]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final designed = games.map((g) => g.scenarioId).toSet();
    final scenarios = [
      for (final s in lib.scenarios)
        if (!designed.contains(s.id) && s.source != ScenarioSource.builtin) s,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final avoid = <String>[
      for (final g in games.take(8)) Mechanisms.describeGame(g),
      for (final s in scenarios.take(4)) Mechanisms.describeScenario(s),
    ];
    final usedTags = <String>[
      for (final g in games.take(8)) ...Mechanisms.ofGame(g),
      for (final s in scenarios.take(4)) ...Mechanisms.ofScenario(s),
    ];
    return req.copyWith(
      avoid: avoid,
      suggestedMechanisms: Mechanisms.suggest(avoid: usedTags, count: 4),
    );
  } catch (_) {
    return req; // memory is a nicety; never block generation on it
  }
}

/// Convert free-form text into a scenario with the model, save, open preview.
GenerationJob importWithAiJob(String text) => GenerationJob(
      title: 'Odczytuję scenariusz',
      run: (ref, status) async {
        final ai = await _requireAi(ref);
        status('Przekładam tekst na format scenariusza…');
        final id = newId();
        final r = await ScenarioImporter(ai: ai).import(text, id: id);
        await ref.read(scenarioRepoProvider).save(r.scenario);
        ref.invalidate(libraryProvider);
        return '/scenario/$id';
      },
    );

/// Design a game from a scenario, save it, start a new play-through.
GenerationJob designGameJob(Scenario scenario) => GenerationJob(
      title: 'Projektuję grę',
      run: (ref, status) async {
        final ai = await _requireAi(ref);
        final settings = await ref.read(settingsProvider.future);
        status('Czytam scenariusz „${scenario.title}”…');
        var spec = await GameDesigner(ai, playerNames: settings.playerNames)
            .design(scenario, id: newId(), onStatus: status);
        await ref.read(gameSpecRepoProvider).save(spec);
        spec = await illustrateIfPossible(ref, spec, status);
        status('Otwieram drzwi…');
        final saveId = await startGame(ref, spec);
        return '/game/$saveId';
      },
    );

/// Paints stage illustrations with Gemini when enabled and a Gemini key is
/// stored. Failures are non-fatal: the procedural backdrop is used instead.
Future<GameSpec> illustrateIfPossible(
    WidgetRef ref, GameSpec spec, void Function(String) status,
    {bool force = false}) async {
  final settings = await ref.read(settingsProvider.future);
  final keys = await ref.read(keysProvider.future);
  if (!settings.generateImages || keys.gemini.trim().isEmpty) return spec;
  final artist = SceneArtist(
      GeminiImageGenerator(apiKey: keys.gemini, model: settings.imageModel));
  final r = await artist.illustrate(spec, onStatus: status, force: force);
  await ref.read(gameSpecRepoProvider).save(r.spec);
  ref.invalidate(libraryProvider);
  if (r.failures.isNotEmpty) {
    status('Bez grafiki: ${r.failures.keys.join(', ')} (${r.failures.values.first})');
    await Future<void>.delayed(const Duration(seconds: 3));
  }
  return r.spec;
}

/// (Re)generate illustrations for an existing game, then open the library.
GenerationJob illustrateGameJob(GameSpec spec, {bool force = false}) => GenerationJob(
      title: 'Maluję scenografię',
      run: (ref, status) async {
        final keys = await ref.read(keysProvider.future);
        if (keys.gemini.trim().isEmpty) {
          throw AiException(AiErrorKind.noApiKey,
              'Grafiki generuje Gemini – wpisz klucz Gemini w Ustawieniach.');
        }
        final settings = await ref.read(settingsProvider.future);
        if (!settings.generateImages) {
          await ref.read(settingsProvider.notifier).save(settings.copyWith(generateImages: true));
        }
        await illustrateIfPossible(ref, spec, status, force: force);
        return '/';
      },
    );
