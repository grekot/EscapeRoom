import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/ai/ai_errors.dart';
import '../../core/ai/anthropic_provider.dart';
import '../../core/ai/gemini_provider.dart';
import '../../core/ai/image_generator.dart';
import '../../core/ai/model_catalog.dart';
import '../../core/storage/settings_repository.dart';
import '../../core/update/app_update.dart';
import '../../domain/catalog.dart';
import 'update_dialog.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _anthropicKey = TextEditingController();
  final _geminiKey = TextEditingController();
  final _names = TextEditingController();
  final _updateRepo = TextEditingController();
  final _scenarioRepo = TextEditingController();
  bool _checkingUpdate = false;
  bool _keysLoaded = false;
  bool _showAnthropic = false;
  bool _showGemini = false;
  bool _testing = false;

  @override
  void dispose() {
    _anthropicKey.dispose();
    _geminiKey.dispose();
    _names.dispose();
    _updateRepo.dispose();
    _scenarioRepo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final keysAsync = ref.watch(keysProvider);
    final settings = settingsAsync.valueOrNull;
    final keys = keysAsync.valueOrNull;
    if (settings == null || keys == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_keysLoaded) {
      _anthropicKey.text = keys.anthropic;
      _geminiKey.text = keys.gemini;
      _names.text = settings.playerNames;
      _updateRepo.text = settings.updateRepo;
      _scenarioRepo.text = settings.scenarioRepo;
      _keysLoaded = true;
    }
    final notifier = ref.read(settingsProvider.notifier);
    final geminiModels = ref.watch(geminiModelsProvider);
    final anthropicModels = ref.watch(anthropicModelsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ustawienia')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _Header('Dostawca AI'),
          SegmentedButton<AiVendor>(
            segments: [
              for (final v in AiVendor.values)
                ButtonSegment(value: v, label: Text(v.label)),
            ],
            selected: {settings.vendor},
            onSelectionChanged: (s) => notifier.save(settings.copyWith(vendor: s.first)),
          ),
          const SizedBox(height: 16),
          if (settings.vendor == AiVendor.anthropic) ...[
            _KeyField(
              controller: _anthropicKey,
              label: 'Klucz API Anthropic (sk-ant-…)',
              obscure: !_showAnthropic,
              onToggle: () => setState(() => _showAnthropic = !_showAnthropic),
              onSave: () async {
                await ref.read(keysProvider.notifier).setAnthropic(_anthropicKey.text);
                _snack('Klucz Anthropic zapisany.');
              },
            ),
            const SizedBox(height: 10),
            _ModelPicker(
              label: 'Model',
              value: settings.anthropicModel,
              models: anthropicModels,
              fallback: AnthropicProvider.models,
              imageOnly: false,
              onChanged: (v) => notifier.save(settings.copyWith(anthropicModel: v)),
              onRefresh: () => ref.invalidate(anthropicModelsProvider),
            ),
            const SizedBox(height: 6),
            const Text(
              'Klucz: console.anthropic.com → API Keys.',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ] else ...[
            _KeyField(
              controller: _geminiKey,
              label: 'Klucz API Gemini (AIza…)',
              obscure: !_showGemini,
              onToggle: () => setState(() => _showGemini = !_showGemini),
              onSave: () async {
                await ref.read(keysProvider.notifier).setGemini(_geminiKey.text);
                _snack('Klucz Gemini zapisany.');
              },
            ),
            const SizedBox(height: 10),
            _ModelPicker(
              label: 'Model',
              value: settings.geminiModel,
              models: geminiModels,
              fallback: GeminiProvider.models,
              imageOnly: false,
              onChanged: (v) => notifier.save(settings.copyWith(geminiModel: v)),
              onRefresh: () => ref.invalidate(geminiModelsProvider),
            ),
            const SizedBox(height: 6),
            const Text(
              'Klucz: aistudio.google.com → Get API key (jest darmowy limit).',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _testing ? null : () => _test(settings),
            icon: _testing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.wifi_tethering),
            label: const Text('Testuj połączenie'),
          ),
          const SizedBox(height: 24),
          _Header('Scenografia (grafiki AI)'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Generuj ilustracje scen'),
            subtitle: Text(settings.vendor == AiVendor.gemini
                ? 'Po zaprojektowaniu gry Gemini maluje jedną ilustrację na etap (kilka sekund i grosze za obraz).'
                : 'Obrazy generuje wyłącznie Gemini. Wpisz klucz Gemini poniżej – tekst może dalej robić Claude.'),
            value: settings.generateImages,
            onChanged: (v) => notifier.save(settings.copyWith(generateImages: v)),
          ),
          if (settings.generateImages) ...[
            if (settings.vendor != AiVendor.gemini) ...[
              const SizedBox(height: 6),
              _KeyField(
                controller: _geminiKey,
                label: 'Klucz API Gemini do grafik (AIza…)',
                obscure: !_showGemini,
                onToggle: () => setState(() => _showGemini = !_showGemini),
                onSave: () async {
                  await ref.read(keysProvider.notifier).setGemini(_geminiKey.text);
                  _snack('Klucz Gemini zapisany.');
                },
              ),
            ],
            const SizedBox(height: 10),
            _ModelPicker(
              label: 'Model obrazów',
              value: settings.imageModel,
              models: geminiModels,
              fallback: GeminiImageGenerator.models,
              imageOnly: true,
              onChanged: (v) => notifier.save(settings.copyWith(imageModel: v)),
              onRefresh: () => ref.invalidate(geminiModelsProvider),
            ),
          ],
          const SizedBox(height: 24),
          _Header('Rozgrywka'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mistrz Gry na żywo'),
            subtitle: const Text(
                'AI reaguje na każdy ruch (błędna odpowiedź, oglądanie przedmiotu, rozmowa). Jedno małe zapytanie na zdarzenie. Wyłączone = teksty zapisane w grze.'),
            value: settings.liveGm,
            onChanged: (v) => notifier.save(settings.copyWith(liveGm: v)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _names,
            decoration: const InputDecoration(
              labelText: 'Imiona graczy (opcjonalnie)',
              hintText: 'np. Zuzanna i Tata',
            ),
            onChanged: (v) => notifier.save(settings.copyWith(playerNames: v)),
          ),
          const SizedBox(height: 16),
          Text('Domyślny wiek gracza: ${settings.defaultAge} lat'),
          Slider(
            value: settings.defaultAge.toDouble(),
            min: 5,
            max: 16,
            divisions: 11,
            label: '${settings.defaultAge}',
            onChanged: (v) => notifier.save(settings.copyWith(defaultAge: v.round())),
          ),
          SegmentedButton<Difficulty>(
            segments: [
              for (final d in Difficulty.values) ButtonSegment(value: d, label: Text(d.label)),
            ],
            selected: {settings.defaultDifficulty},
            onSelectionChanged: (s) =>
                notifier.save(settings.copyWith(defaultDifficulty: s.first)),
          ),
          const SizedBox(height: 12),
          Text('Domyślna liczba etapów: ${settings.defaultStages}'),
          Slider(
            value: settings.defaultStages.toDouble(),
            min: 2,
            max: 6,
            divisions: 4,
            label: '${settings.defaultStages}',
            onChanged: (v) => notifier.save(settings.copyWith(defaultStages: v.round())),
          ),
          const SizedBox(height: 24),
          _Header('Aktualizacje i GitHub'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.system_update_alt),
              title: Text('Wersja aplikacji: ${AppVersion.current}'),
              subtitle: Text('Wydania: github.com/${settings.updateRepo}/releases',
                  style: const TextStyle(fontSize: 12)),
              trailing: _checkingUpdate
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : TextButton(
                      onPressed: () async {
                        setState(() => _checkingUpdate = true);
                        await checkForUpdates(context, settings.updateRepo);
                        if (mounted) setState(() => _checkingUpdate = false);
                      },
                      child: const Text('Sprawdź'),
                    ),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Sprawdzaj aktualizacje przy starcie'),
            subtitle: const Text('Jedno zapytanie do GitHub przy otwarciu biblioteki.'),
            value: settings.checkUpdates,
            onChanged: (v) => notifier.save(settings.copyWith(checkUpdates: v)),
          ),
          const SizedBox(height: 6),
          _RepoField(
            controller: _updateRepo,
            label: 'Repozytorium aplikacji (owner/repo)',
            onSave: () async {
              await notifier.save(settings.copyWith(updateRepo: _updateRepo.text.trim()));
              ref.invalidate(latestReleaseProvider);
              _snack('Zapisano repozytorium aplikacji.');
            },
          ),
          const SizedBox(height: 10),
          _RepoField(
            controller: _scenarioRepo,
            label: 'Repozytorium scenariuszy (owner/repo)',
            onSave: () async {
              await notifier.save(settings.copyWith(scenarioRepo: _scenarioRepo.text.trim()));
              ref.invalidate(remoteScenariosProvider);
              _snack('Zapisano repozytorium scenariuszy.');
            },
          ),
          const SizedBox(height: 6),
          const Text(
            'Scenariusze (.md/.json) wrzucone do publicznego repozytorium GitHub pojawiają się w bibliotece w zakładce „Scenariusze”. Puste pole wyłącza tę funkcję.',
            style: TextStyle(fontSize: 12, color: Colors.white54),
          ),
          const SizedBox(height: 24),
          _Header('Scenariusze z innych AI'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.integration_instructions_outlined),
              title: const Text('Instrukcja dla AI i format scenariusza'),
              subtitle: const Text(
                  'Skopiuj gotowy prompt do ChatGPT / Claude / Gemini, a wynik zaimportuj w „Nowa gra”.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/authoring'),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Klucze API są przechowywane w bezpiecznym magazynie systemu (Android Keystore) i wysyłane wyłącznie do wybranego dostawcy AI. Aplikacja jest przeznaczona do użytku prywatnego.',
            style: TextStyle(fontSize: 12, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  Future<void> _test(Settings s) async {
    setState(() => _testing = true);
    try {
      final key = s.vendor == AiVendor.anthropic ? _anthropicKey.text : _geminiKey.text;
      final p = s.vendor == AiVendor.anthropic
          ? AnthropicProvider(apiKey: key, model: s.anthropicModel)
          : GeminiProvider(apiKey: key, model: s.geminiModel);
      await p.ping();
      _snack('Połączenie działa. Klucz i model „${s.activeModel}” są poprawne.');
    } on AiException catch (e) {
      _snack(e.userMessage);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 6),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );
}

class _KeyField extends StatelessWidget {
  const _KeyField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    required this.onSave,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            obscureText: obscure,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: label,
              suffixIcon: IconButton(
                icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: onToggle,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(onPressed: onSave, child: const Text('Zapisz')),
      ],
    );
  }
}

/// Plain text setting with an explicit save button (GitHub `owner/repo`).
class _RepoField extends StatelessWidget {
  const _RepoField({
    required this.controller,
    required this.label,
    required this.onSave,
  });

  final TextEditingController controller;
  final String label;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(labelText: label, prefixText: 'github.com/'),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(onPressed: onSave, child: const Text('Zapisz')),
      ],
    );
  }
}

/// Model dropdown fed by the vendor's live model list, with a static fallback.
class _ModelPicker extends StatelessWidget {
  const _ModelPicker({
    required this.label,
    required this.value,
    required this.models,
    required this.fallback,
    required this.imageOnly,
    required this.onChanged,
    required this.onRefresh,
  });

  final String label;
  final String value;
  final AsyncValue<List<ModelInfo>> models;
  final Map<String, String> fallback;
  final bool imageOnly;
  final ValueChanged<String> onChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final live = models.valueOrNull?.where((m) => m.isImage == imageOnly).toList() ?? const [];
    final entries = <MapEntry<String, String>>[
      if (live.isNotEmpty)
        for (final m in live) MapEntry(m.id, fallback[m.id] ?? m.label)
      else
        ...fallback.entries,
    ];
    if (!entries.any((e) => e.key == value)) {
      entries.insert(0, MapEntry(value, '$value (wybrany, nie ma go na liście)'));
    }
    final String hint;
    Color hintColor = Colors.white54;
    if (models.isLoading) {
      hint = 'Pobieram listę modeli z API…';
    } else if (models.hasError) {
      final e = models.error;
      hint = 'Nie udało się pobrać listy (${e is AiException ? e.userMessage : e}). Pokazuję listę awaryjną.';
      hintColor = Colors.amber;
    } else if (live.isEmpty) {
      hint = 'API nie zwróciło pasujących modeli. Pokazuję listę awaryjną.';
      hintColor = Colors.amber;
    } else {
      hint = 'Lista z API: ${live.length} modeli dostępnych dla Twojego klucza.';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey('$label-$value-${entries.length}'),
                isExpanded: true,
                initialValue: value,
                decoration: InputDecoration(labelText: label),
                items: [
                  for (final e in entries)
                    DropdownMenuItem(
                      value: e.key,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.value, overflow: TextOverflow.ellipsis),
                          if (e.value != e.key)
                            Text(e.key,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10.5, color: Colors.white54)),
                        ],
                      ),
                    ),
                ],
                selectedItemBuilder: (_) => [
                  for (final e in entries)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(e.value, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
            const SizedBox(width: 4),
            models.isLoading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : IconButton(
                    tooltip: 'Odśwież listę modeli',
                    icon: const Icon(Icons.refresh),
                    onPressed: onRefresh,
                  ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 4),
          child: Text(hint, style: TextStyle(fontSize: 11.5, color: hintColor)),
        ),
      ],
    );
  }
}
