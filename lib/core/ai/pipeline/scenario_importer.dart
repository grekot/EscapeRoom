import 'dart:convert';

import '../../../domain/json_utils.dart';
import '../../../domain/scenario.dart';
import '../../../domain/scenario_markdown.dart';
import '../ai_errors.dart';
import '../ai_provider.dart';
import 'prompts/scenario_prompts.dart';
import 'schemas/scenario_schema.dart';

enum ImportMethod { json, markdown, ai }

class ImportResult {
  const ImportResult(this.scenario, this.method);
  final Scenario scenario;
  final ImportMethod method;
}

/// Turns pasted/opened text into a [Scenario].
///
/// Order: strict JSON → Markdown template → AI conversion (when [ai] given).
class ScenarioImporter {
  ScenarioImporter({this.ai});

  final AiProvider? ai;

  /// Deterministic part only; returns null when AI would be needed.
  static ImportResult? parseLocal(String text, {required String id}) {
    final t = text.trim();
    if (t.startsWith('{')) {
      try {
        final j = asJsonMap(jsonDecode(t));
        if (j['stages'] is List) {
          final s = Scenario.fromJson(j, id: id, source: ScenarioSource.imported)
              .copyWith(createdAt: DateTime.now());
          if (s.validate().isEmpty) return ImportResult(s, ImportMethod.json);
        }
      } on FormatException {
        // not JSON → try markdown
      }
    }
    try {
      final s = ScenarioMarkdown.tryParse(t, id: id);
      if (s != null && s.validate().isEmpty) {
        return ImportResult(s, ImportMethod.markdown);
      }
    } on FormatException {
      // fall through
    }
    return null;
  }

  Future<ImportResult> import(String text, {required String id}) async {
    final local = parseLocal(text, id: id);
    if (local != null) return local;
    final provider = ai;
    if (provider == null) {
      throw AiException(AiErrorKind.noApiKey,
          'Tekst nie pasuje do szablonu, a konwersja przez AI wymaga klucza API.');
    }
    final json = await provider.completeJson(
      system: ScenarioPrompts.importerSystem,
      user: 'TEKST DO KONWERSJI:\n\n$text',
      schema: scenarioJsonSchema(),
    );
    final s = Scenario.fromJson(json, id: id, source: ScenarioSource.imported)
        .copyWith(createdAt: DateTime.now());
    final issues = s.validate();
    if (issues.isNotEmpty) {
      throw AiException(
          AiErrorKind.badJson, 'Konwersja niepełna: ${issues.join(' ')}');
    }
    return ImportResult(s, ImportMethod.ai);
  }
}
