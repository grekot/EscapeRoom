import '../../../../domain/catalog.dart';

/// JSON Schema for a [Scenario] as produced by the in-app scenario writer or
/// by the AI fallback importer.
///
/// Kept in the subset both Anthropic structured outputs and Gemini accept:
/// every object has `additionalProperties: false` and lists all fields in
/// `required`; no numeric/string length constraints (validated in Dart).
Map<String, dynamic> scenarioJsonSchema() => {
      'type': 'object',
      'additionalProperties': false,
      'required': [
        'title',
        'theme',
        'language',
        'targetAge',
        'difficulty',
        'intro',
        'stages',
        'outro',
        'throughline',
        'gmPersona',
      ],
      'properties': {
        'title': {'type': 'string', 'description': 'Krótki, chwytliwy tytuł.'},
        'theme': {
          'type': 'string',
          'description': 'Motyw/miejsce akcji w jednym zdaniu.'
        },
        'language': {'type': 'string', 'description': 'Kod języka, np. "pl".'},
        'targetAge': {
          'type': 'integer',
          'description': 'Wiek gracza, do którego dopasowano trudność i język.'
        },
        'difficulty': {
          'type': 'string',
          'enum': Difficulty.values.map((d) => d.wire).toList(),
        },
        'intro': {
          'type': 'string',
          'description':
              '2–5 zdań wprowadzenia: gdzie są gracze, co się stało, jaki jest cel.'
        },
        'stages': {
          'type': 'array',
          'description': 'Kolejne etapy (3–6).',
          'items': {
            'type': 'object',
            'additionalProperties': false,
            'required': [
              'title',
              'place',
              'puzzle',
              'solution',
              'hints',
              'suggestedType',
              'mechanism',
              'designNotes',
              'uniquenessCheck',
            ],
            'properties': {
              'title': {'type': 'string'},
              'place': {
                'type': 'string',
                'description':
                    'Opis pomieszczenia: przedmioty, światło, atmosfera – materiał na scenografię.'
              },
              'puzzle': {
                'type': 'string',
                'description':
                    'Pełna treść zagadki jako śledztwo: cel oraz 2–4 źródła informacji w pokoju (co gdzie widać/odczytano) z zależnością między nimi. Wszystkie dane potrzebne do rozwiązania.'
              },
              'mechanism': {
                'type': 'string',
                'description': 'Nazwa mechanizmu zagadki w 3–8 słowach (np. „szyfr z kluczem z tabliczki”, „liczenie okien i działanie”).'
              },
              'designNotes': {
                'type': 'string',
                'description': 'Kto w świecie gry zbudował tę zagadkę i po co; jak łączy się z innymi etapami (1–3 zdania).'
              },
              'uniquenessCheck': {
                'type': 'string',
                'description': 'Twoje sprawdzenie jedyności: jakie inne odpowiedzi rozważono i dlaczego odpadają (1–3 zdania).'
              },
              'solution': {
                'type': 'string',
                'description':
                    'Jednoznaczna odpowiedź i krótkie uzasadnienie, dlaczego jest jedyna.'
              },
              'hints': {
                'type': 'array',
                'description':
                    'Dokładnie 3 podpowiedzi: od ogólnej do niemal wprost.',
                'items': {'type': 'string'},
              },
              'suggestedType': {
                'type': 'string',
                'description':
                    'Sugerowany typ interakcji z katalogu aplikacji albo "" gdy brak sugestii.',
                'enum': [...PuzzleTypes.all, ''],
              },
            },
          },
        },
        'outro': {
          'type': 'string',
          'description': 'Zakończenie po ucieczce, 2–4 zdania: odpowiedź na pytanie przewodnie i nagroda emocjonalna.'
        },
        'throughline': {
          'type': 'string',
          'description': 'Pytanie przewodnie historii i jego odpowiedź ujawniana w finale (1–2 zdania).'
        },
        'gmPersona': {
          'type': 'string',
          'description': 'Kto w świecie gry mówi do graczy (np. „głos latarnika z nagrania na taśmie, ciepły, żartobliwy”) – 1 zdanie.'
        },
      },
    };
