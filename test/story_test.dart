import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:escape_room/core/ai/ai_provider.dart';
import 'package:escape_room/core/ai/pipeline/game_master.dart';
import 'package:escape_room/core/ai/pipeline/prompts/gm_prompts.dart';
import 'package:escape_room/core/ai/pipeline/prompts/scenario_prompts.dart';
import 'package:escape_room/domain/catalog.dart';
import 'package:escape_room/domain/game_spec.dart';
import 'package:escape_room/domain/mechanisms.dart';
import 'package:escape_room/domain/scenario.dart';
import 'package:escape_room/domain/scenario_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAi implements AiProvider {
  _FakeAi(this.answer);
  final Map<String, dynamic> answer;
  String? lastSystem;
  Map<String, dynamic>? lastSchema;

  @override
  String get id => 'fake';
  @override
  String get model => 'fake';

  @override
  Future<Map<String, dynamic>> completeJson({
    required String system,
    required String user,
    required Map<String, dynamic> schema,
    int maxTokens = 16000,
    Duration timeout = const Duration(seconds: 180),
  }) async {
    lastSystem = system;
    lastSchema = schema;
    return answer;
  }

  @override
  Future<String> chat({required String system, required List<ChatMessage> history, int maxTokens = 1024, Duration timeout = const Duration(seconds: 45)}) async => '';

  @override
  Future<void> ping() async {}
}

GameSpec _lighthouse() => GameSpec.fromJson(
    jsonDecode(File('assets/gamespecs/latarnia_w_sztormie.json').readAsStringSync()) as Map<String, dynamic>);

void main() {
  test('mechanism tags of a designed game feed the "do not repeat" list', () {
    final g = _lighthouse();
    final tags = Mechanisms.ofGame(g);
    expect(tags, hasLength(4));
    expect(tags.last, contains('mastermind'));
    expect(Mechanisms.describeGame(g), startsWith('„Latarnia w sztormie” – '));

    final picks = Mechanisms.suggest(avoid: [...tags, Mechanisms.mastermind], count: 5, rng: Random(1));
    expect(picks, hasLength(5));
    expect(picks.any((m) => m.contains('mastermind')), isFalse);
    expect(picks.toSet(), hasLength(5));
  });

  test('scenario markdown keeps dramaturgy fields through a round trip', () {
    final s = Scenario(
      id: 'x',
      title: 'Wieża',
      theme: 'wieża zegarowa',
      language: 'pl',
      targetAge: 10,
      difficulty: Difficulty.medium,
      intro: 'Intro.',
      outro: 'Outro.',
      source: ScenarioSource.prompt,
      createdAt: DateTime(2026),
      throughline: 'Kto zatrzymał zegar? Zegarmistrz, by ocalić miasto.',
      gmPersona: 'głos zegarmistrza z pozytywki, spokojny',
      stages: const [
        ScenarioStage(
          title: 'Hol',
          place: 'Marmur.',
          puzzle: 'Cel: ustawcie wskazówki. Na tabliczce klucz, na posadzce cienie.',
          solution: '3:15',
          hints: ['a', 'b', 'c'],
          suggestedType: 'dial_combination',
          mechanism: 'zegar i cienie',
          designNotes: 'Zegarmistrz zbudował to jako test; cień wraca w finale.',
          uniquenessCheck: 'Rozważono 9:15 – cień pada w złą stronę.',
        ),
      ],
    );
    final md = ScenarioMarkdown.toMarkdown(s);
    expect(md, contains('throughline:'));
    expect(md, contains('### Mechanizm'));
    expect(md, contains('### Sprawdzenie'));
    final back = ScenarioMarkdown.tryParse(md, id: 'y')!;
    expect(back.throughline, s.throughline);
    expect(back.gmPersona, s.gmPersona);
    expect(back.stages.single.mechanism, 'zegar i cienie');
    expect(back.stages.single.designNotes, contains('finale'));
    expect(back.stages.single.uniquenessCheck, contains('9:15'));
    // JSON too
    final j = Scenario.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
    expect(j.gmPersona, s.gmPersona);
    expect(j.stages.single.uniquenessCheck, contains('9:15'));
  });

  test('writer prompts carry dramaturgy rules, the avoid list and fresh ideas', () {
    final sys = ScenarioPrompts.writerSystem(age: 10, playerNames: 'Zuzanna');
    expect(sys, contains('DRAMATURGIA'));
    expect(sys, contains('throughline'));
    expect(sys, contains('gmPersona'));
    expect(sys, contains('NIE POWTARZAJ'));
    expect(sys, contains(Mechanisms.catalogue.first));
    final user = ScenarioPrompts.writerUser(
      theme: 'latarnia',
      age: 10,
      difficulty: Difficulty.medium,
      stages: 3,
      avoid: ['„Grobowiec” – logi błędnych prób zamka (mastermind); szyfr'],
      suggestedMechanisms: ['zegar i cienie'],
    );
    expect(user, contains('NIE POWTARZAJ'));
    expect(user, contains('„Grobowiec”'));
    expect(user, contains('ŚWIEŻE POMYSŁY'));
    expect(user, contains('zegar i cienie'));
  });

  test('GM system prompt includes persona and the investigation state', () {
    final spec = GameSpec.fromJson({
      ..._lighthouse().toJson(),
      'gmPersona': 'głos latarnika z taśmy, ciepły',
    });
    final prompt = GmPrompts.system(spec, 1,
        playerNames: 'Zuzanna',
        state: const GmState(
          discovered: {'plaque'},
          attempts: 2,
          hintsUsed: 1,
          elapsed: Duration(minutes: 7),
          wrongAnswers: ['3, 40, 6'],
        ));
    expect(prompt, contains('TWOJA POSTAĆ'));
    expect(prompt, contains('głos latarnika'));
    expect(prompt, contains('STAN ŚLEDZTWA'));
    expect(prompt, contains('Tabliczka →'));
    expect(prompt, contains('Radiostacja (ZABLOKOWANY – odblokuje go zbadanie: Dziennik latarnika)'));
    expect(prompt, contains('błędne odpowiedzi: 2'));
    expect(prompt, contains('„3, 40, 6”'));
    expect(prompt, contains('podpowiedzi użyte: 1 z 3'));
    expect(prompt, contains('DRABINA NAPROWADZANIA'));
    expect(prompt, contains('KROKI POŚREDNIE'));
  });

  test('GM reaction carries a validated focusObjectId; resume has a fallback', () async {
    final spec = _lighthouse();
    final ai = _FakeAi({'narration': 'Spójrzcie na tabliczkę.', 'mood': 'neutral', 'offerHint': false, 'focusObjectId': 'plaque'});
    final gm = GameMaster(ai: ai, spec: spec, playerNames: '');
    final r = await gm.react(const FreeChat('nie wiem'), stageIndex: 1, history: const [], state: const GmState());
    expect(r.focusObjectId, 'plaque');
    expect((ai.lastSchema!['properties'] as Map)['focusObjectId']['enum'], containsAll(['plaque', 'radio', '']));
    expect(ai.lastSystem, contains('STAN ŚLEDZTWA'));

    final bogus = _FakeAi({'narration': 'x', 'mood': 'neutral', 'offerHint': false, 'focusObjectId': 'ghost'});
    final r2 = await GameMaster(ai: bogus, spec: spec, playerNames: '')
        .react(const GameResumed(Duration(minutes: 45)), stageIndex: 1, history: const []);
    expect(r2.focusObjectId, isNull);

    final offline = GameMaster(ai: null, spec: spec, playerNames: '');
    final r3 = await offline.react(const GameResumed(Duration(hours: 2)), stageIndex: 1, history: const []);
    expect(r3.text, spec.stages[1].narrative);
    expect(const GameResumed(Duration(minutes: 45)).describe(), contains('45 min'));
  });
}
