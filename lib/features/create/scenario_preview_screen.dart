import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/storage/repositories.dart';
import '../../domain/catalog.dart';
import '../../domain/scenario.dart';
import '../../domain/scenario_markdown.dart';
import '../game/start_game.dart';
import '../library/export.dart';
import 'jobs.dart';

class ScenarioPreviewScreen extends ConsumerStatefulWidget {
  const ScenarioPreviewScreen({super.key, required this.scenarioId});

  final String scenarioId;

  @override
  ConsumerState<ScenarioPreviewScreen> createState() =>
      _ScenarioPreviewScreenState();
}

class _ScenarioPreviewScreenState extends ConsumerState<ScenarioPreviewScreen> {
  bool _spoilers = false;

  @override
  Widget build(BuildContext context) {
    final lib = ref.watch(libraryProvider);
    final hasAi = ref.watch(aiProviderProvider).valueOrNull != null;
    return lib.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(), body: Center(child: Text('Błąd: $e'))),
      data: (d) {
        final s = d.scenarios.where((x) => x.id == widget.scenarioId).firstOrNull;
        if (s == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Nie znaleziono scenariusza.')),
          );
        }
        final games = d.gamesForScenario(s.id);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Scenariusz'),
            actions: [
              IconButton(
                tooltip: _spoilers ? 'Ukryj rozwiązania' : 'Pokaż rozwiązania (dla rodzica)',
                icon: Icon(_spoilers ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _spoilers = !_spoilers),
              ),
              PopupMenuButton<String>(
                onSelected: (v) => _onMenu(v, s),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Zmień tytuł / wiek / trudność')),
                  const PopupMenuItem(value: 'md', child: Text('Eksportuj (Markdown)')),
                  const PopupMenuItem(value: 'json', child: Text('Eksportuj (JSON)')),
                  if (!isBuiltin(s.id))
                    const PopupMenuItem(value: 'delete', child: Text('Usuń scenariusz')),
                ],
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton.icon(
                onPressed: hasAi
                    ? () => context.push('/generating', extra: designGameJob(s))
                    : null,
                icon: const Icon(Icons.auto_fix_high),
                label: Text(games.isEmpty
                    ? 'Zaprojektuj grę z tego scenariusza'
                    : 'Zaprojektuj kolejną wersję gry'),
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              Text(s.title,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              if (s.theme.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(s.theme, style: const TextStyle(color: Colors.white70)),
                ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Chip(avatar: const Icon(Icons.cake, size: 16), label: Text('${s.targetAge}+ lat')),
                  Chip(avatar: const Icon(Icons.speed, size: 16), label: Text(s.difficulty.label)),
                  Chip(avatar: const Icon(Icons.layers, size: 16), label: Text('${s.stages.length} etapów')),
                  if (!hasAi)
                    const Chip(
                      avatar: Icon(Icons.key_off, size: 16, color: Colors.amber),
                      label: Text('brak klucza API'),
                    ),
                ],
              ),
              if (games.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('Gry z tego scenariusza', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                for (final g in games)
                  Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      leading: Icon(themeIcon(g.visualTheme),
                          color: ThemePalette.of(g.visualTheme).primary),
                      title: Text(g.title),
                      subtitle: Text(
                          '${g.designedBy ?? ''} · ${g.createdAt.day}.${g.createdAt.month}.${g.createdAt.year}',
                          style: const TextStyle(fontSize: 12)),
                      trailing: FilledButton(
                        onPressed: () async {
                          final id = await startGame(ref, g);
                          if (context.mounted) context.go('/game/$id');
                        },
                        child: const Text('Graj'),
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 14),
              Text('Wprowadzenie', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(s.intro, style: const TextStyle(height: 1.4)),
              const SizedBox(height: 14),
              for (var i = 0; i < s.stages.length; i++)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      radius: 14,
                      child: Text('${i + 1}', style: const TextStyle(fontSize: 13)),
                    ),
                    title: Text(s.stages[i].title),
                    subtitle: s.stages[i].suggestedType != null
                        ? Text(s.stages[i].suggestedType!,
                            style: const TextStyle(fontSize: 11, color: Colors.white54))
                        : null,
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Field('Miejsce', s.stages[i].place),
                      _Field('Zagadka', s.stages[i].puzzle),
                      if (_spoilers) ...[
                        _Field('Rozwiązanie', s.stages[i].solution, spoiler: true),
                        _Field('Podpowiedzi',
                            s.stages[i].hints.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n'),
                            spoiler: true),
                      ] else
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text('Rozwiązanie i podpowiedzi ukryte (ikona oka u góry).',
                              style: TextStyle(fontSize: 12, color: Colors.white38)),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              Text('Zakończenie', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(s.outro, style: const TextStyle(height: 1.4)),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onMenu(String v, Scenario s) async {
    switch (v) {
      case 'edit':
        await _edit(s);
      case 'md':
        await shareTextFile(context,
            fileName: safeFileName(s.title, 'md'),
            content: ScenarioMarkdown.toMarkdown(s),
            subject: 'Scenariusz: ${s.title}');
      case 'json':
        await shareTextFile(context,
            fileName: safeFileName(s.title, 'json'),
            content: const JsonEncoder.withIndent('  ').convert(s.toJson()),
            subject: 'Scenariusz: ${s.title}');
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            content: Text('Usunąć scenariusz „${s.title}”?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Usuń')),
            ],
          ),
        );
        if (ok == true) {
          await ref.read(scenarioRepoProvider).delete(s.id);
          ref.invalidate(libraryProvider);
          if (mounted) context.go('/');
        }
    }
  }

  Future<void> _edit(Scenario s) async {
    if (isBuiltin(s.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wbudowanego scenariusza nie można edytować.')));
      return;
    }
    final title = TextEditingController(text: s.title);
    var age = s.targetAge;
    var diff = s.difficulty;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Edytuj scenariusz'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Tytuł')),
              const SizedBox(height: 12),
              Row(children: [
                Text('Wiek: $age'),
                Expanded(
                  child: Slider(
                    value: age.toDouble(), min: 5, max: 16, divisions: 11,
                    onChanged: (v) => setD(() => age = v.round()),
                  ),
                ),
              ]),
              SegmentedButton<Difficulty>(
                segments: [for (final d in Difficulty.values) ButtonSegment(value: d, label: Text(d.label))],
                selected: {diff},
                onSelectionChanged: (v) => setD(() => diff = v.first),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Zapisz')),
          ],
        ),
      ),
    );
    if (ok == true) {
      await ref.read(scenarioRepoProvider).save(s.copyWith(
            title: title.text.trim().isEmpty ? s.title : title.text.trim(),
            targetAge: age,
            difficulty: diff,
          ));
      ref.invalidate(libraryProvider);
    }
    title.dispose();
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.text, {this.spoiler = false});

  final String label;
  final String text;
  final bool spoiler;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: spoiler ? Colors.amber : Colors.white54)),
          const SizedBox(height: 2),
          Text(text, style: const TextStyle(height: 1.35)),
        ],
      ),
    );
  }
}
