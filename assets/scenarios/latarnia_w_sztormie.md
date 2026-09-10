---
format: escape-room-scenario/1
title: Latarnia w sztormie
theme: stara latarnia morska odcięta sztormem, z zepsutym generatorem i statkiem czekającym na światło
language: pl
targetAge: 10
difficulty: medium
---
# Wprowadzenie
Wiatr wyje, a fale walą o skały. Schroniliście się w starej latarni morskiej, ale ciężkie drzwi zatrzasnęły się za Wami i zamek zablokował się od soli i rdzy. Na morzu miga w ciemności statek – bez światła latarni rozbije się o rafę. Musicie przywrócić prąd, nadać wezwanie przez radio, rozpalić wielką lampę i odblokować drzwi, zanim sztorm wygra.

## Etap 1: Maszynownia bez prądu
### Miejsce
Ciasna maszynownia u podstawy wieży. Wielki generator milczy, z pękniętej rury syczy para, a z uszkodzonego kabla strzelają iskry. Na ścianie skrzynka z sześcioma bezpiecznikami w dwu rzędach po trzy (górny rząd: A, B, C; dolny: D, E, F) oraz wielka wajcha główna. Wskaźnik ciśnienia drga w czerwonym polu.
### Zagadka
Na skrzynce bezpieczników latarnik napisał kredą: „Prąd do lampy płynie przez trzy bezpieczniki tworzące literę L: ten w prawym dolnym rogu, ten bezpośrednio nad nim i ten bezpośrednio na lewo od niego. Każdy inny włączony bezpiecznik wysadza generator.” Skrzynka ma dwa rzędy po trzy bezpieczniki: górny A, B, C i dolny D, E, F. Które bezpieczniki włączacie?
### Rozwiązanie
Włączone tylko C, E i F. Prawy dolny róg to F; bezpośrednio nad nim jest C; bezpośrednio na lewo od F jest E. Pozostałe (A, B, D) wyłączone.
### Podpowiedzi
1. Narysujcie skrzynkę: dwa rzędy po trzy pola. Gdzie jest prawy dolny róg?
2. Litera L to trzy pola: róg, jedno w górę i jedno w bok od rogu.
3. Prawy dolny to F, nad nim C, na lewo E. Resztę zostawcie wyłączoną.
### Typ
toggle_grid

## Etap 2: Radiostacja
### Miejsce
Drewniana izba radiowa w połowie wieży. Trzy okrągłe okna zalewa deszcz, co chwila rozświetlają je błyskawice. Na biurku stara radiostacja z trzema pokrętłami: KANAŁ, CZĘSTOTLIWOŚĆ i GŁOŚNOŚĆ, obok ekran radaru i dwie lampy pod sufitem. Otwarty dziennik latarnika.
### Zagadka
W dzienniku latarnika zapisano, jak wezwać ratowników: „KANAŁ ustaw na liczbę okien w tej izbie. CZĘSTOTLIWOŚĆ to liczba stopni prowadzących na szczyt wieży podzielona przez dwa. GŁOŚNOŚĆ to liczba lamp pod sufitem pomnożona przez trzy.” Na ścianie wisi tabliczka: „Na szczyt: 88 stopni.” W izbie są trzy okna i dwie lampy. Jak ustawiacie pokrętła?
### Rozwiązanie
KANAŁ = 3 (trzy okna), CZĘSTOTLIWOŚĆ = 44 (88 : 2), GŁOŚNOŚĆ = 6 (2 lampy × 3).
### Podpowiedzi
1. Każde pokrętło ma swoją wskazówkę w dzienniku – czytajcie po jednym.
2. Policzcie okna i lampy w opisie izby, a liczbę stopni znajdziecie na tabliczce.
3. 3 okna → kanał 3; 88 : 2 = 44; 2 × 3 = 6.
### Typ
dial_combination

## Etap 3: Izba lampy
### Miejsce
Szczyt wieży: szklana izba z ogromną soczewką na obrotowym mechanizmie z kołami zębatymi. Zbiornik oleju z zaworem, zimny palnik, okiennice trzaskające na wietrze, opuszczona przesłona. Na podłodze podarta instrukcja rozruchu.
### Zagadka
Instrukcja rozruchu lampy rozpadła się na pięć kroków, ale zostały wskazówki: „Pompa oleju jest zawsze pierwszym krokiem. Palnika nie wolno zapalać przy otwartych okiennicach. Palnik potrzebuje oleju. Mechanizm obrotu włącza się dopiero, gdy palnik płonie. Przesłonę otwiera się na samym końcu.” Kroki: Zapal palnik, Zamknij okiennice, Otwórz przesłonę, Włącz pompę oleju, Uruchom mechanizm obrotu. W jakiej kolejności je wykonujecie?
### Rozwiązanie
Włącz pompę oleju → Zamknij okiennice → Zapal palnik → Uruchom mechanizm obrotu → Otwórz przesłonę. Pompa musi być pierwsza, przesłona ostatnia; z trzech środkowych okiennice muszą być przed palnikiem, a obrót po palniku, więc kolejność środka jest jedyna.
### Podpowiedzi
1. Zacznijcie od kroku, który „zawsze jest pierwszy”, i tego, który jest „na samym końcu”.
2. Zostały trzy kroki: okiennice, palnik i obrót. Co musi być przed palnikiem, a co po nim?
3. Pompa, okiennice, palnik, obrót, przesłona.
### Typ
sequence_order

## Etap 4: Zamek na drzwiach
### Miejsce
Powrót na dół: grube drzwi wyjściowe z elektronicznym zamkiem na trzy cyfry. Obok kartka z nieudanymi próbami poprzednich latarników i komentarzami mechanizmu. Za oknem światło latarni już omiata morze.
### Zagadka
Zamek otwiera trzycyfrowy kod. Na kartce zapisano nieudane próby:
- 5 1 2 – jedna cyfra poprawna i na właściwym miejscu.
- 9 3 0 – dwie cyfry poprawne, obie na niewłaściwych miejscach.
- 4 6 8 – żadna cyfra nie jest poprawna.
- 3 5 9 – trzy cyfry poprawne, wszystkie na niewłaściwych miejscach.
Jaki kod otwiera drzwi?
### Rozwiązanie
593. Z próby 359 wiemy, że kod składa się z cyfr 3, 5 i 9, ale 3 nie stoi na pierwszym miejscu, 5 nie na drugim, a 9 nie na trzecim. Z próby 512 jedna cyfra jest na właściwym miejscu – może to być tylko 5 na pierwszym miejscu (1 i 2 nie należą do kodu). Skoro 9 nie może być trzecia, stoi druga, a 3 trzecia: 5 9 3.
### Podpowiedzi
1. Która próba mówi Wam, jakie trzy cyfry są w kodzie?
2. Skoro w 512 tylko 5 może być poprawna, to gdzie stoi piątka?
3. Dziewiątka nie może być trzecia (próba 359), więc jest druga. Zostaje 5 9 3.
### Typ
pin_code

# Zakończenie
Zamek szczęka i drzwi ustępują. Na zewnątrz sztorm słabnie, a wielka lampa nad Wami rzuca na morze snop światła. Statek odbija od rafy i wraca na kurs, a jego syrena dziękuje Wam trzema długimi sygnałami. Latarnia znów żyje – dzięki Wam.
