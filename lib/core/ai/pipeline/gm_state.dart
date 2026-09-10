/// What the live game master knows about the players' progress in the
/// current stage, beyond the raw transcript: which objects they examined,
/// how many wrong answers and hints, how long they have been at it.
class GmState {
  const GmState({
    this.discovered = const {},
    this.attempts = 0,
    this.hintsUsed = 0,
    this.elapsed = Duration.zero,
    this.wrongAnswers = const [],
  });

  /// Ids of examined objects (their findings are in the players' notebook).
  final Set<String> discovered;
  final int attempts;
  final int hintsUsed;
  final Duration elapsed;

  /// Most recent wrong answers, oldest first.
  final List<String> wrongAnswers;
}
