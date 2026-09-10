import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../domain/game_save.dart';
import '../../domain/game_spec.dart';
import '../../domain/scenario.dart';
import '../../domain/scenario_markdown.dart';
import 'json_file_store.dart';

const builtinId = 'builtin_warsztat_wynalazcy';

/// Built-in content shipped as assets: (id, scenario .md, game .json).
const builtins = <({String id, String scenario, String game})>[
  (
    id: builtinId,
    scenario: 'assets/scenarios/warsztat_wynalazcy.md',
    game: 'assets/gamespecs/warsztat_wynalazcy.json',
  ),
  (
    id: 'builtin_latarnia',
    scenario: 'assets/scenarios/latarnia_w_sztormie.md',
    game: 'assets/gamespecs/latarnia_w_sztormie.json',
  ),
];

bool isBuiltin(String id) => builtins.any((b) => b.id == id);

class ScenarioRepository {
  ScenarioRepository({JsonFileStore? store})
      : _store = store ?? JsonFileStore('scenarios');

  final JsonFileStore _store;
  final Map<String, Scenario> _builtinCache = {};

  Future<Scenario> builtin([String id = builtinId]) async {
    final cached = _builtinCache[id];
    if (cached != null) return cached;
    final b = builtins.firstWhere((b) => b.id == id);
    final md = await rootBundle.loadString(b.scenario);
    final s = ScenarioMarkdown.tryParse(md, id: id)!;
    return _builtinCache[id] = s.copyWith(
      source: ScenarioSource.builtin,
      createdAt: DateTime(2026, 9, 6),
    );
  }

  Future<List<Scenario>> all() async {
    final list = <Scenario>[for (final b in builtins) await builtin(b.id)];
    for (final j in await _store.readAll()) {
      try {
        list.add(Scenario.fromJson(j));
      } catch (_) {}
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<Scenario?> byId(String id) async {
    if (isBuiltin(id)) return builtin(id);
    final j = await _store.read(id);
    return j == null ? null : Scenario.fromJson(j);
  }

  Future<void> save(Scenario s) => _store.write(s.id, s.toJson());

  Future<void> delete(String id) async {
    if (isBuiltin(id)) return;
    await _store.delete(id);
  }
}

class GameSpecRepository {
  GameSpecRepository({JsonFileStore? store})
      : _store = store ?? JsonFileStore('games');

  final JsonFileStore _store;
  final Map<String, GameSpec> _builtinCache = {};

  Future<GameSpec> builtin([String id = builtinId]) async {
    final cached = _builtinCache[id];
    if (cached != null) return cached;
    final b = builtins.firstWhere((b) => b.id == id);
    final raw = await rootBundle.loadString(b.game);
    return _builtinCache[id] =
        GameSpec.fromJson(jsonDecode(raw) as Map<String, dynamic>, id: id);
  }

  Future<List<GameSpec>> all() async {
    final list = <GameSpec>[for (final b in builtins) await builtin(b.id)];
    for (final j in await _store.readAll()) {
      try {
        list.add(GameSpec.fromJson(j));
      } catch (_) {}
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<GameSpec?> byId(String id) async {
    if (isBuiltin(id)) return builtin(id);
    final j = await _store.read(id);
    return j == null ? null : GameSpec.fromJson(j);
  }

  Future<void> save(GameSpec g) => _store.write(g.id, g.toJson());

  Future<void> delete(String id) async {
    if (isBuiltin(id)) return;
    await _store.delete(id);
  }
}

class SaveRepository {
  SaveRepository({JsonFileStore? store})
      : _store = store ?? JsonFileStore('saves');

  final JsonFileStore _store;

  Future<List<GameSave>> all() async {
    final list = <GameSave>[];
    for (final j in await _store.readAll()) {
      try {
        list.add(GameSave.fromJson(j));
      } catch (_) {}
    }
    list.sort((a, b) => b.lastPlayedAt.compareTo(a.lastPlayedAt));
    return list;
  }

  Future<GameSave?> byId(String id) async {
    final j = await _store.read(id);
    return j == null ? null : GameSave.fromJson(j);
  }

  Future<void> save(GameSave s) => _store.write(s.id, s.toJson());
  Future<void> delete(String id) => _store.delete(id);

  Future<void> deleteForGame(String gameSpecId) async {
    for (final s in await all()) {
      if (s.gameSpecId == gameSpecId) await _store.delete(s.id);
    }
  }
}
