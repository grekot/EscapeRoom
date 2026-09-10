import 'dart:math';

import 'game_spec.dart';
import 'puzzle.dart';
import 'scenario.dart';

/// Puzzle *mechanisms*: the idea behind a puzzle, independent of the widget
/// that displays it. Used to push the scenario writer towards variety and to
/// tell it what the player's library already contains.
class Mechanisms {
  const Mechanisms._();

  static const mastermind =
      'logi błędnych prób zamka (mastermind: cyfry na dobrym/złym miejscu)';

  /// Ideas the writer can pick from; deliberately broader than the widget list.
  static const catalogue = <String>[
    'szyfr podstawieniowy z kluczem znalezionym w innym miejscu pokoju',
    'liczenie elementów sceny (okna, stopnie, świece, kolumny) i działanie na wynikach',
    'kolejność wynikająca z reguł zależności („X przed Y, Z nigdy pierwszy”)',
    'kłamliwe etykiety lub świadkowie – jedno zdanie prawdziwe, reszta fałszywa',
    'ważenie lub porównywanie – wynik w mniejszej liczbie prób niż elementów',
    'plan pomieszczenia ze współrzędnymi – trasa albo punkt przecięcia dwu linii',
    'lustro lub odbicie – napis czytany wspak, odwrócony, w wodzie',
    'zegar i cienie – godzina odczytana z położenia wskazówek lub cienia',
    'rytm i dźwięk – sekwencja uderzeń zapisana symbolami',
    'wzór do kontynuowania – ciąg liczb, kształtów, kolorów z ukrytą regułą',
    'cechy wspólne – co spełnia wszystkie warunki naraz (przekrój zbiorów)',
    'łamigłówka „kto, gdzie, kiedy” – tabelka prawda/fałsz z kilku zdań',
    'legenda w jednym miejscu, znaki w drugim – symbol → znaczenie',
    'akrostych – hasło z pierwszych liter wersów, nazw lub imion',
    'równania z ikon – każdy symbol to liczba, którą trzeba wyznaczyć',
    'kalendarz i daty – dzień tygodnia albo różnica dni',
    'kierunki i kroki – „trzy kroki na północ, dwa na wschód” po planie',
    'mieszanie kolorów lub składników – przepis daje jednoznaczny wynik',
    'anagram słowa ukrytego w opisie sceny',
    'brakujący element zestawu (figura szachowa, karta, nuta, planeta)',
    'odczyt przyrządu (temperatura, ciśnienie, poziom) i reguła, co z nim zrobić',
    mastermind,
    'chronologia – kolejność zdarzeń złożona z fragmentów dziennika',
    'labirynt lub najkrótsza droga opisana słowami i skrzyżowaniami',
    'równoważenie – podział zbioru tak, by sumy lub wagi były równe',
    'strategia z gwarancją – algorytm do opisania własnymi słowami',
    'kod z dat i liczb wplecionych w historię miejsca (rok budowy, liczba załogi)',
    'dopasowanie śladów do sprawców – kto zostawił który ślad',
  ];

  /// Rough mechanism of one puzzle of an already designed game.
  static String ofPuzzle(Puzzle p) => switch (p) {
        PinCodePuzzle x => x.clues.isNotEmpty
            ? 'logi błędnych prób zamka (mastermind)'
            : 'kod cyfrowy złożony z odkryć w scenie',
        SequenceOrderPuzzle _ => 'kolejność z reguł zależności',
        MatchingPuzzle _ => 'dopasowanie par (legenda ↔ znaki)',
        ToggleGridPuzzle _ => 'wzór przełączników wynikający z reguły',
        DialCombinationPuzzle _ => 'wartości pokręteł z obliczeń na danych ze sceny',
        MultipleChoicePuzzle _ => 'wybór przez eliminację',
        TextAnswerPuzzle _ => 'hasło lub szyfr słowny',
        OpenExplanationPuzzle _ => 'opis strategii własnymi słowami',
      };

  static List<String> ofGame(GameSpec g) =>
      [for (final st in g.stages) ofPuzzle(st.puzzle)];

  static List<String> ofScenario(Scenario s) => [
        for (final st in s.stages)
          st.mechanism.trim().isNotEmpty
              ? st.mechanism.trim()
              : (st.suggestedType ?? 'zagadka'),
      ];

  /// One line per recent game for the writer's "do not repeat" list.
  static String describeGame(GameSpec g) =>
      '„${g.title}” – ${ofGame(g).join('; ')}';

  static String describeScenario(Scenario s) =>
      '„${s.title}” (${s.theme}) – ${ofScenario(s).join('; ')}';

  /// [count] catalogue ideas unlike anything in [avoid].
  static List<String> suggest(
      {required Iterable<String> avoid, int count = 3, Random? rng}) {
    final r = rng ?? Random();
    final used = avoid.map(_words).toList();
    final pool = [
      for (final m in catalogue)
        if (!used.any((u) => _similar(u, _words(m)))) m,
    ]..shuffle(r);
    return pool.take(count).toList();
  }

  static Set<String> _words(String s) => s
      .toLowerCase()
      .split(RegExp(r'[^a-ząćęłńóśźż]+'))
      .where((w) => w.length >= 5)
      .toSet();

  /// Two descriptions share at least two longer words → same idea.
  static bool _similar(Set<String> a, Set<String> b) =>
      a.intersection(b).length >= 2;
}
