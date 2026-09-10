import 'dart:convert';
import 'dart:io';

import 'package:escape_room/core/ai/ai_provider.dart';
import 'package:escape_room/core/ai/pipeline/playtester.dart';
import 'package:escape_room/domain/catalog.dart';
import 'package:escape_room/domain/game_spec.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake model: answers the lighthouse puzzles by script.
class _FakeAi implements AiProvider {
  _FakeAi(this.answers);
  final List<Map<String, dynamic>> answers;
  final List<String> prompts = [];
  var calls = 0;

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
    prompts.add(user);
    return answers[calls++];
  }

  @override
  Future<String> chat({required String system, required List<ChatMessage> history, int maxTokens = 1024, Duration timeout = const Duration(seconds: 45)}) async => '';

  @override
  Future<void> ping() async {}
}

void main() {
  test('flags stages the test player cannot solve and passes the others', () async {
    final spec = GameSpec.fromJson(jsonDecode(
        File('assets/gamespecs/latarnia_w_sztormie.json').readAsStringSync()) as Map<String, dynamic>);
    final ai = _FakeAi([
      // stage 1 toggle_grid: wrong state, says data is missing
      {'state': [true, false, false, false, false, true], 'confidence': 'guess', 'missing': 'nie wiem, która to litera L'},
      // stage 2 dials: correct
      {'values': [3, 44, 6], 'confidence': 'sure', 'missing': ''},
      // stage 3 sequence: correct but guessed
      {'order': ['Włącz pompę oleju', 'Zamknij okiennice', 'Zapal palnik', 'Uruchom mechanizm obrotu', 'Otwórz przesłonę'], 'confidence': 'guess', 'missing': 'nie wiem, co po czym'},
      // stage 4 pin: correct
      {'code': '593', 'confidence': 'sure', 'missing': ''},
    ]);
    final issues = await Playtester(ai).run(spec);
    expect(ai.calls, 4);
    expect(issues, hasLength(2));
    expect(issues[0], contains('Etap 1'));
    expect(issues[0], contains('NIE rozwiązał'));
    expect(issues[0], contains('litera L'));
    expect(issues[1], contains('Etap 3'));
    expect(issues[1], contains('zgadując'));
    // the tester sees only player-visible data
    expect(ai.prompts[0], contains('ZAGADKA:'));
    expect(ai.prompts[0], contains('etykiety w kolejności: A | B | C | D | E | F'));
    expect(ai.prompts[0], isNot(contains('targetState')));
    expect(ai.prompts[3], contains('512:'));
    expect(ai.prompts[3], isNot(contains('593')));
  });

  test('flags contradictory scene data and one-step arithmetic at medium', () async {
    final spec = GameSpec.fromJson(jsonDecode(
        File('assets/gamespecs/latarnia_w_sztormie.json').readAsStringSync()) as Map<String, dynamic>);
    final ai = _FakeAi([
      {'state': [false, false, true, false, true, true], 'confidence': 'sure', 'missing': '', 'effort': 'several', 'usedObjects': ['Skrzynka'], 'contradiction': 'napis mówi o trzech bezpiecznikach, a wskaźnik o dwu'},
      {'values': [3, 44, 6], 'confidence': 'sure', 'missing': '', 'effort': 'one', 'usedObjects': ['Dziennik'], 'contradiction': ''},
      {'order': ['Włącz pompę oleju', 'Zamknij okiennice', 'Zapal palnik', 'Uruchom mechanizm obrotu', 'Otwórz przesłonę'], 'confidence': 'sure', 'missing': '', 'effort': 'one', 'usedObjects': ['Instrukcja'], 'contradiction': ''},
      {'code': '593', 'confidence': 'sure', 'missing': '', 'effort': 'several', 'usedObjects': ['Kartka'], 'contradiction': ''},
    ]);
    final issues = await Playtester(ai).run(spec, difficulty: Difficulty.medium);
    expect(issues, hasLength(2));
    expect(issues[0], contains('NIESPÓJNE'));
    expect(issues[0], contains('trzech bezpiecznikach'));
    // stage 2 (dials, one arithmetic step) is too shallow for medium; stage 3
    // (ordering, one step) is fine; stage 4 used the note's finding
    expect(issues[1], contains('Etap 2'));
    expect(issues[1], contains('za płytka'));
    expect(ai.prompts[1], contains('ODKRYCIE'), reason: 'the tester sees the findings');
  });
}
