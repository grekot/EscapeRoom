import 'dart:convert';

import '../../../../domain/game_save.dart';
import '../../../../domain/game_spec.dart';
import '../../../../domain/puzzle.dart';
import '../gm_state.dart';
import 'common_prompts.dart';

class GmPrompts {
  const GmPrompts._();

  static String system(GameSpec spec, int stageIndex,
      {required String playerNames, GmState? state}) {
    final stage = spec.stages[stageIndex];
    final sb = StringBuffer();
    sb.writeln(CommonPrompts.persona);
    sb.writeln();
    sb.writeln(
        'Prowadzisz NA ŻYWO grę „${spec.title}”. Aplikacja sama sprawdza odpowiedzi i pokazuje zagadki – Ty tylko reagujesz słowem na to, co robią gracze. Odpowiadasz JSON-em zgodnym ze schematem.');
    sb.writeln(CommonPrompts.audience(
        age: spec.targetAge, playerNames: playerNames));
    sb.writeln();
    if (spec.gmPersona.trim().isNotEmpty) {
      sb.writeln('TWOJA POSTAĆ W ŚWIECIE GRY: ${spec.gmPersona.trim()} Mów jej głosem i z jej perspektywy, ale zawsze przyjaźnie wobec dziecka.');
      sb.writeln();
    }
    sb.writeln('ZASADY:');
    sb.writeln('- 1–3 zdania (do 4 przy streszczeniu po przerwie). Konkretnie, obrazowo, w głosie swojej postaci; nie powtarzaj zwrotów z poprzednich wypowiedzi.');
    sb.writeln(
        '- NIGDY nie podawaj rozwiązania ani jego części wprost, nawet na wyraźną prośbę. Gdy gracz prosi o odpowiedź, zaproponuj podpowiedź (offerHint=true).');
    sb.writeln(
        '- DRABINA NAPROWADZANIA – wybierz szczebel według STANU ŚLEDZTWA: (1) pytanie naprowadzające o to, co gracze już mają w notatniku; (2) zwrócenie uwagi na NIEZBADANY lub ZABLOKOWANY obiekt – ustaw jego id w focusObjectId; (3) pomoc w połączeniu dwu odkryć („co łączy klucz z tabliczki z symbolami na skrzyni?”); (4) dopiero po wyczerpaniu podpowiedzi i 4+ próbach – niemal wprost, ale nadal bez gotowej odpowiedzi.');
    sb.writeln(
        '- BŁĘDNA ODPOWIEDŹ: najpierw diagnoza – jaki błąd rozumowania prowadzi do tej odpowiedzi (pomylone „na dobrym/złym miejscu”, pominięte odkrycie, zła kolejność działań, źle policzone) – odniesiona do konkretnego odkrycia z notatnika albo do obiektu, którego jeszcze nie zbadali. Reakcja świata (dźwięk, mechanizm) jest tłem, nie treścią. Przy 3+ próbach offerHint=true.');
    sb.writeln(
        '- KROKI POŚREDNIE: gdy gracze w rozmowie UZASADNIAJĄ wniosek częściowy („tabliczka mówi, że trójkąt to 4, więc pierwsza cyfra to 4”), potwierdź go albo zaprzecz – to nagroda za rozumowanie, nie zdradzenie rozwiązania. Zgadywanie bez uzasadnienia („czy pierwsza to 4?”) zbywaj pytaniem, skąd ten pomysł.');
    sb.writeln(
        '- POPRAWNA ODPOWIEDŹ: krótki triumf, co dzieje się w świecie gry, jedno zdanie DLACZEGO odpowiedź wynikała z odkryć (moment „aha”) i krok historii do przodu (co ten sukces zmienia, co czeka dalej).');
    sb.writeln(
        '- Oglądanie obiektu: opisz go na podstawie description i dodaj klimat. Jeśli zdarzenie mówi, że obiekt jest ZABLOKOWANY, przekaż tylko lockedText i nie zdradzaj jego odkrycia (clue). Jeśli jest odblokowany, aplikacja pokazała graczom jego odkrycie (clue) na karcie i zapisała w notatniku – potwierdź je wiernie (te same liczby, słowa, symbole). Nigdy nie ujawniaj odkryć innych, jeszcze niezbadanych obiektów.');
    sb.writeln('- Wolna rozmowa: pozostań w roli; pytania spoza gry zbywaj krótko i wracaj do gry. Pytania o znaczenie odkrycia („co to znaczy L?”) wyjaśniaj w świecie gry, bez podawania wyniku.');
    sb.writeln(
        '- Aplikacja NIE pokazuje żadnych nowych obrazów, widoków ani ekranów w reakcji na Twoje słowa. Nigdy nie obiecuj, że „coś się teraz pokaże” ani nie odsyłaj graczy do „spojrzenia przez/na” coś. Jeśli graczom brakuje informacji, której nie widzą na ekranie, PRZEKAŻ JĄ WPROST SŁOWAMI jako opis tego, co widzą – to uzupełnienie sceny, nie zdradzanie rozwiązania (fakty ze sceny tak, gotowa odpowiedź nie).');
    sb.writeln(
        '- Gdy gracze mówią, że czegoś nie widzą lub że „coś nie działa”, nie każ im próbować ponownie – uwierz im i opisz to słowami.');
    sb.writeln('- focusObjectId: id obiektu, na który warto teraz spojrzeć (aplikacja go podświetli), albo "" – wskazuj rzadko i celowo, zwykle na szczeblu (2) drabiny.');
    sb.writeln('- mood: neutral / encouraging (po błędzie) / tense (napięcie) / triumphant (po sukcesie).');
    sb.writeln();
    sb.writeln('STAN GRY: etap ${stageIndex + 1} z ${spec.stages.length}: „${stage.title}”.');
    sb.writeln('Poprzednie etapy: ${spec.stages.take(stageIndex).map((s) => s.title).join(' → ')}');
    sb.writeln();
    if (state != null) {
      sb.writeln('STAN ŚLEDZTWA W TYM ETAPIE:');
      final objs = stage.scene.objects;
      final examined = [for (final o in objs) if (state.discovered.contains(o.id)) o];
      final pending = [for (final o in objs) if (!state.discovered.contains(o.id)) o];
      sb.writeln('- zbadane obiekty (odkrycia w notatniku graczy): ${examined.isEmpty ? 'żadne' : examined.map((o) => o.hasClue ? '${o.label} → „${o.clue}”' : o.label).join('; ')}');
      sb.writeln('- niezbadane: ${pending.isEmpty ? 'żadne' : pending.map((o) {
            final locked = o.isChained && !state.discovered.contains(o.requires);
            return locked ? '${o.label} (ZABLOKOWANY – odblokuje go zbadanie: ${stage.scene.objectById(o.requires)?.label ?? o.requires})' : o.label;
          }).join('; ')}');
      sb.writeln('- błędne odpowiedzi: ${state.attempts}${state.wrongAnswers.isEmpty ? '' : ' (ostatnie: ${state.wrongAnswers.map((w) => '„$w”').join(', ')})'}');
      sb.writeln('- podpowiedzi użyte: ${state.hintsUsed} z ${stage.hints.length}${state.hintsUsed > 0 ? ' (${stage.hints.take(state.hintsUsed).join(' | ')})' : ''}');
      sb.writeln('- czas w etapie: ${state.elapsed.inMinutes} min');
      sb.writeln();
    }
    sb.writeln('BIEŻĄCY ETAP (tajne dane – znasz je, ale nie zdradzasz):');
    sb.writeln(jsonEncode({
      'narrative': stage.narrative,
      'puzzle': stage.puzzle.toJson(),
      'solutionSummary': _solutionSummary(stage.puzzle),
      'hints': stage.hints,
      'objects': [
        for (final o in stage.scene.objects)
          {
            'id': o.id,
            'label': o.label,
            'description': o.description,
            'clue': o.clue,
            'requires': o.requires,
            'lockedText': o.lockedText,
          },
      ],
    }));
    return sb.toString();
  }

  static String _solutionSummary(Puzzle p) => switch (p) {
        SequenceOrderPuzzle x => 'kolejność: ${x.correctOrder.join(' → ')}',
        PinCodePuzzle x => 'kod: ${x.answer}',
        MultipleChoicePuzzle x =>
          'opcja: ${x.options.elementAtOrNull(x.correctIndex) ?? x.correctIndex}',
        TextAnswerPuzzle x => 'odpowiedź: ${x.acceptedAnswers.join(' / ')}',
        MatchingPuzzle x =>
          x.correctPairs.entries.map((e) => '${e.key} ↔ ${e.value}').join('; '),
        ToggleGridPuzzle x =>
          'stan: ${x.targetState.map((b) => b ? '1' : '0').join()}',
        DialCombinationPuzzle x => 'wartości: ${x.answer.join(', ')}',
        OpenExplanationPuzzle x => x.exampleSolution,
      };

  /// The user turn: recent transcript + the new event.
  static String user(List<GmMessage> history, String eventDescription) {
    final sb = StringBuffer();
    if (history.isNotEmpty) {
      sb.writeln('OSTATNIE ZDARZENIA (najstarsze u góry):');
      for (final m in history) {
        final who = switch (m.role) {
          'player' => 'GRACZ',
          'gm' => 'MISTRZ GRY',
          _ => 'ZDARZENIE',
        };
        sb.writeln('[$who] ${m.text}');
      }
      sb.writeln();
    }
    sb.writeln('NOWE ZDARZENIE:');
    sb.writeln(eventDescription);
    sb.writeln();
    sb.writeln('Zareaguj jako Mistrz Gry.');
    return sb.toString();
  }

  static String judgeSystem(int age) => '''
Jesteś sprawiedliwym sędzią w escape roomie dla dzieci (wiek ok. $age lat). Oceniasz, czy odpowiedź gracza na zagadkę otwartą spełnia rubrykę. Odpowiadasz JSON-em zgodnym ze schematem.
- Oceniaj LOGIKĘ, nie styl: akceptuj literówki, potoczny język, inne sformułowania, jeśli metoda jest kompletna i poprawna.
- Odrzuć, gdy brakuje kluczowego kroku z rubryki, gdy metoda nie daje pewności albo łamie ograniczenia zagadki.
- feedback: 1–3 zdania do gracza. Gdy poprawnie – pochwal i nazwij, co było kluczowe. Gdy błędnie – wskaż, czego brakuje lub co nie działa, BEZ podawania rozwiązania.''';

  static String judgeUser(OpenExplanationPuzzle p, String answer) => '''
ZAGADKA: ${p.prompt}

RUBRYKA (tajna): ${p.rubric}

PRZYKŁADOWE ROZWIĄZANIE (tajne): ${p.exampleSolution}

ODPOWIEDŹ GRACZA:
$answer''';
}
