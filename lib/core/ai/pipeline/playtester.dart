import '../../../domain/catalog.dart';
import '../../../domain/game_spec.dart';
import '../../../domain/puzzle.dart';
import '../../../domain/puzzle_validator.dart';
import '../ai_provider.dart';

/// Solvability gate: a "test player" that sees only what the real player
/// sees (narrative, puzzle prompt, widget labels, object descriptions) must
/// solve every deterministic puzzle. Stages it cannot solve come back as
/// issues for the designer, e.g. a toggle puzzle whose levers carry no
/// information about which ones "point up".
class Playtester {
  Playtester(this.ai);

  final AiProvider ai;

  Future<List<String>> run(GameSpec spec,
      {void Function(String status)? onStatus, Difficulty difficulty = Difficulty.medium}) async {
    final issues = <String>[];
    for (var i = 0; i < spec.stages.length; i++) {
      final st = spec.stages[i];
      final p = st.puzzle;
      if (p is OpenExplanationPuzzle) continue; // judged by AI at play time anyway
      onStatus?.call('Testuję zagadkę ${i + 1}/${spec.stages.length} jako gracz…');
      Map<String, dynamic> j;
      try {
        j = await ai.completeJson(
          system: _system(spec.targetAge),
          user: _user(st),
          schema: _schema(p),
          maxTokens: 800,
          timeout: const Duration(seconds: 60),
        );
      } catch (_) {
        continue; // the gate must not block design on transient errors
      }
      final answer = _answer(p, j);
      final missing = (j['missing'] ?? '').toString().trim();
      final guess = j['confidence'] == 'guess';
      final effort = (j['effort'] ?? '').toString();
      final used = j['usedObjects'] is List ? (j['usedObjects'] as List).length : -1;
      final contradiction = (j['contradiction'] ?? '').toString().trim();
      final result = answer == null ? null : PuzzleValidator.check(p, answer);
      final correct = result is LocalResult && result.correct;
      final n = i + 1;
      if (!correct) {
        issues.add('Etap $n („${st.title}”): testowy gracz, widząc tylko treść zagadki, etykiety widgetu i opisy obiektów, NIE rozwiązał zagadki '
            '(odpowiedział: ${_describe(answer)}${missing.isNotEmpty ? '; brakuje mu: $missing' : ''}). '
            'Wszystkie dane potrzebne do jednoznacznego rozwiązania muszą być w puzzle.prompt, etykietach widgetu (labels/items/options/dials) lub opisach obiektów – gracz nie zobaczy nic więcej (żadnych obrazów „przez peryskop”). Uzupełnij dane albo zmień zagadkę.');
      } else if (guess && missing.isNotEmpty) {
        issues.add('Etap $n („${st.title}”): testowy gracz trafił odpowiedź tylko zgadując; brakuje mu: $missing. Dodaj te dane do puzzle.prompt lub etykiet.');
      } else if (effort == 'none' && difficulty != Difficulty.easy) {
        issues.add('Etap $n („${st.title}”): zagadka BANALNA – testowy gracz rozwiązał ją bez żadnego wnioskowania (odpowiedź jest podana wprost lub wynika z przepisania danych). Przerób ją tak, aby wymagała co najmniej ${difficulty == Difficulty.hard ? 'dwu–trzech' : 'jednego–dwu'} kroków rozumowania (eliminacja, liczenie, porównanie, reguła, szyfr z kluczem), przy zachowaniu tego samego rozwiązania.');
      } else if (contradiction.isNotEmpty) {
        issues.add('Etap $n („${st.title}”): dane w scenie są NIESPÓJNE – testowy gracz zauważył: $contradiction. Każda reguła podana w scenie musi zgadzać się ze WSZYSTKIMI pokazanymi przykładami (jeśli „każda para przeciwległych ramion sumuje się do 19”, to wszystkie pary muszą dawać 19); liczby, które nie pasują do reguły, mylą gracza zamiast go prowadzić. Popraw dane albo zawęź regułę.');
      } else if (effort == 'one' && difficulty == Difficulty.hard) {
        issues.add('Etap $n („${st.title}”): za łatwa dla trudności „hard” – jeden oczywisty krok. Dodaj drugi krok wnioskowania lub fałszywy trop.');
      } else if (effort == 'one' && difficulty == Difficulty.medium && _isArithmeticOnly(st.puzzle)) {
        issues.add('Etap $n („${st.title}”): za płytka dla trudności „medium” – całe rozwiązanie to odczyt jednej liczby i jedno działanie (np. 19 − 14). Dodaj drugi, niezależny krok wnioskowania (np. najpierw trzeba ustalić, KTÓRA para/liczba jest właściwa, na podstawie innego odkrycia), zachowując to samo rozwiązanie.');
      } else if (used == 0 && st.scene.hasClueChain && difficulty != Difficulty.easy) {
        issues.add('Etap $n („${st.title}”): testowy gracz rozwiązał zagadkę BEZ badania obiektów – odkrycia (clue) są zbędne, bo wszystkie dane stoją w puzzle.prompt lub etykietach widgetu. Przenieś dane do clue obiektów i zostaw w puzzle.prompt tylko cel oraz mechanizm.');
      }
    }
    return issues;
  }

  static String _system(int age) => '''
Jesteś testowym graczem: dziecko w wieku około $age lat grające z rodzicem w escape room na telefonie. Widzisz WYŁĄCZNIE poniższe informacje z ekranu – nic więcej (aplikacja nie pokazuje żadnych dodatkowych obrazów ani widoków). Nie znasz rozwiązania.
Rozwiąż zagadkę logicznie na podstawie tego, co widzisz. Odpowiedz JSON-em zgodnym ze schematem.
Jeśli ekran nie zawiera danych potrzebnych do jednoznacznej odpowiedzi, mimo to podaj najlepszą próbę, ustaw confidence="guess" i napisz w polu missing, jakiej konkretnie informacji brakuje na ekranie. Gdy dane wystarczają, confidence="sure" i missing="".
Oceń też wysiłek: effort="none" gdy odpowiedź jest podana wprost albo wystarczy przepisać liczby/słowa z treści; "one" gdy potrzebny jest jeden prosty krok (odczytać liczbę i wykonać jedno działanie, porównać, odczytać regułę); "several" gdy trzeba połączyć kilka niezależnych wskazówek, eliminować albo najpierw ustalić, których danych użyć.
Sprawdź spójność: jeśli jakaś reguła ze sceny nie zgadza się z pokazanymi przykładami albo dane sobie przeczą, opisz to w polu contradiction (inaczej "").''';

  static String _user(GameStage st) {
    final sb = StringBuffer();
    sb.writeln('NARRACJA: ${st.narrative}');
    sb.writeln();
    sb.writeln('ZAGADKA: ${st.puzzle.prompt}');
    sb.writeln();
    sb.writeln('WIDGET NA EKRANIE: ${_widget(st.puzzle)}');
    sb.writeln();
    sb.writeln('PRZEDMIOTY W SCENIE (można każdy zbadać; zbadany pokazuje swoje ODKRYCIE, które trafia do notatnika):');
    for (final o in st.scene.objects) {
      final sb2 = StringBuffer('- ${o.label}: ${o.description}');
      if (o.hasClue) sb2.write(' ODKRYCIE: „${o.clue}”');
      if (o.isChained) {
        final req = st.scene.objectById(o.requires)?.label ?? o.requires;
        sb2.write(' (odkrycie czytelne dopiero po zbadaniu: $req)');
      }
      sb.writeln(sb2);
    }
    return sb.toString();
  }

  static String _widget(Puzzle p) => switch (p) {
        SequenceOrderPuzzle x => 'lista do ułożenia w kolejność, elementy: ${x.items.join(' | ')}',
        PinCodePuzzle x => x.clues.isEmpty
            ? 'klawiatura numeryczna na ${x.codeLength} cyfr (bez listy prób – dane o kodzie są w scenie)'
            : 'klawiatura numeryczna na ${x.codeLength} cyfr; wskazówki: ${x.clues.map((c) => '${c.code}: ${c.text ?? c.describe()}').join('; ')}',
        MultipleChoicePuzzle x => 'karty do wyboru: ${[for (var i = 0; i < x.options.length; i++) '[$i] ${x.options[i]}'].join(' | ')}',
        TextAnswerPuzzle _ => 'pole tekstowe na odpowiedź',
        MatchingPuzzle x => 'dopasowanie par; lewa kolumna: ${x.leftItems.join(' | ')}; prawa kolumna: ${x.rightItems.join(' | ')}',
        ToggleGridPuzzle x => 'siatka ${x.rows}x${x.cols} przełączników wł./wył. (wszystkie na start wyłączone); etykiety w kolejności: ${x.labels.isEmpty ? 'brak etykiet' : x.labels.join(' | ')}',
        DialCombinationPuzzle x => 'pokrętła: ${x.dials.map((d) => '${d.label} (${d.min}–${d.max})').join(' | ')}',
        OpenExplanationPuzzle _ => 'pole na opis',
      };

  static Map<String, dynamic> _schema(Puzzle p) {
    final answer = switch (p) {
      SequenceOrderPuzzle _ => {'order': {'type': 'array', 'items': {'type': 'string'}, 'description': 'Elementy w Twojej kolejności (dokładnie te same napisy).'}},
      PinCodePuzzle _ => {'code': {'type': 'string', 'description': 'Kod – same cyfry.'}},
      MultipleChoicePuzzle _ => {'index': {'type': 'integer', 'description': 'Numer wybranej karty (od 0).'}},
      TextAnswerPuzzle _ => {'answer': {'type': 'string'}},
      MatchingPuzzle _ => {'pairs': {'type': 'array', 'items': {'type': 'array', 'items': {'type': 'string'}}, 'description': 'Pary [lewy, prawy].'}},
      ToggleGridPuzzle _ => {'state': {'type': 'array', 'items': {'type': 'boolean'}, 'description': 'Stan każdego przełącznika w kolejności etykiet.'}},
      DialCombinationPuzzle _ => {'values': {'type': 'array', 'items': {'type': 'integer'}, 'description': 'Wartość każdego pokrętła w kolejności.'}},
      OpenExplanationPuzzle _ => {'answer': {'type': 'string'}},
    };
    final props = <String, dynamic>{
      ...answer,
      'confidence': {'type': 'string', 'enum': ['sure', 'guess']},
      'missing': {'type': 'string', 'description': 'Czego brakuje na ekranie, albo "".'},
      'effort': {'type': 'string', 'enum': ['none', 'one', 'several'], 'description': 'Ile rozumowania wymagała zagadka.'},
      'usedObjects': {'type': 'array', 'items': {'type': 'string'}, 'description': 'Nazwy przedmiotów, których ODKRYCIA były niezbędne do odpowiedzi (pusta lista, gdy wystarczyła sama treść zagadki i widget).'},
      'contradiction': {'type': 'string', 'description': 'Jeśli dane na ekranie są ze sobą sprzeczne albo podana reguła NIE zgadza się z pokazanymi przykładami (np. „każda para sumuje się do 19”, a widoczne pary dają 12), opisz tę sprzeczność w jednym zdaniu. Inaczej "".'},
    };
    return {
      'type': 'object',
      'additionalProperties': false,
      'required': props.keys.toList(),
      'properties': props,
    };
  }

  static Object? _answer(Puzzle p, Map<String, dynamic> j) {
    try {
      switch (p) {
        case SequenceOrderPuzzle _:
          return (j['order'] as List).map((e) => e.toString()).toList();
        case PinCodePuzzle _:
          return j['code'].toString();
        case MultipleChoicePuzzle _:
          return (j['index'] as num).toInt();
        case TextAnswerPuzzle _:
          return j['answer'].toString();
        case MatchingPuzzle _:
          return {for (final pr in j['pairs'] as List) (pr as List)[0].toString(): pr[1].toString()};
        case ToggleGridPuzzle _:
          return (j['state'] as List).map((e) => e == true).toList();
        case DialCombinationPuzzle _:
          return (j['values'] as List).map((e) => (e as num).toInt()).toList();
        case OpenExplanationPuzzle _:
          return j['answer'].toString();
      }
    } catch (_) {
      return null;
    }
  }

  static String _describe(Object? a) => a == null ? 'brak odpowiedzi' : a.toString();

  /// Puzzles whose answer is typically "one number from the scene": a single
  /// arithmetic step is too little for them at medium difficulty.
  static bool _isArithmeticOnly(Puzzle p) =>
      p is MultipleChoicePuzzle || p is PinCodePuzzle || p is DialCombinationPuzzle || p is TextAnswerPuzzle;
}
