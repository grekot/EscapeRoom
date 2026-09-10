# Format scenariusza `escape-room-scenario/1`

Scenariusz to **treść** gry: fabuła, zagadki i rozwiązania w prozie. Nie zawiera decyzji o wyglądzie ani o widgetach – te podejmuje AI-projektant w aplikacji, tworząc z scenariusza grę (`escape-room-game/1`).

Ten sam model danych ma dwa zapisy: **Markdown** (dla ludzi i czatów AI) i **JSON** (kanoniczny, ścisły). Aplikacja importuje oba (plik `.md`/`.json` albo wklejony tekst).

## Markdown

```markdown
---
format: escape-room-scenario/1
title: Warsztat Wynalazcy
theme: opuszczone laboratorium genialnego konstruktora
language: pl
targetAge: 11
difficulty: medium        # easy | medium | hard
throughline: "Kto zamknął warsztat i dlaczego? – konstruktor sprawdza następcę"   # opcjonalnie: pytanie przewodnie + odpowiedź z finału
gmPersona: "głos konstruktora z nagrania na taśmie, ciepły, żartobliwy"           # opcjonalnie: kto mówi do graczy
---
# Wprowadzenie
2–5 zdań: gdzie są gracze, co się stało, jaki jest cel.

## Etap 1: Przebudzenie warsztatu
### Miejsce
Opis pomieszczenia, przedmioty, atmosfera – materiał na scenografię.
### Zagadka
Pełna treść zagadki, tak jak ma ją zobaczyć gracz (wszystkie potrzebne dane).
### Rozwiązanie
Jednoznaczna odpowiedź i krótkie uzasadnienie, dlaczego jest jedyna.
### Podpowiedzi
1. Ogólna.
2. Konkretniejsza.
3. Niemal wprost.
### Typ
sequence_order          # opcjonalnie; sugestia z katalogu typów
### Mechanizm
kolejność z reguł zależności            # opcjonalnie: pomysł zagadki w 3–8 słowach (do kontroli powtórzeń)
### Notatki projektowe
Kto zbudował zagadkę i po co; powiązania z innymi etapami; moment współpracy.   # opcjonalnie
### Sprawdzenie
Jakie inne odpowiedzi rozważono i dlaczego odpadają.                            # opcjonalnie

## Etap 2: ...

# Zakończenie
2–4 zdania po ucieczce.
```

Parser jest tolerancyjny: nagłówki etapów mogą mieć postać `## Etap 1: Tytuł`, `## Etap 1 – Tytuł`, `## Pokój 1. Tytuł`; podsekcje rozpoznawane są po początku słowa (`Miejsce`/`Scena`/`Opis`, `Zagadka`/`Zadanie`, `Rozwiązanie`/`Odpowiedź`, `Podpowiedzi`/`Wskazówki`, `Typ`). Gdy plik nie przypomina szablonu, aplikacja prosi AI o konwersję tekstu do JSON i pokazuje wynik do akceptacji.

## JSON

```json
{
  "format": "escape-room-scenario/1",
  "title": "Warsztat Wynalazcy",
  "theme": "opuszczone laboratorium genialnego konstruktora",
  "language": "pl",
  "targetAge": 11,
  "difficulty": "medium",
  "intro": "…",
  "stages": [
    {
      "title": "Przebudzenie warsztatu",
      "place": "…",
      "puzzle": "…",
      "solution": "…",
      "hints": ["…", "…", "…"],
      "suggestedType": "sequence_order",
      "mechanism": "kolejność z reguł zależności",
      "designNotes": "…",
      "uniquenessCheck": "…"
    }
  ],
  "outro": "…",
  "throughline": "…",
  "gmPersona": "…"
}
```

## Katalog typów (`suggestedType` / `### Typ`)

| Typ | Interakcja w aplikacji | Dobre do |
|---|---|---|
| `sequence_order` | przeciąganie elementów w kolejność | kable, kroki procedury, chronologia |
| `pin_code` | klawiatura numeryczna + logi błędnych prób | sejfy, zamki szyfrowe |
| `multiple_choice` | karty z opcjami | decyzja „które z…” |
| `text_answer` | pole tekstowe | hasła, zagadki słowne, szyfry |
| `matching` | dopasowanie dwu kolumn | etykiety ↔ pudełka, symbole ↔ znaczenia |
| `toggle_grid` | siatka przełączników | dźwignie, bezpieczniki, wzory świateł |
| `dial_combination` | pokrętła / suwaki | waga, zegar, ciśnienie, częstotliwość |
| `open_explanation` | opis słowny oceniany przez AI | algorytmy, strategie, dowody |

## Zasady dobrego scenariusza

1. Jedna zagadka na etap, jedno weryfikowalne rozwiązanie.
2. Wszystkie dane do rozwiązania są w treści zagadki, zapisane jak śledztwo: 2–4 źródła w pokoju i co każde zdradza, z zależnością między nimi.
2a. Historia ma pytanie przewodnie, autora zagadek w świecie gry (jego głos to `gmPersona`), rosnącą stawkę, zwrot akcji i finał, który odpowiada na pytanie. Zagadki wynikają ze świata (bez elektronicznych klawiatur w grobowcu) i mają różne mechanizmy; logi błędnych prób zamka najwyżej raz.
3. Rozwiązanie z uzasadnieniem jedyności (AI-projektant sprawdza logikę, np. czy wskazówki PIN wyznaczają dokładnie jeden kod).
4. Dokładnie 3 podpowiedzi o rosnącej konkretności.
5. Język i trudność dopasowane do wieku; bez treści strasznych dla dzieci.
6. Zróżnicowane typy zagadek w jednej grze.
