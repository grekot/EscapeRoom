# Format gry `escape-room-game/1` (GameSpec)

GameSpec to **projekt grywalnej gry**: co pokazać, jak sprawdzić odpowiedzi, jakie teksty użyć bez AI. Powstaje z scenariusza (`escape-room-scenario/1`) w kroku projektowania wykonywanym przez AI z API. Aplikacja renderuje go w całości lokalnie; raz zaprojektowana gra działa offline (bez Mistrza Gry na żywo).

Kanoniczna definicja: `lib/core/ai/pipeline/schemas/game_spec_schema.dart` (JSON Schema wysyłany do AI) oraz `lib/domain/game_spec.dart` i `lib/domain/puzzle.dart` (modele). Przykład: `assets/gamespecs/warsztat_wynalazcy.json`.

```jsonc
{
  "format": "escape-room-game/1",
  "id": "…", "scenarioId": "…",
  "title": "…", "intro": "…", "outro": "…",
  "difficulty": "easy|medium|hard", "targetAge": 11,
  "visualTheme": "laboratory|castle|spaceship|cave|pyramid|ship|library|forest|bunker",
  "stages": [
    {
      "id": "safe", "title": "…",
      "narrative": "tekst wejścia do etapu",
      "scene": {
        "backdrop": "workshop|control_room|corridor|vault|…",   // Backdrops.all – tło proceduralne, gdy brak ilustracji
        "ambientColor": "#1e3a8a",
        "lighting": "dark|flicker|bright|red_alert",
        "imagePrompt": "Cramped engine room of an old lighthouse…",  // EN, dla ilustratora AI (Gemini); bez ludzi i tekstu
        "imagePath": "…/images/<gameId>/<stageId>.png",             // wypełnia aplikacja po wygenerowaniu
        "imageAsset": null,                                          // ilustracja dołączona do aplikacji (gry wbudowane)
        "objects": [
          { "id": "plaque", "label": "Tabliczka", "icon": "note", "description": "Mosiężna tabliczka nad drzwiami.",
            "clue": "Klucz: trójkąt = 4, koło = 2, kwadrat = 0.", "requires": "", "lockedText": "", "interactive": true, "x": 0.5, "y": 0.3 },
          { "id": "chest", "label": "Skrzynia", "icon": "box", "description": "Na wieku wyryto trzy symbole.",
            "clue": "Symbole: kwadrat, trójkąt, koło.", "requires": "plaque", "lockedText": "Symbole nic Wam jeszcze nie mówią.", "interactive": true }
        ],
        // ŁAŃCUCH WSKAZÓWEK: puzzle.prompt podaje tylko cel, a dane do rozwiązania siedzą w polach clue obiektów
        // (odkrycia trafiają do notatnika gracza). requires = id obiektu, który trzeba zbadać wcześniej; do tego czasu
        // zbliżenie pokazuje lockedText. Tapnięcie obiektu (chip lub element sceny) = zbliżenie „kamery” + karta z opisem
        // i odkryciem; interactive: true → dodatkowo komentuje Mistrz Gry (wywołanie AI). x, y (0–1) to opcjonalny hotspot,
        // gdy obiektu nie przedstawia żaden rekwizyt. Walidacja: requires wskazuje istniejący obiekt, bez cykli; dla
        // medium/hard każda scena ma ≥2 obiekty z clue, a pin_code może mieć clues=[] tylko wtedy.
        "props": [                                                    // animowane rekwizyty rysowane przez aplikację
          { "type": "lever", "x": 0.86, "y": 0.62, "size": 0.16, "objectId": "lever", "label": "", "reactsToSuccess": true }
        ]
      },
      "puzzle": { "type": "pin_code", … },                       // patrz niżej
      "hints": ["…", "…", "…"],
      "fallbackTexts": { "success": "…", "failure": "…", "stuck": "…" },
      "effectOnSuccess": "safe_open|door_slide|lights_on|gears_turn|sparkle|none"
    }
  ]
}
```

## Scena: ilustracja + rekwizyty

Scena to trzy warstwy renderowane w proporcji 16:9:

1. **Tło** – ilustracja wygenerowana przez Gemini (`imagePath`), dołączona do aplikacji (`imageAsset`) albo, gdy żadnej nie ma, tło proceduralne malowane przez aplikację (`BackdropPainter`, archetypy: maszynownia, korytarz, jaskinia, plener, drewniana izba – wybierane wg `backdrop`).
2. **Oświetlenie** – nakładka wg `lighting` (mrok, migotanie, alarm).
3. **Rekwizyty (`props`)** – animowane elementy rysowane przez aplikację (`PropPainter`): `lever`, `switch`, `pinpad`, `gauge`, `lamp`, `gear`, `steam`, `sparks`, `door`, `screen`, `pendulum`, `valve`, `candle`, `window`, `radar`, `chest`, `crystal`, `fan`. Pozycja `x`,`y` to środek w ułamkach 0..1, `size` to szerokość jako ułamek szerokości sceny. `reactsToSuccess` przełącza rekwizyt w stan aktywny po rozwiązaniu etapu (wajcha w górę, drzwi się rozsuwają, dioda na zielono, iskry gasną). `objectId` łączy rekwizyt z obiektem: dotknięcie rekwizytu to oglądanie obiektu. Wajcha, przełącznik, zawór, lampa i wentylator reagują też na dotknięcie (przełączają się lokalnie).

**Obiekty na obrazie.** Każdy obiekt musi być osiągalny z ilustracji: albo przedstawia go rekwizyt (`props[].objectId`, wtedy pod rekwizytem pojawia się podpis z nazwą obiektu), albo ma współrzędne `x`,`y` i aplikacja stawia tam znacznik z ikoną i nazwą. Rząd przycisków pod sceną jest legendą: dotknięcie przycisku podświetla element na obrazie i odwrotnie. Test `bundled games: every object is reachable…` pilnuje tego dla gier wbudowanych.

**Rekwizyt własny (`type: "custom"`).** Gdy w katalogu nie ma odpowiednika (robot, klatka z ptakiem, soczewka latarni…), projektant podaje `spritePrompt` (EN, jeden przedmiot) i `animation` (`bob`, `pulse`, `swing`, `spin`, `none`). `SceneArtist` generuje obraz 1:1 na jednolitym magentowym tle, `ChromaKey.cutOut` usuwa tło i przycina do obiektu (PNG z alfą, `spritePath` / `spriteAsset`), a `SpriteProp` animuje go ogólnym ruchem i podświetla po sukcesie. Bez klucza Gemini zamiast sprite'a rysowany jest świecący kryształ. Powiązania `objectId` są dodatkowo korygowane przez `PropBinding`: rekwizyt przypięty do obiektu musi go przedstawiać (notatka → `scroll`, fiolka → `potion`, zamek → `pinpad`), inaczej jego typ zostaje zamieniony.

Ilustracje generuje `SceneArtist` po zaprojektowaniu gry (Ustawienia → „Generuj ilustracje scen”, wymaga klucza Gemini, niezależnie od dostawcy tekstu). Do `imagePrompt` doklejany jest wspólny styl (`illustrationStyle`), pliki lądują w `<documents>/images/<gameId>/`. Brak obrazu nie jest błędem – gra działa na tle proceduralnym. W bibliotece menu gry ma „Namaluj scenografię”.

## Zagadki (`puzzle.type`)

| type | pola | odpowiedź gracza | sprawdzanie |
|---|---|---|---|
| `sequence_order` | `items[]`, `correctOrder[]` | `List<String>` | lokalnie |
| `pin_code` | `codeLength`, `answer`, `clues[{code,inPlace,wrongPlace,text}]` | `String` | lokalnie; walidator sprawdza, że wskazówki wyznaczają dokładnie jeden kod |
| `multiple_choice` | `options[]`, `correctIndex` | `int` | lokalnie |
| `text_answer` | `acceptedAnswers[]`, `normalize` | `String` | lokalnie (normalizacja: małe litery, bez ogonków i interpunkcji) |
| `matching` | `leftItems[]`, `rightItems[]`, `correctPairs[[l,r]]` | `Map<String,String>` | lokalnie |
| `toggle_grid` | `rows`, `cols`, `labels[]`, `targetState[bool]` | `List<bool>` | lokalnie |
| `dial_combination` | `dials[{label,min,max}]`, `answer[int]` | `List<int>` | lokalnie |
| `open_explanation` | `rubric`, `exampleSolution` | `String` | sędzia AI (`{correct, feedback}`) |

Wszystkie pola wspólne: `prompt` (tekst dla gracza). Nieznany `type` degraduje się do `text_answer`, jeśli da się znaleźć pole z odpowiedzią.

## Bramka jakości (banały i rozwiązywalność)

Dwie warstwy. Deterministyczna (`PuzzleValidator.qualityIssues`, `GameSpecValidator.quality`): odpowiedź podana wprost w treści (wartości pokręteł wypisane w kolejności, kod w treści, kolejność wypisana wprost, dosłowna odpowiedź tekstowa, za mało wskazówek PIN lub opcji). Modelowa (`Playtester`, poniżej): test gracza ocenia też `effort` (`none`/`one`/`several`); dla trudności innej niż `easy` zagadka rozwiązana bez wnioskowania wraca do projektanta jako „banalna”, a dla `hard` wymagane są co najmniej dwa kroki. Prompty autora i projektanta zawierają regułę „żadnych banałów” z przykładami złych zagadek i skalą trudności.

## Bramka rozwiązywalności (test gracza)

Po walidacji strukturalnej `Playtester` odgrywa gracza: dla każdej deterministycznej zagadki model dostaje WYŁĄCZNIE to, co widzi gracz (narracja, `puzzle.prompt`, etykiety widgetu, nazwy i opisy obiektów) i musi podać odpowiedź w schemacie właściwym dla typu zagadki plus `confidence` i `missing`. Odpowiedź sprawdza `PuzzleValidator`. Zagadki nierozwiązane (albo trafione tylko zgadywaniem z podanym brakiem danych) wracają do projektanta jako uwagi i gra jest projektowana ponownie z tymi uwagami (jedna runda). Powód: projektant potrafił zbudować zagadkę „włączcie dźwignie skierowane w górę” z etykietami „Dźwignia 1–4”, czyli bez danych, a Mistrz Gry obiecywał wtedy widok, którego aplikacja nie pokazuje. Prompt Mistrza Gry zakazuje obiecywania obrazów i każe uzupełniać brakujące fakty ze sceny słowami.

## Walidacja (Dart, przed zapisem)

`GameSpecValidator.validate` + `PuzzleValidator.validate` zwracają listę problemów po polsku; przy niepustej liście projektant AI otrzymuje ją i ponawia generowanie (jedna próba). Sprawdzane m.in.: 2–8 etapów, dokładnie 3 podpowiedzi, 1–8 obiektów w scenie, permutacja w `sequence_order`, spójność i jednoznaczność wskazówek PIN, zakresy pokręteł, kompletność par.

## Mistrz Gry na żywo

Podczas gry aplikacja wysyła do AI zdarzenia (`stageEntered`, `wrongAnswer`, `correctAnswer`, `hintRequested`, `objectInspected`, `freeChat`) z GameSpec jako kontekstem i otrzymuje `{narration, mood, offerHint}`. Poprawność odpowiedzi rozstrzyga aplikacja; AI tylko narruje. Gdy AI jest niedostępne lub wyłączone, używane są `fallbackTexts` i `objects[].description`.

## Mistrz Gry na żywo

`gmPersona` (pole gry, przenoszone ze scenariusza) mówi, kim jest narrator w świecie gry. Przy każdym zdarzeniu aplikacja przekazuje GM-owi **stan śledztwa** etapu: zbadane obiekty z odkryciami, niezbadane i zablokowane, liczba błędnych prób z ostatnimi odpowiedziami, użyte podpowiedzi, czas. GM stosuje drabinę naprowadzania (pytanie → wskazanie obiektu → łączenie odkryć → niemal wprost), diagnozuje błąd rozumowania po złej odpowiedzi, potwierdza uzasadnione wnioski częściowe i po sukcesie tłumaczy, dlaczego odpowiedź wynikała z odkryć. Odpowiedź GM zawiera `focusObjectId` – obiekt, który aplikacja podświetla na scenie. Po przerwie dłuższej niż 20 minut GM streszcza, co gracze już wiedzą.
