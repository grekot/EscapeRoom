import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/ai/pipeline/scenario_writer.dart';
import '../../domain/catalog.dart';
import 'import_flow.dart';
import 'jobs.dart';

class CreateScreen extends ConsumerStatefulWidget {
  const CreateScreen({super.key});

  @override
  ConsumerState<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends ConsumerState<CreateScreen> {
  final _prompt = TextEditingController();
  int? _age;
  Difficulty? _difficulty;
  int? _stages;

  static const _themeChips = [
    'Laboratorium wynalazcy',
    'Piramida faraona',
    'Statek kosmiczny',
    'Zamek czarodzieja',
    'Okręt piracki',
    'Tajemnicza biblioteka',
    'Podwodna stacja',
    'Zaczarowany las',
  ];

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).valueOrNull;
    final hasAi = ref.watch(aiProviderProvider).valueOrNull != null;
    final age = _age ?? settings?.defaultAge ?? 10;
    final difficulty = _difficulty ?? settings?.defaultDifficulty ?? Difficulty.medium;
    final stages = _stages ?? settings?.defaultStages ?? 4;

    return Scaffold(
      appBar: AppBar(title: const Text('Nowa gra')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (!hasAi)
            Card(
              color: const Color(0xFF2A2210),
              child: ListTile(
                leading: const Icon(Icons.key_off, color: Colors.amber),
                title: const Text('Brak klucza API'),
                subtitle: const Text(
                    'Import gotowego scenariusza w formacie aplikacji działa bez klucza, ale zaprojektowanie z niego gry, pisanie i losowanie wymagają AI.'),
                trailing: TextButton(
                  onPressed: () => context.push('/settings'),
                  child: const Text('Ustawienia'),
                ),
              ),
            ),
          _Section(
            icon: Icons.tune,
            title: 'Parametry gry',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Wiek gracza: $age lat'),
                Slider(
                  value: age.toDouble(),
                  min: 5,
                  max: 16,
                  divisions: 11,
                  label: '$age',
                  onChanged: (v) => setState(() => _age = v.round()),
                ),
                const SizedBox(height: 4),
                SegmentedButton<Difficulty>(
                  segments: [
                    for (final d in Difficulty.values)
                      ButtonSegment(value: d, label: Text(d.label)),
                  ],
                  selected: {difficulty},
                  onSelectionChanged: (s) => setState(() => _difficulty = s.first),
                ),
                const SizedBox(height: 12),
                Text('Liczba etapów: $stages'),
                Slider(
                  value: stages.toDouble(),
                  min: 2,
                  max: 6,
                  divisions: 4,
                  label: '$stages',
                  onChanged: (v) => setState(() => _stages = v.round()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            icon: Icons.casino,
            title: 'Zaskocz nas!',
            subtitle: 'Mistrz Gry losuje motyw, przedmioty i zwrot akcji, a potem pisze scenariusz.',
            child: FilledButton.icon(
              onPressed: hasAi
                  ? () => context.push(
                        '/generating',
                        extra: writeScenarioJob(ScenarioRequest.random(
                          age: age,
                          difficulty: difficulty,
                          stages: stages,
                        )),
                      )
                  : null,
              icon: const Icon(Icons.shuffle),
              label: const Text('Wylosuj pokój zagadek'),
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            icon: Icons.edit_note,
            title: 'Z Waszego pomysłu',
            subtitle: 'Napiszcie krótko, o czym ma być gra. Możecie wymienić miejsce, bohaterów, ulubione rzeczy.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in _themeChips)
                      ActionChip(
                        label: Text(t, style: const TextStyle(fontSize: 12)),
                        onPressed: () => setState(() {
                          _prompt.text = _prompt.text.trim().isEmpty
                              ? t
                              : '${_prompt.text.trim()}, ${t.toLowerCase()}';
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _prompt,
                  minLines: 2,
                  maxLines: 5,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'np. „Opuszczona stacja polarna, gramy z Zuzią, lubi pingwiny i szyfry”',
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: hasAi && _prompt.text.trim().isNotEmpty
                      ? () => context.push(
                            '/generating',
                            extra: writeScenarioJob(ScenarioRequest(
                              theme: _prompt.text.trim(),
                              age: age,
                              difficulty: difficulty,
                              stages: stages,
                              userPrompt: _prompt.text.trim(),
                            )),
                          )
                      : null,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Napisz scenariusz'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            icon: Icons.file_download,
            title: 'Import scenariusza',
            subtitle: 'Plik .md/.json (np. napisany w innym czacie AI według instrukcji z Ustawień) albo wklejony tekst.',
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickFile(context),
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Wybierz plik'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pasteText(context),
                    icon: const Icon(Icons.content_paste),
                    label: const Text('Wklej tekst'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => context.push('/settings/authoring'),
            icon: const Icon(Icons.help_outline),
            label: const Text('Jak poprosić inne AI o scenariusz?'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFile(BuildContext context) async {
    final f = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['md', 'json', 'txt', 'markdown'],
    );
    if (f == null || !context.mounted) return;
    final List<int> bytes;
    try {
      bytes = await f.readAsBytes();
    } catch (_) {
      _snack('Nie udało się odczytać pliku.');
      return;
    }
    String text;
    try {
      text = utf8.decode(bytes);
    } catch (_) {
      text = latin1.decode(bytes);
    }
    await _handleText(text);
  }

  Future<void> _pasteText(BuildContext context) async {
    final c = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Wklej scenariusz'),
        content: TextField(
          controller: c,
          minLines: 8,
          maxLines: 14,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Tekst scenariusza (Markdown lub JSON)…'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anuluj')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Importuj')),
        ],
      ),
    );
    c.dispose();
    if (text == null || text.trim().isEmpty) return;
    await _handleText(text);
  }

  Future<void> _handleText(String text) => importText(context, ref, text);

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!,
                  style: const TextStyle(color: Colors.white60, fontSize: 13)),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
