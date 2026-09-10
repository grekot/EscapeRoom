import '../../../../domain/catalog.dart';

Map<String, dynamic> _obj(Map<String, dynamic> props,
        {String? description}) =>
    {
      'type': 'object',
      'description': ?description,
      'additionalProperties': false,
      'required': props.keys.toList(),
      'properties': props,
    };

Map<String, dynamic> _str([String? d]) =>
    {'type': 'string', 'description': ?d};

Map<String, dynamic> _int([String? d]) =>
    {'type': 'integer', 'description': ?d};

Map<String, dynamic> _bool([String? d]) =>
    {'type': 'boolean', 'description': ?d};

Map<String, dynamic> _arr(Map<String, dynamic> items, [String? d]) =>
    {'type': 'array', 'description': ?d, 'items': items};

Map<String, dynamic> _const(String type) => {'type': 'string', 'enum': [type]};

/// JSON Schema for the puzzle union – shared by the designer and the judge.
Map<String, dynamic> puzzleJsonSchema() => {
      'anyOf': [
        _obj({
          'type': _const(PuzzleTypes.sequenceOrder),
          'prompt': _str('Polecenie dla gracza.'),
          'items': _arr(_str(), 'Elementy do ułożenia (3–8), unikalne.'),
          'correctOrder': _arr(_str(), 'Te same elementy w poprawnej kolejności.'),
        }, description: 'Gracz układa elementy w kolejności (przeciąganie).'),
        _obj({
          'type': _const(PuzzleTypes.pinCode),
          'prompt': _str(),
          'codeLength': _int('Liczba cyfr kodu (2–6).'),
          'answer': _str('Poprawny kod, tylko cyfry, długość = codeLength.'),
          'clues': _arr(
            _obj({
              'code': _str('Błędna próba, tylko cyfry.'),
              'inPlace': _int('Ile cyfr poprawnych i na właściwym miejscu.'),
              'wrongPlace': _int('Ile cyfr poprawnych, ale na złym miejscu.'),
              'text': _str('Opis wskazówki dla gracza, zgodny z liczbami.'),
            }),
            'Nieudane próby jako wskazówki (3–6). Razem muszą wyznaczać DOKŁADNIE jeden kod.',
          ),
        }, description: 'Sejf z klawiaturą numeryczną i logami błędnych prób.'),
        _obj({
          'type': _const(PuzzleTypes.multipleChoice),
          'prompt': _str(),
          'options': _arr(_str(), '2–5 opcji.'),
          'correctIndex': _int('Indeks poprawnej opcji (od 0).'),
        }, description: 'Wybór jednej z opcji.'),
        _obj({
          'type': _const(PuzzleTypes.textAnswer),
          'prompt': _str(),
          'acceptedAnswers': _arr(_str(), 'Wszystkie akceptowane warianty odpowiedzi.'),
          'normalize': _bool('true = ignoruj wielkość liter, polskie znaki i interpunkcję.'),
        }, description: 'Odpowiedź tekstowa: hasło, zagadka słowna, szyfr.'),
        _obj({
          'type': _const(PuzzleTypes.matching),
          'prompt': _str(),
          'leftItems': _arr(_str(), 'Elementy lewej kolumny (2–6).'),
          'rightItems': _arr(_str(), 'Elementy prawej kolumny, tyle samo.'),
          'correctPairs': _arr(
            _arr(_str(), '[lewy, prawy]'),
            'Poprawne pary, po jednej na każdy lewy element.',
          ),
        }, description: 'Dopasowanie par (np. etykiety do pudełek).'),
        _obj({
          'type': _const(PuzzleTypes.toggleGrid),
          'prompt': _str(),
          'rows': _int(),
          'cols': _int(),
          'labels': _arr(_str(), 'Etykieta każdego pola (rows*cols) albo pusta lista.'),
          'targetState': _arr(_bool(), 'Docelowy stan każdego pola (rows*cols).'),
        }, description: 'Siatka przełączników/dźwigni do ustawienia.'),
        _obj({
          'type': _const(PuzzleTypes.dialCombination),
          'prompt': _str(),
          'dials': _arr(
            _obj({'label': _str(), 'min': _int(), 'max': _int()}),
            '1–6 pokręteł/suwaków.',
          ),
          'answer': _arr(_int(), 'Docelowa wartość każdego pokrętła.'),
        }, description: 'Pokrętła / suwaki / waga do ustawienia na wartości.'),
        _obj({
          'type': _const(PuzzleTypes.openExplanation),
          'prompt': _str(),
          'rubric': _str('Co MUSI zawierać poprawna odpowiedź – dla sędziego AI, gracz tego nie widzi.'),
          'exampleSolution': _str('Przykładowa pełna poprawna odpowiedź.'),
        }, description: 'Gracz opisuje metodę/algorytm słowami; ocenia sędzia AI.'),
      ],
    };

/// JSON Schema for a whole [GameSpec] as produced by the game designer.
Map<String, dynamic> gameSpecJsonSchema() => _obj({
      'title': _str(),
      'intro': _str('Narracja otwierająca grę, 2–5 zdań, w drugiej osobie liczby mnogiej lub pojedynczej.'),
      'gmPersona': _str('Kto w świecie gry mówi do graczy jako Mistrz Gry (postać, ton, sposób mówienia) – 1–2 zdania; przenieś ze scenariusza.'),
      'outro': _str('Narracja po ucieczce, 2–4 zdania.'),
      'difficulty': {
        'type': 'string',
        'enum': Difficulty.values.map((d) => d.wire).toList(),
      },
      'targetAge': _int(),
      'visualTheme': {
        'type': 'string',
        'enum': VisualTheme.values.map((d) => d.wire).toList(),
        'description': 'Motyw graficzny całej gry.',
      },
      'stages': _arr(
        _obj({
          'title': _str(),
          'narrative': _str('Tekst wejścia do etapu: co gracze widzą i czują. 2–4 zdania.'),
          'scene': _obj({
            'backdrop': {
              'type': 'string',
              'enum': Backdrops.all,
              'description': 'Rodzaj pomieszczenia.',
            },
            'ambientColor': _str('Kolor przewodni sceny w hex, np. "#2b6cb0".'),
            'lighting': {
              'type': 'string',
              'enum': Lighting.values.map((d) => d.wire).toList(),
            },
            'objects': _arr(
              _obj({
                'id': _str('Krótki identyfikator, np. "safe".'),
                'label': _str('Nazwa widoczna dla gracza.'),
                'icon': {'type': 'string', 'enum': SceneIcons.all},
                'description': _str('Klimatyczny opis tego, co gracz widzi, gdy ogląda obiekt (1–2 zdania).'),
                'clue': _str('ODKRYCIE: konkretna informacja zdobywana po zbadaniu obiektu (wyryte liczby, reguła, klucz szyfru, fragment kolejności). Aplikacja pokazuje ją w zbliżeniu i zapisuje w notatniku gracza. "" tylko dla mechanizmu zagadki (np. sam zamek) albo jednego fałszywego tropu.'),
                'requires': _str('id obiektu, który trzeba zbadać wcześniej, aby odczytać to odkrycie (łańcuch wskazówek), albo "".'),
                'lockedText': _str('Co gracz widzi, gdy zbada obiekt przed spełnieniem requires, np. „Za ciemno, żeby odczytać napis”. "" gdy requires = "".'),
                'interactive': _bool('true = Mistrz Gry komentuje oglądanie obiektu na żywo.'),
                'x': {'type': 'number', 'description': 'Gdzie na ilustracji jest ten obiekt, w poziomie 0..1 (zgodnie z imagePrompt). Aplikacja pokaże tam znacznik, jeśli obiekt nie ma własnego rekwizytu.'},
                'y': {'type': 'number', 'description': 'Położenie obiektu w pionie 0..1 (0 = góra).'},
              }),
              '2–5 obiektów do oglądania w scenie.',
            ),
            'imagePrompt': _str(
                'Prompt dla ilustratora AI PO ANGIELSKU: szeroki plan pomieszczenia, kluczowe meble/urządzenia, materiały, światło, nastrój. Bez ludzi, bez tekstu/napisów. 1–3 zdania.'),
            'props': _arr(
              _obj({
                'type': {'type': 'string', 'enum': PropTypes.all.keys.toList()},
                'x': {'type': 'number', 'description': 'Środek rekwizytu w poziomie, 0..1 (0 = lewa krawędź).'},
                'y': {'type': 'number', 'description': 'Środek rekwizytu w pionie, 0..1 (0 = góra).'},
                'size': {'type': 'number', 'description': 'Szerokość rekwizytu jako ułamek szerokości sceny, 0.08..0.4.'},
                'objectId': _str('id obiektu ze scene.objects, który opisuje ten rekwizyt (dotknięcie rekwizytu = oglądanie obiektu) albo "".'),
                'label': _str('Krótka etykieta albo "".'),
                'reactsToSuccess': _bool('true = po rozwiązaniu etapu rekwizyt przechodzi w stan aktywny (wajcha w górę, drzwi się otwierają, dioda na zielono).'),
                'spritePrompt': _str('Tylko dla type=custom: PO ANGIELSKU jeden przedmiot do narysowania (co to jest, materiał, kolor, styl), bez tła i bez tekstu. Dla innych typów "".'),
                'animation': {
                  'type': 'string',
                  'enum': PropTypes.animations,
                  'description': 'Ruch sprite\'a dla type=custom: bob (kołysanie), pulse (pulsowanie/świecenie), swing (wahanie), spin (obrót), none. Dla innych typów "none".',
                },
              }),
              '2–5 animowanych rekwizytów rozmieszczonych na ilustracji (dolna połowa i boki, nie zasłaniaj środka).',
            ),
          }),
          'puzzle': puzzleJsonSchema(),
          'hints': _arr(_str(), 'Dokładnie 3 podpowiedzi: od ogólnej do niemal wprost.'),
          'fallbackTexts': _obj({
            'success': _str('Reakcja na poprawne rozwiązanie.'),
            'failure': _str('Reakcja na błędną odpowiedź, bez zdradzania rozwiązania.'),
            'stuck': _str('Zachęta, gdy gracz prosi o pomoc.'),
          }),
          'effectOnSuccess': {
            'type': 'string',
            'enum': SuccessEffect.values.map((d) => d.wire).toList(),
          },
        }),
        'Etapy gry w kolejności (2–8).',
      ),
    });

/// Schema for the AI judge of open_explanation answers.
Map<String, dynamic> judgementJsonSchema() => _obj({
      'correct': _bool('Czy odpowiedź gracza spełnia rubrykę.'),
      'feedback': _str('1–3 zdania do gracza. Gdy błędna: co jest nie tak, bez podawania rozwiązania.'),
    });

/// Schema for a live game-master reaction.
Map<String, dynamic> gmReactionJsonSchema({List<String> objectIds = const []}) => _obj({
      'narration': _str('1–3 zdania Mistrza Gry do graczy (do 4 przy streszczeniu po przerwie).'),
      'mood': {
        'type': 'string',
        'enum': ['neutral', 'encouraging', 'tense', 'triumphant'],
      },
      'offerHint': _bool('true, gdy warto zaproponować graczowi podpowiedź.'),
      'focusObjectId': {
        'type': 'string',
        'enum': [...objectIds, ''],
        'description': 'id obiektu sceny, na który warto teraz spojrzeć (aplikacja go podświetli), albo "" gdy nie wskazujesz niczego.',
      },
    });
