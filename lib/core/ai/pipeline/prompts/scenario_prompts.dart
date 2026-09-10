import '../../../../domain/catalog.dart';
import '../../../../domain/mechanisms.dart';
import 'common_prompts.dart';

class ScenarioPrompts {
  const ScenarioPrompts._();

  static String writerSystem({required int age, required String playerNames}) =>
      '''
${CommonPrompts.persona}

Twoje zadanie: napisać SCENARIUSZ escape roomu w formacie JSON zgodnym ze schematem. Scenariusz to treść: historia, zagadki, rozwiązania i podpowiedzi w prozie. Ekrany zaprojektuje później osobny projektant, a grę poprowadzi Mistrz Gry – piszesz dla nich obu.

${CommonPrompts.audience(age: age, playerNames: playerNames)}

A. DRAMATURGIA – gra ma być przygodą, nie zestawem łamigłówek:
1. Pytanie przewodnie (pole throughline): co tu się stało, kto i po co zostawił zagadki? Intro je stawia, każdy etap dodaje jeden fakt, finał na nie odpowiada. Outro daje nagrodę emocjonalną (spotkanie, odkrycie, ratunek), nie tylko „drzwi się otwierają”.
2. Autor zagadek w świecie gry: konkretna postać (latarnik, konstruktor, kapłanka, komputer stacji) z motywem – coś zabezpieczyła, ostrzega, sprawdza następcę, prosi o pomoc. Jej głos to gmPersona: kto i jak mówi do graczy (1 zdanie). Ta postać spina wszystkie etapy.
3. Stawka rośnie: każdy etap podnosi napięcie (sztorm się wzmaga, tlen się kończy, zegar cofa czas). W środku gry zwrot akcji zmieniający rozumienie sytuacji (pomocnik okazuje się autorem pułapek, cel jest inny, niż sądzono) – bez treści strasznych.
4. Przedmiot lub motyw przewodni wraca w kilku etapach i ma znaczenie w finale.
5. Powiązania między etapami: co najmniej jedno odkrycie z wcześniejszego etapu jest potrzebne później (np. imię z etapu 1 to klucz szyfru w etapie 3). Przy 4+ etapach finał to synteza łącząca fakty z całej gry. Zapisz powiązania w designNotes.

B. ŚWIAT I MECHANIZM:
6. Każda zagadka istnieje w świecie gry z powodu (kto ją zbudował, po co) – zapisz to w designNotes. Forma pasuje do miejsca i epoki: w grobowcu kamienne tarcze i liczenie hieroglifów, w stacji kosmicznej panel diagnostyczny; ŻADNYCH elektronicznych klawiatur w starożytności ani pergaminów na orbicie.
7. Pole mechanism: nazwij pomysł zagadki w 3–8 słowach. W jednej grze każdy etap ma INNY mechanizm i inny rodzaj myślenia (obserwacja i liczenie, dedukcja z reguł, szyfr i język, wyobraźnia przestrzenna, arytmetyka na faktach, strategia). Inspiracje – wybieraj różne, dopasowane do świata:
${Mechanisms.catalogue.map((m) => '   - $m').join('\n')}
8. Logi błędnych prób zamka (mastermind: „jedna cyfra dobra na złym miejscu”) to mechanizm ZUŻYTY – używaj go najwyżej raz na cztery gry i NIGDY, gdy pojawia się na liście „NIE POWTARZAJ” w treści zadania. To samo dotyczy każdego innego mechanizmu z tej listy: wybierz inny pomysł, nawet jeśli tamten pasuje do motywu.

C. KAŻDY ETAP TO ŚLEDZTWO:
9. Pole puzzle zawiera WSZYSTKIE dane potrzebne do rozwiązania, zapisane jak śledztwo: cel („ustawcie…”, „wpiszcie…”) plus 2–4 źródła informacji w pokoju i co każde z nich zdradza (np. „na mosiężnej tabliczce klucz do symboli; na wieku skrzyni trzy symbole; w dzienniku reguła kolejności”), z zależnością – jedno odkrycie pozwala odczytać drugie. Projektant zamieni źródła na obiekty sceny, które gracz bada; gracz nie zobaczy pól place, solution ani hints.
10. ŻADNYCH BANAŁÓW: odpowiedź nie może być podana wprost ani wynikać z przepisania liczb i słów („ustaw 12:15”, „wpisz kod z kartki 485”). Każda zagadka wymaga wnioskowania. Trudność: easy = 1 wyraźny krok; medium = 2 NIEZALEŻNE kroki (odczyt jednej liczby i jedno działanie, np. 19 − 14, to tylko jeden krok – za mało); hard = 2–3 kroki plus fałszywy trop, który da się odrzucić logicznie.
10a. SPÓJNOŚĆ ŚWIATA: każda reguła, którą podajesz, musi zgadzać się ze wszystkimi przykładami w scenie (gdy „każda para sumuje się do 19”, wszystkie pary dają 19). Fałszywy trop ma być odrzucalny logicznie, nie sprzeczny z regułą. Sprawdź to w uniquenessCheck.
11. Krzywa trudności: etap 1 to rozgrzewka (najprostszy), najtrudniejszy etap tuż przed finałem, finał satysfakcjonujący i spinający historię.
12. Gra we dwoje (dziecko z rodzicem): w co najmniej jednym etapie zaplanuj współpracę – jedna osoba czyta regułę lub legendę, druga sprawdza przedmioty i liczy; zapisz to w designNotes.

D. POPRAWNOŚĆ:
13. Każdy etap ma DOKŁADNIE jedną zagadkę z JEDNYM weryfikowalnym rozwiązaniem. W polu uniquenessCheck wypisz, jakie inne odpowiedzi rozważano i dlaczego odpadają. Jeśli mimo wszystko używasz wskazówek do kodu w stylu „jedna cyfra poprawna na złym miejscu”, policz każdą względem kodu cyfra po cyfrze.
14. Pole solution podaje odpowiedź i krótko uzasadnia jej jedyność. Dokładnie 3 podpowiedzi na etap: ogólna → konkretniejsza → niemal wprost.
15. Bez wiedzy encyklopedycznej spoza treści; wszystko wynika z podanych danych i logiki. Słownictwo i długość zdań dla wieku gracza.
16. suggestedType: typ interakcji z katalogu poniżej, który najlepiej odda mechanizm (albo ""). Nie używaj tego samego typu w dwu kolejnych etapach. Nie kopiuj liczb ani reguł z jakichkolwiek przykładów – wymyśl własne, spójne z fabułą.

${CommonPrompts.puzzleCatalogue}''';

  static String writerUser({
    required String theme,
    required int age,
    required Difficulty difficulty,
    required int stages,
    String? userPrompt,
    List<String> seedObjects = const [],
    String? twist,
    List<String> avoid = const [],
    List<String> suggestedMechanisms = const [],
  }) {
    final sb = StringBuffer();
    sb.writeln('Napisz scenariusz według parametrów:');
    sb.writeln('- Motyw: $theme');
    sb.writeln('- Wiek gracza: $age');
    sb.writeln('- Trudność: ${difficulty.wire} (${difficulty.label})');
    sb.writeln('- Liczba etapów: $stages');
    sb.writeln('- Język: polski (language = "pl")');
    if (seedObjects.isNotEmpty) {
      sb.writeln('- Wpleć w historię te przedmioty: ${seedObjects.join(', ')}');
    }
    if (twist != null && twist.isNotEmpty) {
      sb.writeln('- Dodatkowy element: $twist');
    }
    if (userPrompt != null && userPrompt.trim().isNotEmpty) {
      sb.writeln();
      sb.writeln('Życzenia gracza (najważniejsze, nadrzędne wobec motywu):');
      sb.writeln(userPrompt.trim());
    }
    if (avoid.isNotEmpty) {
      sb.writeln();
      sb.writeln('NIE POWTARZAJ – gracz ma już w bibliotece te gry (tytuł – mechanizmy zagadek). Nie używaj żadnego z tych mechanizmów ani podobnych i nie powielaj ich motywów fabularnych:');
      for (final a in avoid) {
        sb.writeln('- $a');
      }
    }
    if (suggestedMechanisms.isNotEmpty) {
      sb.writeln();
      sb.writeln('ŚWIEŻE POMYSŁY (wylosowane przez aplikację; użyj co najmniej dwu, jeśli da się je osadzić w motywie):');
      for (final m in suggestedMechanisms) {
        sb.writeln('- $m');
      }
    }
    return sb.toString();
  }

  static const importerSystem = '''
Otrzymasz tekst opisujący scenariusz escape roomu (może być w luźnym Markdownie, notatkach lub prozie). Przekształć go WIERNIE do formatu JSON zgodnego ze schematem.

ZASADY:
- Nie wymyślaj nowych zagadek ani nie zmieniaj rozwiązań. Zachowaj treść i kolejność etapów.
- Jeśli czegoś brakuje (np. podpowiedzi), uzupełnij minimalnie i sensownie na podstawie treści: hints ma mieć dokładnie 3 pozycje, intro/outro mogą być krótkie streszczenia z tekstu.
- puzzle = pełna treść zagadki dla gracza; solution = odpowiedź z uzasadnieniem; place = opis miejsca (jeśli brak, jedno zdanie wywnioskowane z treści).
- suggestedType: dobierz z katalogu najlepiej pasujący typ albo "".
- mechanism (3–8 słów o pomyśle zagadki), designNotes, uniquenessCheck, throughline, gmPersona: wypełnij krótko na podstawie tekstu, a gdy tekst nic o tym nie mówi – "".
- Jeśli nie podano wieku, przyjmij 10; jeśli nie podano trudności, "medium"; language "pl" (albo język tekstu).

${CommonPrompts.puzzleCatalogue}''';

  /// Themes for the random mode.
  static const randomThemes = <String>[
    'zatopiony okręt podwodny pełen dziwnych maszyn',
    'pracownia alchemika w wieży zamku',
    'opuszczona stacja kosmiczna na orbicie Marsa',
    'grobowiec faraona z pułapkami',
    'tajna baza szpiegów pod lodowcem',
    'pociąg-widmo, który nie chce się zatrzymać',
    'muzeum nocą, gdy eksponaty ożywają',
    'fabryka czekolady z zepsutą maszyną',
    'latarnia morska podczas sztormu',
    'biblioteka czarodzieja, w której książki gadają',
    'cyrk wędrowny z zagadkowym iluzjonistą',
    'obserwatorium astronomiczne na szczycie góry',
    'statek piracki uwięziony w mgle',
    'podziemne miasto krasnoludów',
    'laboratorium szalonego naukowca w burzową noc',
    'zamrożona jaskinia lodowa z śpiącym smokiem',
    'ogród botaniczny z roślinami, które liczą',
    'kolonia na Księżycu z awarią tlenu',
    'sklep z zabawkami, które same się przestawiają',
    'kopalnia złota Dzikiego Zachodu',
    'zaczarowana kuchnia olbrzyma',
    'dworzec z zegarem, który cofa czas',
    'stary kinoteatr z filmem, który nie ma końca',
    'pracownia zegarmistrza pełna mechanicznych ptaków',
  ];

  static const randomObjects = <String>[
    'zardzewiały klucz francuski',
    'mapa z brakującym fragmentem',
    'pozytywka grająca tylko trzy nuty',
    'klatka z mechaniczną papugą',
    'luneta z porysowaną soczewką',
    'pęk kolorowych bezpieczników',
    'stary telefon z tarczą',
    'słoik ze świecącymi kryształami',
    'zegar z trzema wskazówkami',
    'waga szalkowa',
    'kompas wskazujący na zachód',
    'lampa naftowa bez knota',
    'skrzynia z pięcioma zamkami',
    'globus z zaznaczonymi punktami',
    'dziennik z wyrwanymi stronami',
    'termos z gorącą herbatą',
    'szachownica bez jednej figury',
    'lustro, które pokazuje litery odwrotnie',
    'wiadro z farbą w trzech kolorach',
    'peryskop',
  ];

  static const randomTwists = <String>[
    'jeden z etapów wymaga pracy zespołowej dwu osób',
    'w tle słychać odliczanie, ale nikt nie wie, do czego',
    'pomocnik-robot udziela rad, ale jedna z nich jest fałszywa i trzeba to wykryć',
    'każde rozwiązanie odsłania literę hasła użytego w finale',
    'w pokoju jest kot, który reaguje na poprawne odpowiedzi',
    'konstruktor pokoju zostawił żartobliwe komentarze przy każdej zagadce',
    '',
    '',
  ];
}
