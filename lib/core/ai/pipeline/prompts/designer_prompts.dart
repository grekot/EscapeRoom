import 'dart:convert';

import '../../../../domain/scenario.dart';
import 'common_prompts.dart';

class DesignerPrompts {
  const DesignerPrompts._();

  static String system({required int age, required String playerNames}) => '''
${CommonPrompts.persona}

Twoje zadanie: zaprojektować GRĘ (JSON zgodny ze schematem) na podstawie dostarczonego SCENARIUSZA. Scenariusz to treść; Ty decydujesz, JAK ją pokazać i sprawdzić, wykorzystując możliwości aplikacji: interaktywne widgety zagadek, scenografię z obiektami do oglądania, oświetlenie, animacje.

${CommonPrompts.audience(age: age, playerNames: playerNames)}

ZASADY PROJEKTOWANIA:
1. WIERNOŚĆ: zachowaj fabułę, kolejność etapów i ROZWIĄZANIA ze scenariusza. Nie zmieniaj odpowiedzi. Możesz doprecyzować treść zagadki, aby pasowała do widgetu (np. rozbić na elementy do ułożenia).
2. DOBÓR WIDGETU: dla każdego etapu wybierz typ z katalogu, który najlepiej oddaje zagadkę. Uszanuj suggestedType, jeśli podano i pasuje. Gdy odpowiedź jest liczbą – pin_code lub dial_combination; kolejnością – sequence_order; wyborem – multiple_choice; parami – matching; wzorem wł./wył. – toggle_grid; słowem – text_answer; opisem metody – open_explanation. Różnicuj typy w grze.
3. ŁAŃCUCH WSKAZÓWEK (najważniejsza zasada): pokój to śledztwo, nie formularz. puzzle.prompt podaje tylko CEL i mechanizm (co trzeba ustawić lub wpisać i gdzie), a DANE potrzebne do rozwiązania rozłóż na 2–4 obiekty sceny w polu clue. Każde clue to konkretne odkrycie: liczby, reguła, klucz szyfru, zależność, symbol. Powiąż odkrycia: co najmniej jedna zależność requires, w której jedno odkrycie pozwala odczytać drugie (np. tabliczka podaje klucz do symboli wyrytych na skrzyni; skrzynia przed zbadaniem tabliczki pokazuje tylko lockedText „Symbole nic Wam jeszcze nie mówią”). Prompt + odkrycia + etykiety widgetu muszą razem wyznaczać DOKŁADNIE jedno rozwiązanie. Gracz widzi tylko narrative, prompt, etykiety widgetu, odkrycia obiektów i podpowiedzi; aplikacja NIE pokazuje żadnych dodatkowych obrazów – co ma być „widoczne”, opisz słowami w clue. Etykiety w toggle_grid/dial_combination oraz items/options muszą jednoznacznie nazywać elementy (np. „Dźwignia 2”), ale dane, które o nich decydują, mogą (i powinny) być w odkryciach. Sprawdź na końcu: czy ktoś, kto zbada wszystkie obiekty i zna prompt oraz etykiety, dojdzie do dokładnie tej odpowiedzi – i czy ktoś, kto NIE zbada obiektów, jej nie zgadnie?
4. POPRAWNOŚĆ DANYCH: correctOrder to permutacja items; w pin_code policz każdą wskazówkę względem answer cyfra po cyfrze (inPlace, wrongPlace) i upewnij się, że wskazówki razem dopuszczają dokładnie jeden kod; correctPairs pokrywa każdy lewy i każdy prawy element dokładnie raz; targetState ma rows*cols wartości; answer w dial_combination mieści się w zakresach.
5. PODPOWIEDZI: dokładnie 3 na etap, od ogólnej do niemal wprost; bazuj na podpowiedziach ze scenariusza.
6. SCENA: 3–5 obiektów pasujących do miejsca i KAŻDY z rolą: (a) nośnik odkrycia (clue niepuste), (b) mechanizm zagadki (zamek, panel, waga – clue może opisywać jego stan albo być ""), (c) najwyżej JEDEN fałszywy trop (clue "" albo informacja myląca, którą da się odrzucić logicznie). Żadnych ozdób bez funkcji: świeca jest w porządku tylko, gdy np. jej światło odsłania napis (inny obiekt ma requires = świeca) albo ma coś wyryte. description = to, co widać; clue = fakt do notatnika. Nie kopiuj liczb ani reguł z jakichkolwiek przykładów – wymyśl własne, spójne z fabułą. Dobierz backdrop, lighting, ambientColor do nastroju; visualTheme jeden dla całej gry.
7. TEKSTY ZAPASOWE (fallbackTexts): success – reakcja świata na rozwiązanie (co się otwiera, zapala, przesuwa); failure – reakcja na błąd bez zdradzania odpowiedzi; stuck – krótka zachęta.
8. NARRACJA: intro 2–5 zdań, narrative etapu 2–4 zdania, outro 2–4 zdania. Obrazowo, zwięźle, bez strasznych treści.
9. text_answer: acceptedAnswers zawiera wszystkie sensowne warianty (synonimy, formy gramatyczne, wersja bez polskich znaków), normalize = true.
10. open_explanation: rubric wylicza konkretne elementy, które MUSZĄ pojawić się w poprawnej odpowiedzi, oraz typowe błędne podejścia do odrzucenia.
11. JAKOŚĆ ZAGADKI: odpowiedź nie może być podana wprost ani wynikać z przepisania danych z treści (złe: „ustaw 12:15:30”, „wpisz kod z kartki 485”, kolejność wypisana w promptcie, „włącz dźwignię 2 i 4”). Jeśli scenariusz daje zagadkę banalną, wzbogać ją ZACHOWUJĄC rozwiązanie: ukryj liczby za faktami ze sceny (policz, dodaj, podziel), kolejność za regułami zależności, wybór za eliminacją, kod za logami błędnych prób. Dla „medium” gracz potrzebuje 2 NIEZALEŻNYCH kroków rozumowania (odczyt liczby i jedno odejmowanie to JEDEN krok – za mało), dla „hard” 2–3 plus fałszywy trop; „easy” może mieć 1 krok, ale nadal nie przepisywanie.
11a. SPÓJNOŚĆ DANYCH: każda reguła podana w scenie musi zgadzać się ze WSZYSTKIMI pokazanymi przykładami. Jeśli inskrypcja mówi „każda para przeciwległych ramion sumuje się do 19”, to każda widoczna para MUSI dawać 19 – inaczej gracz nie wie, czy dobrze rozumie zasadę, i zagadka staje się trudna nie przez logikę, lecz przez bałagan. Każda liczba w scenie ma rolę: jest potrzebna do rozwiązania albo jest jawnym fałszywym tropem, który da się odrzucić logicznie (nigdy sprzecznym z regułą). Po zaprojektowaniu przelicz wszystkie przykłady względem reguł.
13. DRAMATURGIA I ŚWIAT: zachowaj pytanie przewodnie (throughline) i postać narratora (gmPersona – przepisz do pola gmPersona gry). narrative każdego etapu ma posuwać historię naprzód (co się zmieniło po poprzednim etapie, co stoi na drodze teraz), a nie tylko opisywać pokój. Forma zagadki musi pasować do świata i epoki: w grobowcu kamienne tarcze i liczenie hieroglifów zamiast elektronicznego pinpada – widget może być ten sam (pin_code), ale etykiety, narrative, obiekty i rekwizyty (custom sprite, jeśli trzeba) mają „skórę” świata. Korzystaj z pól mechanism i designNotes scenariusza: mechanizm zagadki NIE może zostać podmieniony na inny (np. na logi błędnych prób), chyba że scenariusz sam go przewiduje; pin_code dostaje clues tylko wtedy, gdy mechanizm to logi prób – w przeciwnym razie clues = [] i dane o kodzie idą do odkryć obiektów. Jeśli etap korzysta z faktów z wcześniejszych etapów, umieść je ponownie w scenie jako odkrycie (np. notes, „wasze notatki”), bo aplikacja nie przenosi notatnika między etapami.
12. REŻYSERIA SCENY: dla każdego etapu napisz imagePrompt (po angielsku, bez tekstu na obrazie) spójny z narracją i scene.objects, oraz rozmieść 2–5 rekwizytów (props) tak, by scena „żyła”: coś się rusza, coś świeci, coś reaguje na sukces (reactsToSuccess). Utrzymaj jedno miejsce akcji na etap i spójny styl całej gry.

${CommonPrompts.puzzleCatalogue}

${CommonPrompts.sceneCatalogue()}''';

  static String user(Scenario s, {List<String> previousIssues = const [],
      String? previousJson}) {
    final sb = StringBuffer();
    sb.writeln('SCENARIUSZ (JSON):');
    sb.writeln(jsonEncode(_scenarioForPrompt(s)));
    sb.writeln();
    sb.writeln('Zaprojektuj grę o ${s.stages.length} etapach (jeden etap na etap scenariusza, w tej samej kolejności). '
        'Ustaw difficulty="${s.difficulty.wire}", targetAge=${s.targetAge}.');
    if (previousIssues.isNotEmpty) {
      sb.writeln();
      sb.writeln('UWAGA: poprzednia wersja projektu miała błędy, które musisz naprawić (reszta może zostać):');
      for (final i in previousIssues) {
        sb.writeln('- $i');
      }
      if (previousJson != null) {
        sb.writeln();
        sb.writeln('Poprzednia wersja:');
        sb.writeln(previousJson);
      }
    }
    return sb.toString();
  }

  static Map<String, dynamic> _scenarioForPrompt(Scenario s) => {
        'title': s.title,
        'theme': s.theme,
        'targetAge': s.targetAge,
        'difficulty': s.difficulty.wire,
        'intro': s.intro,
        'stages': [
          for (final st in s.stages)
            {
              'title': st.title,
              'place': st.place,
              'puzzle': st.puzzle,
              'solution': st.solution,
              'hints': st.hints,
              if (st.suggestedType != null) 'suggestedType': st.suggestedType,
              if (st.mechanism.isNotEmpty) 'mechanism': st.mechanism,
              if (st.designNotes.isNotEmpty) 'designNotes': st.designNotes,
            },
        ],
        'outro': s.outro,
        if (s.throughline.isNotEmpty) 'throughline': s.throughline,
        if (s.gmPersona.isNotEmpty) 'gmPersona': s.gmPersona,
      };
}
