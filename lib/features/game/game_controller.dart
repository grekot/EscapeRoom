import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/ai/ai_errors.dart';
import '../../core/ai/pipeline/game_master.dart';
import '../../domain/catalog.dart';
import '../../domain/game_save.dart';
import '../../domain/game_spec.dart';
import '../../domain/puzzle.dart';
import '../../domain/puzzle_validator.dart';

/// UI state of one play session.
class GameSession {
  const GameSession({
    required this.spec,
    required this.save,
    this.reaction,
    this.busy = false,
    this.busyLabel,
    this.stageSolved = false,
    this.effect,
    this.error,
    this.pendingSelfJudge,
    this.pendingAnswer,
    this.finished = false,
  });

  final GameSpec spec;
  final GameSave save;

  /// Latest game-master utterance.
  final GmReaction? reaction;
  final bool busy;
  final String? busyLabel;

  /// Current stage solved; waiting for "Dalej".
  final bool stageSolved;

  /// Effect to play once (cleared after the animation).
  final SuccessEffect? effect;
  final String? error;

  /// An open_explanation answer awaiting parent's verdict (no AI available).
  final OpenExplanationPuzzle? pendingSelfJudge;
  final String? pendingAnswer;
  final bool finished;

  int get stageIndex => save.stageIndex.clamp(0, spec.stages.length - 1);
  GameStage get stage => spec.stages[stageIndex];
  /// Ids of the current stage's objects the players have examined.
  Set<String> get discovered => save.discoveredIn(stageIndex);

  /// The object's finding cannot be read yet (its prerequisite not examined).
  bool isLocked(SceneObject o) => o.isChained && !discovered.contains(o.requires);

  int get hintsRevealed =>
      stageIndex < save.hintsUsed.length ? save.hintsUsed[stageIndex] : 0;
  int get attempts =>
      stageIndex < save.attempts.length ? save.attempts[stageIndex] : 0;
  bool get isLastStage => stageIndex == spec.stages.length - 1;

  GameSession copyWith({
    GameSave? save,
    GmReaction? reaction,
    bool? busy,
    String? busyLabel,
    bool clearBusyLabel = false,
    bool? stageSolved,
    SuccessEffect? effect,
    bool clearEffect = false,
    String? error,
    bool clearError = false,
    OpenExplanationPuzzle? pendingSelfJudge,
    String? pendingAnswer,
    bool clearSelfJudge = false,
    bool? finished,
  }) =>
      GameSession(
        spec: spec,
        save: save ?? this.save,
        reaction: reaction ?? this.reaction,
        busy: busy ?? this.busy,
        busyLabel: clearBusyLabel ? null : (busyLabel ?? this.busyLabel),
        stageSolved: stageSolved ?? this.stageSolved,
        effect: clearEffect ? null : (effect ?? this.effect),
        error: clearError ? null : (error ?? this.error),
        pendingSelfJudge:
            clearSelfJudge ? null : (pendingSelfJudge ?? this.pendingSelfJudge),
        pendingAnswer:
            clearSelfJudge ? null : (pendingAnswer ?? this.pendingAnswer),
        finished: finished ?? this.finished,
      );
}

class GameController extends AutoDisposeFamilyAsyncNotifier<GameSession, String> {
  late GameMaster _gm;
  bool _liveGm = true;

  @override
  Future<GameSession> build(String saveId) async {
    final save = await ref.read(saveRepoProvider).byId(saveId);
    if (save == null) throw StateError('Brak zapisu gry.');
    final spec = await ref.read(gameSpecRepoProvider).byId(save.gameSpecId);
    if (spec == null) throw StateError('Brak gry dla tego zapisu.');
    final settings = await ref.read(settingsProvider.future);
    final ai = await ref.read(aiProviderProvider.future);
    _liveGm = settings.liveGm && ai != null;
    _gm = GameMaster(
      ai: _liveGm ? ai : null,
      spec: spec,
      playerNames: settings.playerNames,
    );
    final session = GameSession(spec: spec, save: save);
    if (save.completed) return session.copyWith(finished: true);

    // Entering (or resuming) a stage: narrate.
    if (save.history.isEmpty) {
      final r = await _gm.react(const StageEntered(),
          stageIndex: session.stageIndex, history: const []);
      final s2 = session.copyWith(
          reaction: r,
          save: save
              .withMessage(GmMessage(role: 'event', text: 'Start: ${spec.stages[session.stageIndex].title}', at: DateTime.now()))
              .withMessage(GmMessage(role: 'gm', text: r.text, at: DateTime.now())));
      await _persist(s2.save);
      return s2;
    }
    final lastGm = save.history.lastWhere((m) => m.role == 'gm',
        orElse: () => GmMessage(
            role: 'gm', text: spec.stages[session.stageIndex].narrative, at: DateTime.now()));
    // Resume exactly where the player left off, including a solved stage
    // that still waits for "Dalej".
    final resumed = session.copyWith(
      reaction: GmReaction(text: lastGm.text, mood: save.stageSolved ? 'triumphant' : 'neutral'),
      stageSolved: save.stageSolved,
    );
    // After a real break the GM recaps what the players already know.
    final away = DateTime.now().difference(save.lastPlayedAt);
    if (_liveGm && !save.stageSolved && away > const Duration(minutes: 20)) {
      final r = await _gm.react(GameResumed(away),
          stageIndex: resumed.stageIndex, history: save.history, state: _gmState(resumed));
      if (r.fromAi) {
        final s2 = resumed.copyWith(
            reaction: r,
            save: save.withMessage(GmMessage(role: 'gm', text: r.text, at: DateTime.now())));
        await _persist(s2.save);
        return s2;
      }
    }
    return resumed;
  }

  GameSession get _s => state.requireValue;

  Future<void> _persist(GameSave save) =>
      ref.read(saveRepoProvider).save(save);

  void _set(GameSession s) => state = AsyncData(s);

  Future<GmReaction> _react(GmEvent e, GameSession s) =>
      _gm.react(e, stageIndex: s.stageIndex, history: s.save.history, state: _gmState(s));

  /// What the GM should know about progress in the current stage.
  GmState _gmState(GameSession s) {
    final h = s.save.history;
    final startIdx = h.lastIndexWhere((m) => m.role == 'event' && m.text.startsWith('Start:'));
    final since = startIdx >= 0 ? h.sublist(startIdx) : h;
    const prefix = 'Odpowiedź: ';
    final answers = [
      for (final m in since)
        if (m.role == 'player' && m.text.startsWith(prefix)) m.text.substring(prefix.length),
    ];
    return GmState(
      discovered: s.discovered,
      attempts: s.attempts,
      hintsUsed: s.hintsRevealed,
      elapsed: DateTime.now().difference(startIdx >= 0 ? h[startIdx].at : s.save.startedAt),
      wrongAnswers: answers.length > 3 ? answers.sublist(answers.length - 3) : answers,
    );
  }

  GameSave _log(GameSave save, String role, String text) =>
      save.withMessage(GmMessage(role: role, text: text, at: DateTime.now()));

  /// [display] is the human-readable answer for the transcript.
  Future<void> submitAnswer(Object answer, String display) async {
    var s = _s;
    if (s.busy || s.stageSolved) return;
    final result = PuzzleValidator.check(s.stage.puzzle, answer);
    switch (result) {
      case LocalResult r:
        await _resolve(r.correct, display, detail: r.detail);
      case NeedsAiJudgement j:
        final ai = await ref.read(aiProviderProvider.future);
        if (ai == null) {
          _set(s.copyWith(pendingSelfJudge: j.puzzle, pendingAnswer: display));
          return;
        }
        _set(s.copyWith(busy: true, busyLabel: 'Mistrz Gry ocenia odpowiedź…', clearError: true));
        try {
          final verdict = await judgeOpenAnswer(ai, j.puzzle, j.answer,
              age: s.spec.targetAge);
          s = _s.copyWith(busy: false, clearBusyLabel: true);
          _set(s);
          await _resolve(verdict.correct, display,
              detail: verdict.feedback, skipGmForFailure: true);
        } on AiException catch (e) {
          _set(_s.copyWith(
              busy: false, clearBusyLabel: true,
              error: e.userMessage, pendingSelfJudge: j.puzzle,
              pendingAnswer: display));
        }
    }
  }

  /// Parent's verdict for an open answer when no AI is configured.
  Future<void> selfJudge(bool accepted) async {
    final display = _s.pendingAnswer ?? '(odpowiedź opisowa)';
    _set(_s.copyWith(clearSelfJudge: true, clearError: true));
    await _resolve(accepted, display);
  }

  Future<void> _resolve(bool correct, String display,
      {String? detail, bool skipGmForFailure = false}) async {
    var s = _s;
    var save = _log(s.save, 'player', 'Odpowiedź: $display');
    if (correct) {
      HapticFeedback.mediumImpact();
      save = save.copyWith(stageSolved: true);
      await _persist(save);
      _set(s.copyWith(
          save: save,
          stageSolved: true,
          effect: s.stage.effectOnSuccess,
          busy: true,
          busyLabel: 'Coś się dzieje…'));
      final r = await _react(CorrectAnswer(display, isLastStage: s.isLastStage), _s);
      save = _log(_s.save, 'gm', r.text);
      _set(_s.copyWith(save: save, reaction: r, busy: false, clearBusyLabel: true));
      await _persist(save);
    } else {
      HapticFeedback.vibrate();
      save = save.withAttempt(s.stageIndex);
      s = s.copyWith(save: save);
      if (skipGmForFailure && detail != null && detail.isNotEmpty) {
        final r = GmReaction(text: detail, mood: 'encouraging', offerHint: s.attempts >= 2);
        save = _log(save, 'gm', r.text);
        _set(s.copyWith(save: save, reaction: r));
        await _persist(save);
        return;
      }
      _set(s.copyWith(busy: _liveGm, busyLabel: _liveGm ? 'Mistrz Gry reaguje…' : null));
      final r = await _react(WrongAnswer(display, s.attempts, detail: detail), s);
      save = _log(_s.save, 'gm', r.text);
      _set(_s.copyWith(save: save, reaction: r, busy: false, clearBusyLabel: true));
      await _persist(save);
    }
  }

  void effectDone() {
    if (_s.effect != null) _set(_s.copyWith(clearEffect: true));
  }

  /// Reveals the next hint; returns it (or null when none left).
  Future<String?> revealHint() async {
    final s = _s;
    final n = s.hintsRevealed;
    if (n >= s.stage.hints.length) return null;
    final hint = s.stage.hints[n];
    var save = _log(s.save.withHintUsed(s.stageIndex), 'event', 'Podpowiedź ${n + 1}: $hint');
    _set(s.copyWith(save: save));
    await _persist(save);
    if (_liveGm) {
      final r = await _react(HintRequested(n + 1, hint), _s);
      save = _log(_s.save, 'gm', r.text);
      _set(_s.copyWith(save: save, reaction: r));
      await _persist(save);
    }
    return hint;
  }

  Future<void> inspect(SceneObject o) async {
    final s = _s;
    if (s.busy) return;
    final locked = s.isLocked(o);
    final event = ObjectInspected(o, locked: locked);
    var save = _log(s.save, 'event',
        locked ? 'Oglądają: ${o.label} (jeszcze nieczytelny)' : 'Oglądają: ${o.label}');
    // An examined object joins the notebook (its finding is now known).
    if (!locked) save = save.withDiscovered(s.stageIndex, o.id);
    // Decorative objects are described locally; interactive ones by the GM.
    final askGm = _liveGm && o.interactive;
    _set(s.copyWith(save: save, busy: askGm, busyLabel: askGm ? 'Mistrz Gry opisuje…' : null));
    final r = askGm ? await _react(event, _s) : GmReaction(text: event.fallbackText);
    save = _log(_s.save, 'gm', r.text);
    _set(_s.copyWith(save: save, reaction: r, busy: false, clearBusyLabel: true));
    await _persist(save);
  }

  Future<void> chat(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    final s = _s;
    var save = _log(s.save, 'player', t);
    _set(s.copyWith(save: save, busy: true, busyLabel: 'Mistrz Gry odpowiada…'));
    final r = await _react(FreeChat(t), _s);
    save = _log(_s.save, 'gm', r.text);
    _set(_s.copyWith(save: save, reaction: r, busy: false, clearBusyLabel: true));
    await _persist(save);
  }

  /// Advances after a solved stage. Returns true when the game is finished.
  Future<bool> nextStage() async {
    final s = _s;
    if (!s.stageSolved) return false;
    if (s.isLastStage) {
      final save = s.save.copyWith(
          stageIndex: s.spec.stages.length,
          finishedAt: DateTime.now(),
          stageSolved: false);
      _set(s.copyWith(save: save, finished: true, stageSolved: false));
      await _persist(save);
      ref.invalidate(libraryProvider);
      return true;
    }
    final next = s.stageIndex + 1;
    var save = _log(s.save.copyWith(stageIndex: next, stageSolved: false), 'event',
        'Start: ${s.spec.stages[next].title}');
    _set(s.copyWith(
        save: save, stageSolved: false, clearEffect: true,
        busy: _liveGm, busyLabel: _liveGm ? 'Mistrz Gry opowiada…' : null,
        reaction: GmReaction(text: s.spec.stages[next].narrative)));
    final r = await _react(const StageEntered(), _s);
    save = _log(_s.save, 'gm', r.text);
    _set(_s.copyWith(save: save, reaction: r, busy: false, clearBusyLabel: true));
    await _persist(save);
    return false;
  }

  bool get liveGm => _liveGm;
}

final gameControllerProvider = AsyncNotifierProvider.autoDispose
    .family<GameController, GameSession, String>(GameController.new);
