Napisz scenariusz gry typu escape room dla aplikacji „Pokój Zagadek AI”. Odpowiedz WYŁĄCZNIE jednym plikiem Markdown w dokładnie poniższym formacie (żadnego tekstu przed ani po nim).

PARAMETRY (zmień według potrzeb):
- Motyw: {MOTYW, np. „zatopiony okręt podwodny” / „biblioteka czarodzieja”}
- Wiek gracza: {WIEK, np. 11}
- Trudność: {easy | medium | hard}
- Liczba etapów: {3–6}
- Język: polski
- Nie powtarzaj mechanizmów z tych gier: {opcjonalnie lista, np. „logi błędnych prób zamka; szyfr Cezara”}

A. DRAMATURGIA – gra ma być przygodą, nie zestawem łamigłówek:
1. Pytanie przewodnie (`throughline`): co tu się stało, kto i po co zostawił zagadki? Wprowadzenie je stawia, każdy etap dodaje jeden fakt, finał na nie odpowiada, a zakończenie daje nagrodę emocjonalną (spotkanie, odkrycie, ratunek).
2. Autor zagadek w świecie gry: konkretna postać (latarnik, konstruktor, kapłanka, komputer stacji) z motywem. Jej głos to `gmPersona` – kto i jak mówi do graczy w czasie gry (1 zdanie). Ta postać spina wszystkie etapy.
3. Stawka rośnie z etapu na etap; w środku gry zwrot akcji zmieniający rozumienie sytuacji – bez przemocy i treści strasznych dla dzieci.
4. Przedmiot lub motyw przewodni wraca w kilku etapach i ma znaczenie w finale.
5. Co najmniej jedno odkrycie z wcześniejszego etapu jest potrzebne później; przy 4+ etapach finał to synteza faktów z całej gry. Zapisz powiązania w „### Notatki projektowe”.

B. ŚWIAT I MECHANIZM:
6. Każda zagadka istnieje w świecie gry z powodu (kto ją zbudował i po co – „### Notatki projektowe”). Forma pasuje do miejsca i epoki: w grobowcu kamienne tarcze i liczenie hieroglifów, nie elektroniczna klawiatura.
7. „### Mechanizm” nazywa pomysł zagadki w 3–8 słowach. Każdy etap ma INNY mechanizm i inny rodzaj myślenia (obserwacja i liczenie, dedukcja z reguł, szyfr i język, wyobraźnia przestrzenna, arytmetyka na faktach, strategia). Przykłady: szyfr podstawieniowy z kluczem w innym miejscu pokoju; liczenie elementów sceny i działanie na wynikach; kolejność z reguł zależności; kłamliwe etykiety; ważenie w mniejszej liczbie prób; plan ze współrzędnymi; lustro i napis wspak; zegar i cienie; rytm zapisany symbolami; wzór do kontynuowania; łamigłówka „kto, gdzie, kiedy”; legenda w jednym miejscu, znaki w drugim; akrostych; równania z ikon; kalendarz i daty; kierunki i kroki po planie; mieszanie składników; anagram; brakujący element zestawu; odczyt przyrządu i reguła; chronologia z fragmentów dziennika; labirynt opisany słowami; równoważenie zbiorów; strategia z gwarancją do opisania słowami.
8. Logi błędnych prób zamka („jedna cyfra dobra na złym miejscu”) to mechanizm zużyty – najwyżej raz, a wcale, jeśli jest na liście „nie powtarzaj”.

C. KAŻDY ETAP TO ŚLEDZTWO:
9. Treść zagadki („### Zagadka”) zawiera WSZYSTKIE dane potrzebne do rozwiązania, zapisane jak śledztwo: cel plus 2–4 źródła informacji w pokoju i co każde z nich zdradza (np. „na tabliczce klucz do symboli; na wieku skrzyni trzy symbole; w dzienniku reguła kolejności”), z zależnością – jedno odkrycie pozwala odczytać drugie. Aplikacja zamieni te źródła na obiekty sceny, które gracz bada, a treść pokaże tylko cel. Gracz nie widzi sekcji „Miejsce”, „Rozwiązanie” ani podpowiedzi.
10. Żadnych banałów: odpowiedź nie może być podana wprost ani wynikać z przepisania liczb czy słów. Trudność: easy = 1 wyraźny krok; medium = 2 niezależne kroki (odczyt liczby i jedno działanie to za mało); hard = 2–3 kroki plus fałszywy trop do odrzucenia. Każda reguła podana w scenie musi zgadzać się ze wszystkimi pokazanymi przykładami – niespójne dane mylą, zamiast utrudniać.
11. Krzywa trudności: etap 1 najprostszy, najtrudniejszy tuż przed finałem, finał spina historię.
12. W co najmniej jednym etapie zaplanuj współpracę dziecka i rodzica (jedno czyta legendę, drugie liczy przedmioty).

D. POPRAWNOŚĆ:
13. Każdy etap ma DOKŁADNIE jedną zagadkę z JEDNYM weryfikowalnym rozwiązaniem. W „### Sprawdzenie” wypisz inne rozważone odpowiedzi i dlaczego odpadają. Jeśli używasz wskazówek do kodu w stylu „jedna cyfra poprawna na złym miejscu”, policz każdą względem kodu cyfra po cyfrze.
14. „### Rozwiązanie” podaje odpowiedź i krótko uzasadnia jej jedyność. Dokładnie 3 podpowiedzi na etap: ogólna, konkretniejsza, niemal wprost.
15. Język i trudność dopasowane do wieku; bez wiedzy encyklopedycznej spoza treści.
16. „### Typ” – JEDNA wartość z listy (aplikacja ma dla każdej gotowy interaktywny widget); nie ten sam typ w dwu kolejnych etapach:
   - sequence_order – ułożenie elementów w kolejności (kable, kroki procedury, planety)
   - pin_code – kod cyfrowy; cyfry mogą wynikać z odkryć w pokoju (nie tylko z logów błędnych prób)
   - multiple_choice – wybór jednej z 3–5 opcji
   - text_answer – hasło, odpowiedź na zagadkę słowną, odszyfrowany szyfr
   - matching – dopasowanie par (etykiety do pudełek, symbole do znaczeń)
   - toggle_grid – ustawienie siatki przełączników/dźwigni (włącz/wyłącz)
   - dial_combination – ustawienie kilku pokręteł/suwaków na konkretne wartości
   - open_explanation – gracz opisuje słowami metodę (np. algorytm ważenia); ocenia AI

FORMAT (skopiuj strukturę 1:1, nagłówki muszą pozostać takie same):

---
format: escape-room-scenario/1
title: {Tytuł}
theme: {motyw w jednym zdaniu}
language: pl
targetAge: {wiek}
difficulty: {easy | medium | hard}
throughline: {pytanie przewodnie i jego odpowiedź z finału, 1–2 zdania}
gmPersona: {kto i jak mówi do graczy w świecie gry, 1 zdanie}
---
# Wprowadzenie
{2–5 zdań: gdzie są gracze, co się stało, jaki jest cel, jakie pytanie wisi w powietrzu}

## Etap 1: {Tytuł etapu}
### Miejsce
{opis pomieszczenia: przedmioty, światło, atmosfera – materiał na scenografię}
### Zagadka
{cel + 2–4 źródła informacji w pokoju i co każde zdradza, z zależnością między nimi}
### Rozwiązanie
{jednoznaczna odpowiedź + krótkie uzasadnienie}
### Podpowiedzi
1. {ogólna}
2. {konkretniejsza}
3. {niemal wprost}
### Typ
{jedna wartość z listy}
### Mechanizm
{pomysł zagadki w 3–8 słowach}
### Notatki projektowe
{kto zbudował zagadkę i po co; powiązanie z innymi etapami; moment współpracy}
### Sprawdzenie
{inne rozważone odpowiedzi i dlaczego odpadają}

## Etap 2: {Tytuł etapu}
(tak samo jak wyżej)

# Zakończenie
{2–4 zdania po ucieczce: odpowiedź na pytanie przewodnie i nagroda emocjonalna}
