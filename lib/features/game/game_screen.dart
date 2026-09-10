import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../domain/catalog.dart';
import '../../domain/puzzle.dart';
import 'game_controller.dart';
import 'puzzles/puzzle_view.dart';
import 'widgets/clue_notebook.dart';
import 'widgets/gm_bubble.dart';
import 'widgets/gm_chat_sheet.dart';
import 'widgets/hint_sheet.dart';
import 'widgets/scene_view.dart';
import 'widgets/success_effect_overlay.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key, required this.saveId});

  final String saveId;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  OpenExplanationPuzzle? _dialogShownFor;

  @override
  Widget build(BuildContext context) {
    final provider = gameControllerProvider(widget.saveId);
    final async = ref.watch(provider);

    ref.listen(provider, (prev, next) {
      final s = next.valueOrNull;
      if (s == null) return;
      if (s.pendingSelfJudge != null && _dialogShownFor != s.pendingSelfJudge) {
        _dialogShownFor = s.pendingSelfJudge;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showSelfJudgeDialog(s.pendingSelfJudge!, s.error);
        });
      }
      if (s.finished && (prev?.valueOrNull?.finished != true)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/victory/${widget.saveId}');
        });
      }
    });

    return async.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Nie udało się wczytać gry.\n$e',
                textAlign: TextAlign.center),
          ),
        ),
      ),
      data: (s) {
        if (s.finished) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final palette = ThemePalette.of(s.spec.visualTheme);
        final accent = palette.primary;
        final ctrl = ref.read(provider.notifier);
        final progress = (s.stageIndex + (s.stageSolved ? 1 : 0)) / s.spec.stages.length;

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.spec.title,
                    style: const TextStyle(fontSize: 17), overflow: TextOverflow.ellipsis),
                Text('Etap ${s.stageIndex + 1} z ${s.spec.stages.length}',
                    style: TextStyle(fontSize: 12, color: accent)),
              ],
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Do biblioteki (postęp zapisany)',
              onPressed: () => context.go('/'),
            ),
            actions: [
              _HintButton(
                used: s.hintsRevealed,
                total: s.stage.hints.length,
                accent: accent,
                onPressed: s.stageSolved
                    ? null
                    : () => showHintSheet(
                          context,
                          hints: s.stage.hints,
                          revealed: () => ref.read(provider).valueOrNull?.hintsRevealed ?? 0,
                          onReveal: ctrl.revealHint,
                          accent: accent,
                        ),
              ),
              IconButton(
                tooltip: 'Rozmowa z Mistrzem Gry',
                icon: const Icon(Icons.forum_outlined),
                onPressed: () => showGmChatSheet(
                  context,
                  history: () => ref.read(provider).valueOrNull?.save.history ?? const [],
                  onSend: ctrl.chat,
                  liveGm: ctrl.liveGm,
                  accent: accent,
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  LinearProgressIndicator(
                    value: progress,
                    color: accent,
                    backgroundColor: Colors.white10,
                    minHeight: 3,
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
                      children: [
                        SceneView(
                          stage: s.stage,
                          palette: palette,
                          enabled: !s.busy,
                          solved: s.stageSolved,
                          lit: s.stageSolved &&
                              s.stage.effectOnSuccess == SuccessEffect.lightsOn,
                          onInspect: ctrl.inspect,
                          discovered: s.discovered,
                          focusObjectId: s.reaction?.focusObjectId,
                        ),
                        const SizedBox(height: 12),
                        GmBubble(
                          text: s.reaction?.text ?? s.stage.narrative,
                          mood: s.reaction?.mood ?? 'neutral',
                          accent: accent,
                          busyLabel: s.busy ? s.busyLabel : null,
                          fromAi: s.reaction?.fromAi ?? false,
                        ),
                        if (s.stage.scene.clueObjects.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: ClueNotebook(
                              stage: s.stage,
                              discovered: s.discovered,
                              accent: accent,
                            ),
                          ),
                        if (s.reaction?.offerHint == true && !s.stageSolved)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: ActionChip(
                                avatar: Icon(Icons.lightbulb, size: 18, color: accent),
                                label: const Text('Chcecie podpowiedź?'),
                                onPressed: () => showHintSheet(
                                  context,
                                  hints: s.stage.hints,
                                  revealed: () => ref.read(provider).valueOrNull?.hintsRevealed ?? 0,
                                  onReveal: ctrl.revealHint,
                                  accent: accent,
                                ),
                              ),
                            ),
                          ),
                        if (s.error != null && s.pendingSelfJudge == null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Card(
                              color: const Color(0xFF3B1D1D),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(children: [
                                  const Icon(Icons.error_outline, color: Colors.redAccent),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(s.error!)),
                                ]),
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: s.stageSolved
                                ? _SolvedPanel(
                                    accent: accent,
                                    isLast: s.isLastStage,
                                    busy: s.busy,
                                    onNext: ctrl.nextStage,
                                  )
                                : PuzzleView(
                                    puzzle: s.stage.puzzle,
                                    enabled: !s.busy,
                                    accent: accent,
                                    onSubmit: ctrl.submitAnswer,
                                  ),
                          ),
                        ),
                        if (s.attempts > 0 && !s.stageSolved)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text('Nieudane próby: ${s.attempts}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white38, fontSize: 12)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (s.effect != null)
                Positioned.fill(
                  child: SuccessEffectOverlay(
                    key: ValueKey('${s.stageIndex}-${s.effect}'),
                    effect: s.effect!,
                    accent: accent,
                    onDone: ctrl.effectDone,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showSelfJudgeDialog(OpenExplanationPuzzle p, String? error) async {
    final ctrl = ref.read(gameControllerProvider(widget.saveId).notifier);
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Ocena bez AI'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error == null
                  ? 'Ta zagadka wymaga oceny opisu, a Mistrz Gry AI jest niedostępny (brak klucza API). Porównajcie odpowiedź z przykładowym rozwiązaniem i oceńcie sami.'
                  : 'Sędzia AI nie odpowiedział ($error). Porównajcie odpowiedź z przykładowym rozwiązaniem i oceńcie sami.'),
              const SizedBox(height: 12),
              Text('Przykładowe rozwiązanie:',
                  style: Theme.of(ctx).textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(p.exampleSolution),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Próbujemy dalej'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Zaliczam!'),
          ),
        ],
      ),
    );
    _dialogShownFor = null;
    if (!mounted) return;
    await ctrl.selfJudge(accepted ?? false);
  }
}

class _HintButton extends StatelessWidget {
  const _HintButton({
    required this.used,
    required this.total,
    required this.accent,
    required this.onPressed,
  });

  final int used;
  final int total;
  final Color accent;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Podpowiedzi',
      onPressed: onPressed,
      icon: Badge(
        label: Text('$used/$total'),
        backgroundColor: used == 0 ? Colors.white24 : accent,
        textColor: used == 0 ? Colors.white : Colors.black,
        child: const Icon(Icons.lightbulb_outline),
      ),
    );
  }
}

class _SolvedPanel extends StatelessWidget {
  const _SolvedPanel({
    required this.accent,
    required this.isLast,
    required this.busy,
    required this.onNext,
  });

  final Color accent;
  final bool isLast;
  final bool busy;
  final Future<bool> Function() onNext;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.check_circle, size: 56, color: accent),
        const SizedBox(height: 8),
        Text('Rozwiązane!',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: accent, foregroundColor: Colors.black),
          onPressed: busy ? null : onNext,
          icon: Icon(isLast ? Icons.emoji_events : Icons.arrow_forward),
          label: Text(isLast ? 'Wyjdźcie na wolność!' : 'Dalej'),
        ),
      ],
    );
  }
}
