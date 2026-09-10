---
format: escape-room-scenario/1
title: Warsztat Wynalazcy
theme: opuszczone laboratorium genialnego, ekscentrycznego konstruktora
language: pl
targetAge: 11
difficulty: medium
---
# Wprowadzenie
Z cichym sykiem pneumatycznych siłowników ciężkie, stalowe drzwi zamykają się za Waszymi plecami. Mechaniczny zamek klika głucho – jesteście uwięzieni w opuszczonym laboratorium dziwnego, genialnego wynalazcy. W pokoju panuje niemal całkowity mrok, rozświetlany jedynie przez małą, migającą na czerwono diodę na głównym panelu sterowania. Aby wyjść, musicie przywrócić zasilanie, otworzyć sejf, naprawić czytnik kart i odblokować śluzę.

## Etap 1: Przebudzenie warsztatu
### Miejsce
Ciemne laboratorium. Na środku wielki stół roboczy z niedokończonymi projektami, śrubokrętami i resztkami dziwnych materiałów. Na ścianie panel sterowania z otwartą skrzynką elektroniki, z której zwisają cztery luźne, kolorowe przewody. Obok pożółkła kartka z instrukcją konstruktora.
### Zagadka
System zasilania został odcięty. W skrzynce zwisają cztery przewody: Biały, Czarny, Czerwony i Zielony. Trzeba je wpiąć pojedynczo, w odpowiedniej kolejności. Instrukcja na kartce mówi:
- Czarny przewód nigdy nie może być wpięty jako pierwszy ani jako ostatni.
- Biały przewód musi zostać podłączony natychmiast po czerwonym.
- Zielony przewód musisz podłączyć, zanim podłączysz czarny.
W jakiej kolejności (od pierwszego do czwartego) wpinacie przewody?
### Rozwiązanie
Zielony, Czarny, Czerwony, Biały. Biały musi być tuż po czerwonym, więc para „Czerwony–Biały” zajmuje dwa sąsiednie miejsca. Czarny nie może być pierwszy ani ostatni, a zielony musi być przed czarnym – jedyny układ spełniający wszystkie warunki to Zielony, Czarny, Czerwony, Biały.
### Podpowiedzi
1. Zacznijcie od przewodu, który ma najwięcej ograniczeń – czarnego. Gdzie na pewno nie może być?
2. Czerwony i biały zawsze idą razem, biały zaraz po czerwonym. Ile miejsc pozostaje dla zielonego i czarnego?
3. Skoro zielony musi być przed czarnym, a czarny nie może być pierwszy, to zielony jest pierwszy, a czarny drugi.
### Typ
sequence_order

## Etap 2: Sejf z logami
### Miejsce
Światło już działa. Widać porozrzucane mikrokontrolery, lutownice, zwoje kolorowego filamentu i prototyp drukarki 3D. W ścianie na końcu pokoju tkwi masywny stalowy sejf z klawiaturą numeryczną. Do drzwiczek przyklejona jest pognieciona kartka z pięcioma nieudanymi próbami włamania.
### Zagadka
Sejf otwiera trzycyfrowy kod PIN. Na kartce zapisano analizę błędnych prób:
- 6 8 2 – jedna cyfra poprawna i na właściwym miejscu.
- 6 1 4 – jedna cyfra poprawna, ale na niewłaściwym miejscu.
- 2 0 6 – dwie cyfry poprawne, obie na niewłaściwych miejscach.
- 7 3 8 – wszystkie cyfry błędne.
- 3 8 0 – jedna cyfra poprawna, ale na niewłaściwym miejscu.
Jaki kod otwiera sejf?
### Rozwiązanie
042. Z próby 738 wiemy, że 7, 3 i 8 są błędne. W 682 poprawna na miejscu musi więc być 2 na trzeciej pozycji (6 wykluczamy przez 614 i 206). W 206 dwie poprawne na złych miejscach to 2 i 0, więc 0 nie jest na drugiej pozycji – jest na pierwszej. Z 614 poprawna cyfra to 4 (bo 6 i 1 błędne), na złym miejscu, więc 4 stoi na drugiej pozycji. Kod: 0 4 2.
### Podpowiedzi
1. Zacznijcie od próby, w której wszystkie cyfry są błędne – te cyfry możecie od razu skreślić wszędzie.
2. Porównajcie 682 i 206: która cyfra występuje w obu i co to mówi o jej miejscu?
3. Skoro 2 jest na trzecim miejscu, a 0 nie może być na drugim, to 0 stoi na pierwszym. Środkową cyfrę znajdziecie w próbie 614.
### Typ
pin_code

## Etap 3: Trzy pudełka
### Miejsce
Stół roboczy z częściami zapasowymi. Trzy nieprzezroczyste kartonowe pudełka z naklejonymi etykietami: „Tylko Czerwone Diody”, „Tylko Zielone Diody”, „Mieszane: Czerwone i Zielone”. Obok wymięta kartka z dziennika konstruktora. Przy drzwiach czytnik kart z pustym gniazdem na diodę.
### Zagadka
W sejfie była karta magnetyczna, ale czytnik przy drzwiach potrzebuje zielonej diody. Z dziennika wynika, że asystent upuścił pudełka i nakleił etykiety z powrotem tak, że KAŻDE pudełko ma teraz błędną etykietę. System obronny reaguje na ruch, więc możecie wyciągnąć w ciemno tylko jedną diodę z jednego pudełka. Z którego pudełka trzeba losować, aby jedno losowanie dało pewność, gdzie są wyłącznie zielone diody?
### Rozwiązanie
Z pudełka z etykietą „Mieszane”. Ponieważ etykieta kłamie, w tym pudełku są diody tylko jednego koloru – wylosowana dioda zdradza jego zawartość. Jeśli jest zielona, pudełko „Mieszane” zawiera zielone; wtedy pudełko „Tylko Zielone” nie może zawierać zielonych ani mieszanych… nie – zawiera czerwone (bo etykieta kłamie i zielone są już zajęte), a pudełko „Tylko Czerwone” zawiera mieszane. Jeśli dioda jest czerwona – analogicznie odwrotnie.
### Podpowiedzi
1. Skoro każda etykieta kłamie, to co na pewno NIE jest w pudełku z napisem „Mieszane”?
2. Pudełko „Mieszane” ma w środku diody tylko jednego koloru. Jedno losowanie wystarczy, żeby ten kolor poznać.
3. Losujcie z pudełka „Mieszane”. Potem pamiętajcie: pozostałe dwa pudełka też mają błędne etykiety.
### Typ
multiple_choice

## Etap 4: Nowe etykiety
### Miejsce
To samo stanowisko. Z pudełka „Mieszane” wyciągnęliście zieloną diodę. Na blacie leżą trzy odklejone etykiety i trzy pudełka czekające na właściwe podpisy.
### Zagadka
Wylosowaliście ZIELONĄ diodę z pudełka opisanego jako „Mieszane”. Wiedząc, że wszystkie trzy etykiety były błędne, przypiszcie każdemu pudełku (według starej etykiety) jego prawdziwą zawartość.
### Rozwiązanie
Pudełko „Mieszane” → Tylko Zielone (wylosowana zielona, a w środku jest jeden kolor). Pudełko „Tylko Zielone” → Tylko Czerwone (nie może zawierać zielonych, bo etykieta kłamie, a zielone są już w innym pudełku; mieszane też nie, bo… zostały dwa pudełka i dwie zawartości: czerwone i mieszane; „Tylko Czerwone” nie może zawierać czerwonych, więc zawiera mieszane). Pudełko „Tylko Czerwone” → Mieszane.
### Podpowiedzi
1. Pudełko, z którego losowaliście, jest już rozstrzygnięte. Zostały dwa pudełka i dwie zawartości.
2. Pudełko z napisem „Tylko Czerwone” nie może zawierać samych czerwonych.
3. Skoro „Tylko Czerwone” ma mieszane, to „Tylko Zielone” musi mieć czerwone.
### Typ
matching

## Etap 5: Śluza i waga
### Miejsce
Wąska stalowa śluza przed wyjściem. Masywne ryglowane drzwi z zablokowanym mechanizmem. Na stoliku stara mosiężna waga szalkowa i 9 identycznie wyglądających kół zębatych. Na ścianie wyryta wiadomość konstruktora.
### Zagadka
Osiem kół zębatych waży dokładnie tyle samo, a jedno – fałszywe, z domieszką ołowiu – jest minimalnie cięższe i blokuje mechanizm. Waga jest tak zardzewiała, że rozsypie się po dokładnie dwóch ważeniach. Opiszcie, jak rozdzielić koła i przeprowadzić dwa ważenia, aby ze stuprocentową pewnością wskazać cięższe koło.
### Rozwiązanie
Podzielić 9 kół na trzy grupy po 3. Ważenie 1: dwie grupy przeciw sobie. Jeśli jedna przeważa – fałszywka jest w niej; jeśli równowaga – jest w trzeciej, nieważonej grupie. Ważenie 2: z wybranej grupy dwa koła przeciw sobie. Jeśli jedno przeważa – to ono; jeśli równowaga – fałszywe jest trzecie, nieważone koło. Kluczowe: dzielenie na trzy części, bo waga ma trzy możliwe wyniki.
### Podpowiedzi
1. Waga daje trzy odpowiedzi: lewa cięższa, prawa cięższa, równowaga. Jak podzielić koła, żeby każdy wynik coś mówił?
2. Podzielcie koła na trzy równe grupy. Co daje zważenie dwu z nich?
3. Po pierwszym ważeniu zostają trzy podejrzane koła. Zważcie dwa z nich – trzecie też może być odpowiedzią.
### Typ
open_explanation

# Zakończenie
Klink! Fałszywe koło ląduje na boku, a idealnie dopasowany mosiężny element wsuwa się w gniazdo blokady. Rozlega się zgrzyt zwalnianych rygli, z sufitu sypie się kurz, a masywne wrota otwierają się na oścież, wpuszczając blask popołudniowego słońca. Jesteście wolni! Złamanie logów sejfu, przechytrzenie kłamliwych etykiet i perfekcyjny plan ważenia to wynik godny prawdziwych inżynierów.
