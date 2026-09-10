import 'json_utils.dart';

/// One line of the game-master conversation, kept so that resuming a game
/// preserves context.
class GmMessage {
  const GmMessage({required this.role, required this.text, required this.at});

  /// `player` | `gm` | `event`
  final String role;
  final String text;
  final DateTime at;

  factory GmMessage.fromJson(Map<String, dynamic> j) => GmMessage(
        role: jStr(j, 'role', fallback: 'gm'),
        text: jStr(j, 'text'),
        at: jDate(j, 'at'),
      );

  Map<String, dynamic> toJson() =>
      {'role': role, 'text': text, 'at': at.toIso8601String()};
}

/// Progress of one play-through of a [GameSpec].
class GameSave {
  const GameSave({
    required this.id,
    required this.gameSpecId,
    required this.stageIndex,
    required this.hintsUsed,
    required this.attempts,
    required this.startedAt,
    required this.finishedAt,
    required this.history,
    required this.lastPlayedAt,
    this.stageSolved = false,
    this.discovered = const [],
  });

  final String id;
  final String gameSpecId;

  /// Index of the current (unsolved) stage; equals stage count when finished.
  final int stageIndex;

  /// Number of hints revealed per stage index.
  final List<int> hintsUsed;

  /// Number of wrong answers per stage index.
  final List<int> attempts;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final List<GmMessage> history;
  final DateTime lastPlayedAt;

  /// Current stage is solved and waits for the player to tap "Dalej".
  final bool stageSolved;

  /// Objects the players have examined, as `<stageIndex>:<objectId>`.
  final List<String> discovered;

  Set<String> discoveredIn(int stage) => {
        for (final d in discovered)
          if (d.startsWith('$stage:')) d.substring('$stage:'.length),
      };

  GameSave withDiscovered(int stage, String objectId) {
    final key = '$stage:$objectId';
    if (discovered.contains(key)) return this;
    return copyWith(discovered: [...discovered, key]);
  }

  bool get completed => finishedAt != null;
  int get totalHints => hintsUsed.fold(0, (a, b) => a + b);
  int get totalAttempts => attempts.fold(0, (a, b) => a + b);

  Duration get elapsed =>
      (finishedAt ?? DateTime.now()).difference(startedAt);

  factory GameSave.start({
    required String id,
    required String gameSpecId,
    required int stageCount,
  }) {
    final now = DateTime.now();
    return GameSave(
      id: id,
      gameSpecId: gameSpecId,
      stageIndex: 0,
      hintsUsed: List.filled(stageCount, 0),
      attempts: List.filled(stageCount, 0),
      startedAt: now,
      finishedAt: null,
      history: const [],
      lastPlayedAt: now,
    );
  }

  factory GameSave.fromJson(Map<String, dynamic> j) => GameSave(
        id: jStr(j, 'id'),
        gameSpecId: jStr(j, 'gameSpecId'),
        stageIndex: jInt(j, 'stageIndex'),
        hintsUsed: jIntList(j, 'hintsUsed'),
        attempts: jIntList(j, 'attempts'),
        startedAt: jDate(j, 'startedAt'),
        finishedAt: j['finishedAt'] == null ? null : jDate(j, 'finishedAt'),
        history: jMapList(j, 'history').map(GmMessage.fromJson).toList(),
        lastPlayedAt: jDate(j, 'lastPlayedAt'),
        stageSolved: jBool(j, 'stageSolved'),
        discovered: jStrList(j, 'discovered'),
      );

  Map<String, dynamic> toJson() => {
        'stageSolved': stageSolved,
        'discovered': discovered,
        'id': id,
        'gameSpecId': gameSpecId,
        'stageIndex': stageIndex,
        'hintsUsed': hintsUsed,
        'attempts': attempts,
        'startedAt': startedAt.toIso8601String(),
        'finishedAt': finishedAt?.toIso8601String(),
        'history': history.map((m) => m.toJson()).toList(),
        'lastPlayedAt': lastPlayedAt.toIso8601String(),
      };

  GameSave copyWith({
    int? stageIndex,
    List<int>? hintsUsed,
    List<int>? attempts,
    DateTime? finishedAt,
    List<GmMessage>? history,
    DateTime? lastPlayedAt,
    bool? stageSolved,
    List<String>? discovered,
  }) =>
      GameSave(
        id: id,
        gameSpecId: gameSpecId,
        stageIndex: stageIndex ?? this.stageIndex,
        hintsUsed: hintsUsed ?? this.hintsUsed,
        attempts: attempts ?? this.attempts,
        startedAt: startedAt,
        finishedAt: finishedAt ?? this.finishedAt,
        history: history ?? this.history,
        lastPlayedAt: lastPlayedAt ?? DateTime.now(),
        stageSolved: stageSolved ?? this.stageSolved,
        discovered: discovered ?? this.discovered,
      );

  GameSave withHintUsed(int stage) {
    final h = List<int>.from(hintsUsed);
    while (h.length <= stage) {
      h.add(0);
    }
    h[stage] += 1;
    return copyWith(hintsUsed: h);
  }

  GameSave withAttempt(int stage) {
    final a = List<int>.from(attempts);
    while (a.length <= stage) {
      a.add(0);
    }
    a[stage] += 1;
    return copyWith(attempts: a);
  }

  GameSave withMessage(GmMessage m, {int keepLast = 60}) {
    final h = [...history, m];
    final trimmed = h.length > keepLast ? h.sublist(h.length - keepLast) : h;
    return copyWith(history: trimmed);
  }
}
