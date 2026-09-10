import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/ai/image_generator.dart';
import '../../core/ai/pipeline/scene_artist.dart';
import '../../core/storage/repositories.dart';
import '../../domain/game_spec.dart';
import '../../domain/scenario.dart';
import '../../domain/scenario_markdown.dart';
import '../../core/platform/incoming_intent.dart';
import '../../core/update/app_update.dart';
import '../create/import_flow.dart';
import '../settings/update_dialog.dart';
import 'remote_scenarios_card.dart';
import '../create/jobs.dart';
import '../game/start_game.dart';
import 'export.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkIncoming());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkIncoming();
  }

  /// A file opened/shared from another app lands here as text.
  Future<void> _checkIncoming() async {
    final text = await IncomingIntent.takeText();
    if (text != null && mounted) {
      await importText(context, ref, text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lib = ref.watch(libraryProvider);
    final ai = ref.watch(aiProviderProvider).valueOrNull;
    final release = ref.watch(latestReleaseProvider).valueOrNull;
    final scenarioRepo = ref.watch(settingsProvider).valueOrNull?.scenarioRepo ?? '';
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pokój Zagadek AI'),
          actions: [
            IconButton(
              tooltip: 'Ustawienia',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push('/settings'),
            ),
          ],
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.sports_esports), text: 'Gry'),
            Tab(icon: Icon(Icons.description_outlined), text: 'Scenariusze'),
          ]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/create'),
          icon: const Icon(Icons.add),
          label: const Text('Nowa gra'),
        ),
        body: lib.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Błąd: $e')),
          data: (d) => Column(
            children: [
              if (ai == null)
                MaterialBanner(
                  backgroundColor: const Color(0xFF2A2210),
                  leading: const Icon(Icons.key_off, color: Colors.amber),
                  content: const Text(
                      'Brak klucza API – możesz grać we wbudowany pokój, ale nowe gry i Mistrz Gry na żywo wymagają klucza.'),
                  actions: [
                    TextButton(
                      onPressed: () => context.push('/settings'),
                      child: const Text('Ustawienia'),
                    ),
                  ],
                ),
              if (release != null)
                MaterialBanner(
                  backgroundColor: const Color(0xFF10261E),
                  leading: Icon(Icons.system_update, color: Theme.of(context).colorScheme.primary),
                  content: Text(
                      'Dostępna nowa wersja ${release.version} (masz ${AppVersion.current}).'),
                  actions: [
                    TextButton(
                      onPressed: () => showUpdateDialog(context, release),
                      child: const Text('Szczegóły'),
                    ),
                  ],
                ),
              Expanded(
                child: TabBarView(
                  children: [
                    _GamesTab(data: d, hasAi: ai != null),
                    _ScenariosTab(data: d, hasAi: ai != null, remoteRepo: scenarioRepo),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GamesTab extends ConsumerWidget {
  const _GamesTab({required this.data, required this.hasAi});

  final LibraryData data;
  final bool hasAi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (data.games.isEmpty) {
      return const Center(child: Text('Brak gier.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
      itemCount: data.games.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final g = data.games[i];
        final palette = ThemePalette.of(g.visualTheme);
        final inProgress = data.inProgress(g.id);
        final done = data.isCompleted(g.id);
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [palette.top, palette.bottom]),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    Icon(themeIcon(g.visualTheme), color: palette.primary, size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(g.title,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                              overflow: TextOverflow.ellipsis),
                          Text(
                            '${g.stages.length} etapów · ${g.difficulty.label} · ${g.targetAge}+ lat'
                            '${isBuiltin(g.id) ? ' · wbudowana' : ''}',
                            style: const TextStyle(fontSize: 12, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    if (done) const Icon(Icons.emoji_events, color: Colors.amber),
                    PopupMenuButton<String>(
                      onSelected: (v) => _onMenu(context, ref, v, g),
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'restart', child: Text('Zagraj od nowa')),
                        const PopupMenuItem(value: 'export', child: Text('Eksportuj grę (JSON)')),
                        PopupMenuItem(
                            value: 'illustrate',
                            child: Text(g.hasImages
                                ? 'Namaluj scenografię od nowa (Gemini)'
                                : 'Namaluj scenografię (Gemini)')),
                        if (data.scenarios.any((s) => s.id == g.scenarioId))
                          const PopupMenuItem(value: 'scenario', child: Text('Pokaż scenariusz')),
                        if (!isBuiltin(g.id))
                          const PopupMenuItem(value: 'delete', child: Text('Usuń grę')),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(g.intro,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: palette.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                      onPressed: () async {
                        if (inProgress != null) {
                          context.go('/game/${inProgress.id}');
                        } else {
                          final id = await startGame(ref, g);
                          if (context.mounted) context.go('/game/$id');
                        }
                      },
                      icon: Icon(inProgress != null ? Icons.play_arrow : Icons.login),
                      label: Text(inProgress != null
                          ? 'Kontynuuj (${inProgress.stageIndex + 1}/${g.stages.length})'
                          : 'Graj'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onMenu(
      BuildContext context, WidgetRef ref, String v, GameSpec g) async {
    switch (v) {
      case 'restart':
        await ref.read(saveRepoProvider).deleteForGame(g.id);
        final id = await startGame(ref, g);
        if (context.mounted) context.go('/game/$id');
      case 'export':
        await shareTextFile(context,
            fileName: safeFileName(g.title, 'game.json'),
            content: const JsonEncoder.withIndent('  ').convert(g.toJson()),
            subject: 'Gra: ${g.title}');
      case 'scenario':
        context.push('/scenario/${g.scenarioId}');
      case 'illustrate':
        context.push('/generating', extra: illustrateGameJob(g, force: g.hasImages));
      case 'delete':
        final ok = await _confirm(context, 'Usunąć grę „${g.title}” razem z zapisami?');
        if (ok) {
          await ref.read(saveRepoProvider).deleteForGame(g.id);
          await ref.read(gameSpecRepoProvider).delete(g.id);
          await SceneArtist(GeminiImageGenerator(apiKey: '')).deleteImages(g.id);
          ref.invalidate(libraryProvider);
        }
    }
  }
}

class _ScenariosTab extends ConsumerWidget {
  const _ScenariosTab({required this.data, required this.hasAi, this.remoteRepo = ''});

  final LibraryData data;
  final bool hasAi;

  /// GitHub `owner/repo` with downloadable scenarios ('' = feature off).
  final String remoteRepo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasRemote = remoteRepo.trim().isNotEmpty;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
      itemCount: data.scenarios.length + (hasRemote ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (hasRemote && index == 0) return RemoteScenariosCard(repo: remoteRepo);
        final i = hasRemote ? index - 1 : index;
        final s = data.scenarios[i];
        final games = data.gamesForScenario(s.id).length;
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            leading: CircleAvatar(
              backgroundColor: Colors.white10,
              child: Icon(_sourceIcon(s.source), color: Colors.white70),
            ),
            title: Text(s.title, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${s.stages.length} etapów · ${s.difficulty.label} · ${s.targetAge}+ lat · '
              '${_sourceLabel(s.source)}${games > 0 ? ' · gier: $games' : ''}',
              style: const TextStyle(fontSize: 12),
            ),
            onTap: () => context.push('/scenario/${s.id}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Zaprojektuj grę',
                  icon: const Icon(Icons.auto_fix_high),
                  onPressed: hasAi
                      ? () => context.push('/generating', extra: designGameJob(s))
                      : null,
                ),
                PopupMenuButton<String>(
                  onSelected: (v) => _onMenu(context, ref, v, s),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'md', child: Text('Eksportuj (Markdown)')),
                    const PopupMenuItem(value: 'json', child: Text('Eksportuj (JSON)')),
                    if (!isBuiltin(s.id))
                      const PopupMenuItem(value: 'delete', child: Text('Usuń scenariusz')),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _onMenu(
      BuildContext context, WidgetRef ref, String v, Scenario s) async {
    switch (v) {
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
        final ok = await _confirm(context, 'Usunąć scenariusz „${s.title}”? Gry z niego zaprojektowane zostaną.');
        if (ok) {
          await ref.read(scenarioRepoProvider).delete(s.id);
          ref.invalidate(libraryProvider);
        }
    }
  }
}

IconData _sourceIcon(ScenarioSource s) => switch (s) {
      ScenarioSource.builtin => Icons.star,
      ScenarioSource.imported => Icons.file_download,
      ScenarioSource.prompt => Icons.edit_note,
      ScenarioSource.random => Icons.casino,
    };

String _sourceLabel(ScenarioSource s) => switch (s) {
      ScenarioSource.builtin => 'wbudowany',
      ScenarioSource.imported => 'zaimportowany',
      ScenarioSource.prompt => 'z promptu',
      ScenarioSource.random => 'losowy',
    };

Future<bool> _confirm(BuildContext context, String msg) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Usuń')),
      ],
    ),
  );
  return r ?? false;
}

