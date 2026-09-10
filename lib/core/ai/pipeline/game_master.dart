import '../../../domain/game_save.dart';
import '../../../domain/game_spec.dart';
import '../../../domain/puzzle.dart';
import '../ai_provider.dart';
import 'gm_state.dart';
import 'prompts/gm_prompts.dart';

export 'gm_state.dart';
import 'schemas/game_spec_schema.dart';

/// Something the player did that the game master may react to.
sealed class GmEvent {
  const GmEvent();

  /// One-line description for the transcript / prompt.
  String describe();
}

class StageEntered extends GmEvent {
  const StageEntered();
  @override
  String describe() => 'Gracze wchodzą do nowego etapu i widzą scenę.';
}

class WrongAnswer extends GmEvent {
  const WrongAnswer(this.answerText, this.attempt, {this.detail});
  final String answerText;
  final int attempt;
  final String? detail;
  @override
  String describe() =>
      'Gracze podali BŁĘDNĄ odpowiedź (próba nr $attempt): „$answerText”.${detail != null ? ' Informacja z aplikacji: $detail' : ''}';
}

class CorrectAnswer extends GmEvent {
  const CorrectAnswer(this.answerText, {this.isLastStage = false});
  final String answerText;
  final bool isLastStage;
  @override
  String describe() =>
      'Gracze podali POPRAWNĄ odpowiedź: „$answerText”.${isLastStage ? ' To był ostatni etap – gra wygrana!' : ' Przechodzą do następnego etapu.'}';
}

class HintRequested extends GmEvent {
  const HintRequested(this.number, this.hintText);
  final int number;
  final String hintText;
  @override
  String describe() =>
      'Gracze poprosili o podpowiedź nr $number. Aplikacja pokazała im: „$hintText”. Skomentuj krótko w klimacie, nie dodawaj nowych informacji.';
}

class ObjectInspected extends GmEvent {
  const ObjectInspected(this.object, {this.locked = false});
  final SceneObject object;

  /// The object's finding is not readable yet (its `requires` not examined).
  final bool locked;

  @override
  String describe() {
    if (locked) {
      return 'Gracze oglądają obiekt „${object.label}” (id ${object.id}), ale jest ZABLOKOWANY – najpierw muszą zbadać obiekt „${object.requires}”. Widzą tylko: „${object.lockedText.isEmpty ? object.description : object.lockedText}”. Nie zdradzaj odkrycia (clue) tego obiektu.';
    }
    final sb = StringBuffer('Gracze oglądają obiekt „${object.label}” (id ${object.id}). Opis: ${object.description}');
    if (object.hasClue) {
      sb.write(' Aplikacja pokazała im odkrycie: „${object.clue}” – potwierdź je wiernie i dodaj klimat.');
    }
    return sb.toString();
  }

  /// Text shown when no AI game master is available.
  String get fallbackText => locked
      ? (object.lockedText.isEmpty ? object.description : object.lockedText)
      : [object.description, if (object.hasClue) object.clue].join(' ');
}

class FreeChat extends GmEvent {
  const FreeChat(this.text);
  final String text;
  @override
  String describe() => 'Gracze mówią do Mistrza Gry: „$text”';
}

/// Players come back to an unfinished stage after a break.
class GameResumed extends GmEvent {
  const GameResumed(this.away);
  final Duration away;
  @override
  String describe() =>
      'Gracze wracają do gry po przerwie (${away.inMinutes} min). Przywitaj ich w swojej roli i streść w 1–3 zdaniach, co już odkryli (STAN ŚLEDZTWA) i co pozostaje do zrobienia w tym etapie – bez zdradzania rozwiązania. Jeśli mają niezbadane obiekty, wskaż jeden w focusObjectId.';
}

class GmReaction {
  const GmReaction({
    required this.text,
    this.mood = 'neutral',
    this.offerHint = false,
    this.fromAi = false,
    this.focusObjectId,
  });

  final String text;

  /// neutral | encouraging | tense | triumphant
  final String mood;
  final bool offerHint;
  final bool fromAi;

  /// Scene object the GM points at (the app highlights it), if any.
  final String? focusObjectId;
}

/// Live game master. Falls back to canned texts when [ai] is null or fails.
class GameMaster {
  GameMaster({required this.ai, required this.spec, required this.playerNames});

  final AiProvider? ai;
  final GameSpec spec;
  final String playerNames;

  Future<GmReaction> react(
    GmEvent event, {
    required int stageIndex,
    required List<GmMessage> history,
    GmState? state,
  }) async {
    final fallback = _fallback(event, stageIndex);
    final provider = ai;
    if (provider == null) return fallback;
    final objectIds = [for (final o in spec.stages[stageIndex].scene.objects) o.id];
    try {
      final j = await provider.completeJson(
        system: GmPrompts.system(spec, stageIndex, playerNames: playerNames, state: state),
        user: GmPrompts.user(history.length > 24
            ? history.sublist(history.length - 24)
            : history, event.describe()),
        schema: gmReactionJsonSchema(objectIds: objectIds),
        maxTokens: 700,
        timeout: const Duration(seconds: 40),
      );
      final text = (j['narration'] ?? '').toString().trim();
      if (text.isEmpty) return fallback;
      final focus = (j['focusObjectId'] ?? '').toString().trim();
      return GmReaction(
        text: text,
        mood: (j['mood'] ?? fallback.mood).toString(),
        offerHint: j['offerHint'] == true,
        fromAi: true,
        focusObjectId: objectIds.contains(focus) ? focus : null,
      );
    } catch (_) {
      return fallback;
    }
  }

  GmReaction _fallback(GmEvent event, int stageIndex) {
    final stage = spec.stages[stageIndex];
    return switch (event) {
      StageEntered() => GmReaction(text: stage.narrative),
      WrongAnswer e => GmReaction(
          text: e.detail == null
              ? stage.fallbackTexts.failure
              : '${stage.fallbackTexts.failure} ${e.detail}',
          mood: 'encouraging',
          offerHint: e.attempt >= 3,
        ),
      // The outro is shown on the victory screen, so no need to append it here.
      CorrectAnswer() => GmReaction(
          text: stage.fallbackTexts.success,
          mood: 'triumphant',
        ),
      HintRequested() => const GmReaction(text: 'Posłuchajcie uważnie…'),
      ObjectInspected e => GmReaction(text: e.fallbackText),
      FreeChat() => GmReaction(text: stage.fallbackTexts.stuck),
      GameResumed() => GmReaction(text: stage.narrative),
    };
  }
}

class Judgement {
  const Judgement({required this.correct, required this.feedback});
  final bool correct;
  final String feedback;
}

/// Grades an [OpenExplanationPuzzle] answer with the model.
Future<Judgement> judgeOpenAnswer(
  AiProvider ai,
  OpenExplanationPuzzle puzzle,
  String answer, {
  required int age,
}) async {
  final j = await ai.completeJson(
    system: GmPrompts.judgeSystem(age),
    user: GmPrompts.judgeUser(puzzle, answer),
    schema: judgementJsonSchema(),
    maxTokens: 600,
    timeout: const Duration(seconds: 60),
  );
  return Judgement(
    correct: j['correct'] == true,
    feedback: (j['feedback'] ?? '').toString(),
  );
}
