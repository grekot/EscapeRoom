# Pokój Zagadek AI

Aplikacja Android (Flutter), w której AI tworzy i prowadzi wieloetapowe escape roomy dla dzieci i rodzin. Inspiracja: rozgrywka „Warsztat Wynalazcy” (przewody → sejf z PIN-em → pudełka z kłamliwymi etykietami → waga i 9 kół), która jest wbudowana w aplikację i działa bez klucza API.

## Jak to działa

```
 SCENARIUSZ (.md / .json)   ──AI──►   GRA (GameSpec JSON)   ──AI──►   ROZGRYWKA
 fabuła, zagadki,                    etapy → widgety zagadek,          Mistrz Gry reaguje
 rozwiązania w prozie                scenografia, obiekty,             na ruchy gracza;
                                     podpowiedzi, teksty zapasowe      odpowiedzi sprawdza app
```

1. **Scenariusz** (`escape-room-scenario/1`) – treść gry. Źródła: plik MD/JSON (np. napisany w ChatGPT/Claude/Gemini według instrukcji z aplikacji), krótki prompt użytkownika albo losowanie. Format: [assets/docs/SCENARIO_FORMAT.md](assets/docs/SCENARIO_FORMAT.md), gotowy prompt dla zewnętrznego AI: [assets/docs/AI_AUTHORING_PROMPT.md](assets/docs/AI_AUTHORING_PROMPT.md).
2. **Projekt gry** (`escape-room-game/1`) – AI-projektant mapuje scenariusz na katalog możliwości aplikacji: 8 typów interaktywnych zagadek, 26 rodzajów pomieszczeń, 50 ikon obiektów, oświetlenie, animacje sukcesu. Wynik jest walidowany logicznie w Darcie (np. czy wskazówki PIN wyznaczają dokładnie jeden kod) i w razie błędów poprawiany jedną dodatkową rundą. Format: [docs/GAMESPEC_FORMAT.md](docs/GAMESPEC_FORMAT.md).
3. **Scenografia** – każda scena to ilustracja 16:9 (generowana przez Gemini na podstawie promptu reżysera AI, a bez klucza Gemini malowana proceduralnie przez aplikację), oświetlenie oraz animowane rekwizyty rysowane przez aplikację: wajcha, przełącznik, pinpad, wskaźnik, lampa, koła zębate, para, iskry, drzwi, ekran, wahadło, zawór, świeca, okno z burzą, radar, skrzynia, kryształ, wentylator. Rekwizyty reagują na rozwiązanie etapu (drzwi się rozsuwają, iskry gasną) i na dotknięcie. Tapnięcie obiektu (na scenie albo na chipie pod nią) to zbliżenie „kamery” na ten obiekt z kartą opisu i jego **odkryciem**, a Mistrz Gry komentuje go na żywo; „Wróć” przywraca pełny kadr. Pokój jest śledztwem: treść zagadki podaje tylko cel, dane są rozłożone na obiekty (łańcuch wskazówek – np. tabliczka daje klucz, którym dopiero czyta się symbole na skrzyni), a zebrane odkrycia lądują w notatniku pod sceną. Autor scenariusza dostaje wymagania dramaturgiczne (pytanie przewodnie, postać autora zagadek, zwrot akcji, finał-synteza, mechanizmy wynikające ze świata) oraz listę mechanizmów z gier już obecnych w bibliotece, których ma nie powtarzać; Mistrz Gry zna stan śledztwa (co zbadano, ile prób, jakie podpowiedzi) i naprowadza stopniowo, diagnozując błędy zamiast ogólnych zachęt. Tła kolejnych etapów przechodzą w siebie płynnie. Gdy w katalogu brakuje przedmiotu, projektant zamawia rekwizyt własny: Gemini rysuje go na magentowym tle, aplikacja wycina tło i animuje sprite. Przykład: wbudowana gra „Latarnia w sztormie”.
4. **Mistrz Gry na żywo** – podczas gry AI reaguje na zdarzenia (zła odpowiedź, prośba o podpowiedź, oglądanie obiektu, rozmowa), nie zdradzając rozwiązań. Poprawność odpowiedzi rozstrzyga aplikacja lokalnie; zagadki opisowe ocenia sędzia AI (bez klucza – rodzic). Bez sieci używane są teksty zapasowe z projektu gry.

Dostawcy AI: **Anthropic (Claude)** i **Google (Gemini)** – wybór i klucz w Ustawieniach (klucz w Android Keystore). Aplikacja jest przeznaczona do użytku prywatnego (klucz na urządzeniu).

## Struktura

```
lib/domain/           modele (Scenario, GameSpec, Puzzle, GameSave), parser MD, walidatory
lib/core/ai/          providery HTTP (Anthropic, Gemini), pipeline: writer, importer, designer, game master, judge
lib/core/ai/pipeline/schemas   JSON Schema (wspólny podzbiór dla obu dostawców)
lib/core/storage/     ustawienia, klucze, pliki JSON w katalogu aplikacji
lib/features/         library, create (import / prompt / losowo), game (scena, widgety, GM), settings
assets/scenarios/     wbudowany scenariusz MD;  assets/gamespecs/  wbudowana gra JSON
```

## Budowanie

Wymagania: Flutter 3.41+, JDK 17, Android SDK z platformą 37 (Gradle pobiera ją sam).

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Na Windows, gdy Gradle zgłasza `Unable to establish loopback connection` (JDK 17 + katalog TEMP ze skróconą nazwą 8.3), uruchamiaj build z przekierowanym TEMP:

```bash
mkdir -p /c/TMP/jtmp && TEMP='C:\TMP\jtmp' TMP='C:\TMP\jtmp' flutter build apk --debug
```

Testy na żywo z prawdziwym API Gemini (pomijane bez klucza; klucz tylko w zmiennej środowiskowej):

```bash
GEMINI_API_KEY=... flutter test --tags live
```

Z `ILLUSTRATE_BUILTINS=1` (i opcjonalnie `ILLUSTRATE_ONLY=<id gry>`) test dodatkowo przemalowuje wbudowane gry i zapisuje PNG do `assets/images/`.

Instalacja na telefonie: `flutter run` albo `adb install build/app/outputs/flutter-apk/app-debug.apk`.

## Testowanie na Windows

Projekt ma też platformę Windows (okno 430×900, jak telefon). Wszystkie wtyczki działają na desktopie; udostępnianie i odbieranie plików z innych aplikacji to funkcje tylko Androida (na Windows przycisk „Udostępnij” kopiuje treść do schowka).

```bash
flutter run -d windows
```

`tool/win_ui.ps1` steruje uruchomionym oknem `escape_room.exe` z PowerShella (kliknięcia, przeciąganie, kółko, zrzuty przez PrintWindow), np.:

```bash
powershell -ExecutionPolicy Bypass -File tool/win_ui.ps1 -Actions "top;mclick:350,299;sleep:3;shot:game"
```

Zrzuty trafiają do `C:\TMP\jtmp\<nazwa>.png`. Uwaga: kliknięcia i kółko idą przez prawdziwy kursor (`mouse_event`), okno musi być na wierzchu (`top`); Flutter ignoruje syntetyczne komunikaty `PostMessage`.

## Budowanie i wydania (GitHub Actions)

Repozytorium: `github.com/grekot/EscapeRoom`.

- **CI** (`.github/workflows/ci.yml`): każdy push do `main` uruchamia `flutter analyze`, testy offline i buduje APK (artefakt `app-release-apk`).
- **Release** (`.github/workflows/release.yml`): tag `vX.Y.Z` (albo ręczne uruchomienie z numerem wersji) buduje podpisany APK i paczkę Windows i publikuje je jako GitHub Release z automatycznymi notatkami. Wersja z tagu trafia do aplikacji przez `--dart-define=APP_VERSION`.
- Podpisywanie: keystore i hasła są w sekretach repozytorium (`KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`); lokalnie ten sam keystore wskazuje `android/key.properties` (poza gitem). Bez sekretów build używa klucza debug.

Nowe wydanie:

```bash
git tag v1.1.0 && git push origin v1.1.0
```

## Aktualizacje w aplikacji

Przy otwarciu biblioteki aplikacja pyta GitHub o najnowsze wydanie (`releases/latest`). Gdy jest nowsze niż uruchomiona wersja, pokazuje baner; na Androidzie pobiera APK do pamięci podręcznej i uruchamia systemowy instalator (pierwszy raz Android poprosi o zgodę na instalowanie z tej aplikacji), na Windows otwiera stronę wydania. Repozytorium i automatyczne sprawdzanie ustawia się w Ustawieniach.

## Repozytorium scenariuszy

Zakładka „Scenariusze” pokazuje pliki `.md` / `.json` z publicznego repozytorium (domyślnie `grekot/EscapeRoomScenario`): z katalogu głównego oraz z folderu `scenarios/` (lub `scenariusze/`). Pliki README/LICENSE/FORMAT są pomijane. „Pobierz” importuje scenariusz tak samo jak plik lokalny (format `escape-room-scenario/1`, w razie potrzeby konwersja przez AI). Repozytorium można zmienić w Ustawieniach.
