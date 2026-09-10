import '../../domain/catalog.dart';
import '../remote/remote_scenarios.dart';
import '../update/app_update.dart';
import '../../domain/json_utils.dart';
import '../ai/anthropic_provider.dart';
import '../ai/gemini_provider.dart';
import '../ai/image_generator.dart';
import 'json_file_store.dart';

enum AiVendor {
  anthropic('anthropic', 'Anthropic (Claude)'),
  gemini('gemini', 'Google (Gemini)');

  const AiVendor(this.wire, this.label);
  final String wire;
  final String label;

  static AiVendor parse(String? s) => values.firstWhere(
        (v) => v.wire == s,
        orElse: () => AiVendor.anthropic,
      );
}

class Settings {
  const Settings({
    this.vendor = AiVendor.anthropic,
    this.anthropicModel = AnthropicProvider.defaultModel,
    this.geminiModel = GeminiProvider.defaultModel,
    this.liveGm = true,
    this.defaultAge = 10,
    this.defaultDifficulty = Difficulty.medium,
    this.defaultStages = 4,
    this.playerNames = '',
    this.generateImages = true,
    this.imageModel = GeminiImageGenerator.defaultModel,
    this.updateRepo = UpdateChecker.defaultRepo,
    this.scenarioRepo = RemoteScenarioCatalog.defaultRepo,
    this.checkUpdates = true,
  });

  /// GitHub `owner/repo` whose releases carry app updates.
  final String updateRepo;

  /// GitHub `owner/repo` with downloadable scenario files.
  final String scenarioRepo;

  /// Look for a newer release when the library opens.
  final bool checkUpdates;

  final AiVendor vendor;
  final String anthropicModel;
  final String geminiModel;

  /// Live game master reactions (costs one small request per event).
  final bool liveGm;
  final int defaultAge;
  final Difficulty defaultDifficulty;
  final int defaultStages;

  /// Optional, e.g. "Zuzanna i Tata" – used by the GM to address players.
  final String playerNames;

  /// Generate scene illustrations with Gemini after designing a game.
  final bool generateImages;
  final String imageModel;

  String get activeModel =>
      vendor == AiVendor.anthropic ? anthropicModel : geminiModel;

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
        vendor: AiVendor.parse(jStrOrNull(j, 'vendor')),
        anthropicModel:
            jStr(j, 'anthropicModel', fallback: AnthropicProvider.defaultModel),
        geminiModel: jStr(j, 'geminiModel', fallback: GeminiProvider.defaultModel),
        liveGm: jBool(j, 'liveGm', fallback: true),
        defaultAge: jInt(j, 'defaultAge', fallback: 10),
        defaultDifficulty: Difficulty.parse(jStrOrNull(j, 'defaultDifficulty')),
        defaultStages: jInt(j, 'defaultStages', fallback: 4),
        playerNames: jStr(j, 'playerNames'),
        generateImages: jBool(j, 'generateImages', fallback: true),
        imageModel: jStr(j, 'imageModel', fallback: GeminiImageGenerator.defaultModel),
        updateRepo: jStr(j, 'updateRepo', fallback: UpdateChecker.defaultRepo),
        scenarioRepo: jStr(j, 'scenarioRepo', fallback: RemoteScenarioCatalog.defaultRepo),
        checkUpdates: jBool(j, 'checkUpdates', fallback: true),
      );

  Map<String, dynamic> toJson() => {
        'vendor': vendor.wire,
        'anthropicModel': anthropicModel,
        'geminiModel': geminiModel,
        'liveGm': liveGm,
        'defaultAge': defaultAge,
        'defaultDifficulty': defaultDifficulty.wire,
        'defaultStages': defaultStages,
        'playerNames': playerNames,
        'generateImages': generateImages,
        'imageModel': imageModel,
        'updateRepo': updateRepo,
        'scenarioRepo': scenarioRepo,
        'checkUpdates': checkUpdates,
      };

  Settings copyWith({
    AiVendor? vendor,
    String? anthropicModel,
    String? geminiModel,
    bool? liveGm,
    int? defaultAge,
    Difficulty? defaultDifficulty,
    int? defaultStages,
    String? playerNames,
    bool? generateImages,
    String? imageModel,
    String? updateRepo,
    String? scenarioRepo,
    bool? checkUpdates,
  }) =>
      Settings(
        vendor: vendor ?? this.vendor,
        anthropicModel: anthropicModel ?? this.anthropicModel,
        geminiModel: geminiModel ?? this.geminiModel,
        liveGm: liveGm ?? this.liveGm,
        defaultAge: defaultAge ?? this.defaultAge,
        defaultDifficulty: defaultDifficulty ?? this.defaultDifficulty,
        defaultStages: defaultStages ?? this.defaultStages,
        playerNames: playerNames ?? this.playerNames,
        generateImages: generateImages ?? this.generateImages,
        imageModel: imageModel ?? this.imageModel,
        updateRepo: updateRepo ?? this.updateRepo,
        scenarioRepo: scenarioRepo ?? this.scenarioRepo,
        checkUpdates: checkUpdates ?? this.checkUpdates,
      );
}

/// Settings live in `<documents>/settings/settings.json` (no extra plugin).
class SettingsRepository {
  SettingsRepository({JsonFileStore? store})
      : _store = store ?? JsonFileStore('settings');

  static const _doc = 'settings';
  final JsonFileStore _store;

  Future<Settings> load() async {
    final j = await _store.read(_doc);
    return j == null ? const Settings() : Settings.fromJson(j);
  }

  Future<void> save(Settings s) => _store.write(_doc, s.toJson());
}
