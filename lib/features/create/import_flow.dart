import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/ai/pipeline/scenario_importer.dart';
import '../../domain/game_spec.dart';
import '../../domain/game_spec_validator.dart';
import 'jobs.dart';

/// Handles any pasted/opened text: an exported game (`escape-room-game/1`),
/// a scenario in JSON or Markdown, or free text converted by the model.
Future<void> importText(BuildContext context, WidgetRef ref, String text) async {
  final t = text.trim();
  if (t.isEmpty) return;

  void snack(String m) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  // 1. A whole game exported from the app.
  if (t.startsWith('{')) {
    try {
      final j = jsonDecode(t);
      if (j is Map && j['format'] == GameSpec.format) {
        final spec = GameSpec.fromJson(Map<String, dynamic>.from(j), id: newId());
        final issues = GameSpecValidator.validate(spec);
        final fatal = issues.where((i) => i.contains('sprzeczna') || i.contains('permutacją')).toList();
        if (fatal.isNotEmpty) {
          snack('Plik gry ma błędy: ${fatal.first}');
          return;
        }
        await ref.read(gameSpecRepoProvider).save(spec);
        ref.invalidate(libraryProvider);
        snack('Zaimportowano grę „${spec.title}”.');
        if (context.mounted) context.go('/');
        return;
      }
    } on FormatException {
      // not a game → try scenario
    }
  }

  // 2. Scenario in the app's format.
  final id = newId();
  final local = ScenarioImporter.parseLocal(t, id: id);
  if (local != null) {
    await ref.read(scenarioRepoProvider).save(local.scenario);
    ref.invalidate(libraryProvider);
    snack(local.method == ImportMethod.json
        ? 'Zaimportowano scenariusz (JSON).'
        : 'Zaimportowano scenariusz (Markdown).');
    if (context.mounted) context.push('/scenario/$id');
    return;
  }

  // 3. Anything else → model converts it.
  final hasAi = ref.read(aiProviderProvider).valueOrNull != null;
  if (!context.mounted) return;
  if (!hasAi) {
    snack('Tekst nie pasuje do szablonu, a konwersja przez AI wymaga klucza API.');
    return;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Nietypowy format'),
      content: const Text(
          'Ten tekst nie jest w formacie aplikacji. Czy Mistrz Gry ma spróbować odczytać z niego scenariusz? Zajmie to chwilę i zużyje trochę tokenów.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Odczytaj przez AI')),
      ],
    ),
  );
  if (ok == true && context.mounted) {
    context.push('/generating', extra: importWithAiJob(t));
  }
}
