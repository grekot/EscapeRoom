import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/ai/ai_provider.dart';
import '../core/ai/ai_provider_factory.dart';
import '../core/ai/model_catalog.dart';
import '../core/remote/remote_scenarios.dart';
import '../core/storage/repositories.dart';
import '../core/storage/secure_keys.dart';
import '../core/storage/settings_repository.dart';
import '../core/update/app_update.dart';
import '../domain/game_save.dart';
import '../domain/game_spec.dart';
import '../domain/scenario.dart';

const uuid = Uuid();
String newId() => uuid.v4().replaceAll('-', '').substring(0, 20);

final settingsRepoProvider = Provider((_) => SettingsRepository());
final secureKeysProvider = Provider((_) => SecureKeys());
final scenarioRepoProvider = Provider((_) => ScenarioRepository());
final gameSpecRepoProvider = Provider((_) => GameSpecRepository());
final saveRepoProvider = Provider((_) => SaveRepository());

class SettingsNotifier extends AsyncNotifier<Settings> {
  @override
  Future<Settings> build() => ref.read(settingsRepoProvider).load();

  Future<void> save(Settings s) async {
    state = AsyncData(s);
    await ref.read(settingsRepoProvider).save(s);
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, Settings>(SettingsNotifier.new);

class ApiKeys {
  const ApiKeys({required this.anthropic, required this.gemini});
  final String anthropic;
  final String gemini;
}

class KeysNotifier extends AsyncNotifier<ApiKeys> {
  @override
  Future<ApiKeys> build() async {
    final k = ref.read(secureKeysProvider);
    return ApiKeys(anthropic: await k.anthropic(), gemini: await k.gemini());
  }

  Future<void> setAnthropic(String v) async {
    await ref.read(secureKeysProvider).setAnthropic(v);
    ref.invalidateSelf();
    await future;
  }

  Future<void> setGemini(String v) async {
    await ref.read(secureKeysProvider).setGemini(v);
    ref.invalidateSelf();
    await future;
  }
}

final keysProvider =
    AsyncNotifierProvider<KeysNotifier, ApiKeys>(KeysNotifier.new);

/// Active provider or null when the selected vendor has no key.
final aiProviderProvider = FutureProvider<AiProvider?>((ref) async {
  final s = await ref.watch(settingsProvider.future);
  final k = await ref.watch(keysProvider.future);
  return buildAiProvider(s, anthropicKey: k.anthropic, geminiKey: k.gemini);
});

class LibraryData {
  const LibraryData({
    required this.games,
    required this.scenarios,
    required this.saves,
  });

  final List<GameSpec> games;
  final List<Scenario> scenarios;
  final List<GameSave> saves;

  /// Most recent unfinished save for a game, if any.
  GameSave? inProgress(String gameId) {
    for (final s in saves) {
      if (s.gameSpecId == gameId && !s.completed) return s;
    }
    return null;
  }

  bool isCompleted(String gameId) =>
      saves.any((s) => s.gameSpecId == gameId && s.completed);

  List<GameSpec> gamesForScenario(String scenarioId) =>
      games.where((g) => g.scenarioId == scenarioId).toList();
}

final libraryProvider = FutureProvider<LibraryData>((ref) async {
  final games = await ref.watch(gameSpecRepoProvider).all();
  final scenarios = await ref.watch(scenarioRepoProvider).all();
  final saves = await ref.watch(saveRepoProvider).all();
  return LibraryData(games: games, scenarios: scenarios, saves: saves);
});

/// Live model lists from the vendors (refetched when the key changes).
final geminiModelsProvider = FutureProvider<List<ModelInfo>>((ref) async {
  final k = await ref.watch(keysProvider.future);
  return ModelCatalog().gemini(k.gemini);
});

final anthropicModelsProvider = FutureProvider<List<ModelInfo>>((ref) async {
  final k = await ref.watch(keysProvider.future);
  return ModelCatalog().anthropic(k.anthropic);
});

/// A newer GitHub release than the running app, or null (also on any error –
/// updates are a convenience, never a blocker). Checked once per launch.
final latestReleaseProvider = FutureProvider<ReleaseInfo?>((ref) async {
  final (check, repo) = await ref.watch(
      settingsProvider.selectAsync((s) => (s.checkUpdates, s.updateRepo)));
  if (!check || repo.trim().isEmpty) return null;
  try {
    final r = await UpdateChecker().latest(repo);
    return r != null && r.isNewer ? r : null;
  } catch (_) {
    return null;
  }
});

/// Scenario files published in the configured GitHub repository.
final remoteScenariosProvider =
    FutureProvider.autoDispose<List<RemoteScenario>>((ref) async {
  final repo = await ref.watch(settingsProvider.selectAsync((s) => s.scenarioRepo));
  if (repo.trim().isEmpty) return const [];
  return RemoteScenarioCatalog().list(repo);
});
