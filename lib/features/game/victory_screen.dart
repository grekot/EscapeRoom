import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/game_save.dart';
import '../../domain/game_spec.dart';
import 'start_game.dart';

class VictoryScreen extends ConsumerWidget {
  const VictoryScreen({super.key, required this.saveId});

  final String saveId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_victoryDataProvider(saveId));
    return data.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Błąd: $e')),
      ),
      data: (d) {
        final palette = ThemePalette.of(d.spec.visualTheme);
        final accent = palette.primary;
        final el = d.save.elapsed;
        final time = '${el.inMinutes} min ${el.inSeconds % 60} s';
        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [palette.top, palette.bottom],
              ),
            ),
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 24),
                  Icon(Icons.emoji_events, size: 96, color: accent),
                  const SizedBox(height: 12),
                  Text('Jesteście wolni!',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(d.spec.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: accent, fontSize: 16)),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(d.spec.outro,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _Stat(icon: Icons.timer, label: 'Czas', value: time, accent: accent),
                      _Stat(icon: Icons.lightbulb, label: 'Podpowiedzi',
                          value: '${d.save.totalHints}', accent: accent),
                      _Stat(icon: Icons.replay, label: 'Pomyłki',
                          value: '${d.save.totalAttempts}', accent: accent),
                    ],
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: accent, foregroundColor: Colors.black),
                    onPressed: () async {
                      final id = await startGame(ref, d.spec);
                      if (context.mounted) context.go('/game/$id');
                    },
                    icon: const Icon(Icons.replay),
                    label: const Text('Zagrajcie jeszcze raz'),
                  ),
                  const SizedBox(height: 10),
                  if (d.hasScenario)
                    OutlinedButton.icon(
                      onPressed: () => context.go('/scenario/${d.spec.scenarioId}'),
                      icon: const Icon(Icons.auto_fix_high),
                      label: const Text('Zaprojektuj tę historię inaczej'),
                    ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.home),
                    label: const Text('Do biblioteki'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VictoryData {
  const _VictoryData(this.spec, this.save, this.hasScenario);
  final GameSpec spec;
  final GameSave save;
  final bool hasScenario;
}

final _victoryDataProvider =
    FutureProvider.autoDispose.family<_VictoryData, String>((ref, saveId) async {
  final save = await ref.read(saveRepoProvider).byId(saveId);
  if (save == null) throw StateError('Brak zapisu.');
  final spec = await ref.read(gameSpecRepoProvider).byId(save.gameSpecId);
  if (spec == null) throw StateError('Brak gry.');
  final sc = await ref.read(scenarioRepoProvider).byId(spec.scenarioId);
  return _VictoryData(spec, save, sc != null);
});

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: accent),
              const SizedBox(height: 6),
              Text(value,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.white60)),
            ],
          ),
        ),
      ),
    );
  }
}
