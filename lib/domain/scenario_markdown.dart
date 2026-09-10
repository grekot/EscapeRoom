import 'catalog.dart';
import 'scenario.dart';

/// Deterministic parser/serializer for the Markdown form of
/// `escape-room-scenario/1`.
///
/// Expected shape (headings are matched case-insensitively and tolerate
/// small variations such as "Etap 1 – Tytuł" or "Etap 1. Tytuł"):
///
/// ```markdown
/// ---
/// format: escape-room-scenario/1
/// title: ...
/// theme: ...
/// language: pl
/// targetAge: 11
/// difficulty: medium
/// ---
/// # Wprowadzenie
/// ...
/// ## Etap 1: Tytuł
/// ### Miejsce
/// ### Zagadka
/// ### Rozwiązanie
/// ### Podpowiedzi
/// 1. ...
/// ### Typ
/// pin_code
/// # Zakończenie
/// ```
class ScenarioMarkdown {
  const ScenarioMarkdown._();

  static final _frontMatter = RegExp(r'^\s*---\s*\n([\s\S]*?)\n---\s*\n');
  static final _h1 = RegExp(r'^#\s+(.+?)\s*$');
  static final _h2Stage = RegExp(
      r'^##\s+(?:etap|stage|pok[oó]j|room)\s*(\d+)?\s*[:.\-–—]?\s*(.*?)\s*$',
      caseSensitive: false);
  static final _h3 = RegExp(r'^###\s+(.+?)\s*$');
  static final _listItem = RegExp(r'^\s*(?:\d+[.)]|[-*•])\s+(.*)$');

  /// Returns null when the text does not look like the template at all
  /// (no stage headings). Throws [FormatException] for a template that is
  /// recognisable but broken.
  static Scenario? tryParse(String text, {required String id}) {
    var body = text.replaceAll('\r\n', '\n');
    final meta = <String, String>{};
    final fm = _frontMatter.firstMatch(body);
    if (fm != null) {
      for (final line in fm.group(1)!.split('\n')) {
        final i = line.indexOf(':');
        if (i <= 0) continue;
        final k = line.substring(0, i).trim().toLowerCase();
        var v = line.substring(i + 1).trim();
        final hash = v.indexOf(' #');
        if (hash >= 0) v = v.substring(0, hash).trim();
        meta[k] = _unquote(v);
      }
      body = body.substring(fm.end);
    }

    final lines = body.split('\n');
    final hasStage = lines.any(_h2Stage.hasMatch);
    if (!hasStage) return null;

    String intro = '';
    String outro = '';
    String? titleFromH1;
    final stages = <_StageDraft>[];

    String section = 'none'; // none | intro | outro | stage
    String sub = ''; // for stage: place | puzzle | solution | hints | type | mechanism | notes | check
    final buf = StringBuffer();
    _StageDraft? cur;

    void flush() {
      final txt = buf.toString().trim();
      buf.clear();
      if (txt.isEmpty) return;
      switch (section) {
        case 'intro':
          intro = _join(intro, txt);
        case 'outro':
          outro = _join(outro, txt);
        case 'stage':
          final c = cur!;
          switch (sub) {
            case 'place':
              c.place = _join(c.place, txt);
            case 'puzzle':
              c.puzzle = _join(c.puzzle, txt);
            case 'solution':
              c.solution = _join(c.solution, txt);
            case 'hints':
              c.hints.addAll(_parseList(txt));
            case 'type':
              c.type = txt.split(RegExp(r'\s+')).first.toLowerCase();
            case 'mechanism':
              c.mechanism = _join(c.mechanism, txt);
            case 'notes':
              c.notes = _join(c.notes, txt);
            case 'check':
              c.check = _join(c.check, txt);
            default:
              c.place = _join(c.place, txt);
          }
      }
    }

    for (final raw in lines) {
      final line = raw.trimRight();
      final h2 = _h2Stage.firstMatch(line);
      if (h2 != null) {
        flush();
        section = 'stage';
        sub = 'place';
        cur = _StageDraft(title: h2.group(2)?.trim() ?? '');
        if (cur.title.isEmpty) cur.title = 'Etap ${stages.length + 1}';
        stages.add(cur);
        continue;
      }
      final h1 = _h1.firstMatch(line);
      if (h1 != null) {
        flush();
        final t = h1.group(1)!.toLowerCase();
        if (_isIntro(t)) {
          section = 'intro';
        } else if (_isOutro(t)) {
          section = 'outro';
        } else if (stages.isEmpty && intro.isEmpty && titleFromH1 == null) {
          titleFromH1 = h1.group(1)!.trim();
          section = 'intro';
        } else {
          section = 'none';
        }
        continue;
      }
      final h3 = _h3.firstMatch(line);
      if (h3 != null && section == 'stage') {
        flush();
        sub = _subKind(h3.group(1)!);
        continue;
      }
      buf.writeln(line);
    }
    flush();

    if (stages.isEmpty) return null;

    final title = meta['title'] ?? titleFromH1 ?? 'Bez tytułu';
    return Scenario(
      id: id,
      title: title,
      theme: meta['theme'] ?? '',
      language: meta['language'] ?? 'pl',
      targetAge: int.tryParse(meta['targetage'] ?? '') ?? 10,
      difficulty: Difficulty.parse(meta['difficulty']),
      intro: intro,
      stages: [
        for (final d in stages)
          ScenarioStage(
            title: d.title,
            place: d.place,
            puzzle: d.puzzle,
            solution: d.solution,
            hints: d.hints,
            suggestedType:
                PuzzleTypes.all.contains(d.type) ? d.type : null,
            mechanism: d.mechanism,
            designNotes: d.notes,
            uniquenessCheck: d.check,
          ),
      ],
      outro: outro,
      source: ScenarioSource.imported,
      createdAt: DateTime.now(),
      throughline: meta['throughline'] ?? '',
      gmPersona: meta['gmpersona'] ?? '',
    );
  }

  static String toMarkdown(Scenario s) {
    final sb = StringBuffer();
    sb.writeln('---');
    sb.writeln('format: ${Scenario.format}');
    sb.writeln('title: ${_yaml(s.title)}');
    sb.writeln('theme: ${_yaml(s.theme)}');
    sb.writeln('language: ${s.language}');
    sb.writeln('targetAge: ${s.targetAge}');
    sb.writeln('difficulty: ${s.difficulty.wire}');
    if (s.throughline.isNotEmpty) sb.writeln('throughline: ${_yaml(s.throughline)}');
    if (s.gmPersona.isNotEmpty) sb.writeln('gmPersona: ${_yaml(s.gmPersona)}');
    sb.writeln('---');
    sb.writeln('# Wprowadzenie');
    sb.writeln(s.intro.trim());
    for (var i = 0; i < s.stages.length; i++) {
      final st = s.stages[i];
      sb.writeln();
      sb.writeln('## Etap ${i + 1}: ${st.title}');
      sb.writeln('### Miejsce');
      sb.writeln(st.place.trim());
      sb.writeln('### Zagadka');
      sb.writeln(st.puzzle.trim());
      sb.writeln('### Rozwiązanie');
      sb.writeln(st.solution.trim());
      sb.writeln('### Podpowiedzi');
      for (var h = 0; h < st.hints.length; h++) {
        sb.writeln('${h + 1}. ${st.hints[h].trim()}');
      }
      if (st.suggestedType != null) {
        sb.writeln('### Typ');
        sb.writeln(st.suggestedType);
      }
      if (st.mechanism.isNotEmpty) {
        sb.writeln('### Mechanizm');
        sb.writeln(st.mechanism.trim());
      }
      if (st.designNotes.isNotEmpty) {
        sb.writeln('### Notatki projektowe');
        sb.writeln(st.designNotes.trim());
      }
      if (st.uniquenessCheck.isNotEmpty) {
        sb.writeln('### Sprawdzenie');
        sb.writeln(st.uniquenessCheck.trim());
      }
    }
    sb.writeln();
    sb.writeln('# Zakończenie');
    sb.writeln(s.outro.trim());
    return sb.toString();
  }

  static bool _isIntro(String t) =>
      t.startsWith('wprowadzenie') ||
      t.startsWith('wstęp') ||
      t.startsWith('wstep') ||
      t.startsWith('intro');

  static bool _isOutro(String t) =>
      t.startsWith('zakończenie') ||
      t.startsWith('zakonczenie') ||
      t.startsWith('finał') ||
      t.startsWith('final') ||
      t.startsWith('outro') ||
      t.startsWith('epilog');

  static String _subKind(String h) {
    final t = h.toLowerCase();
    if (t.startsWith('miejsce') || t.startsWith('scena') || t.startsWith('opis') || t.startsWith('place') || t.startsWith('setting')) {
      return 'place';
    }
    if (t.startsWith('zagadk') || t.startsWith('puzzle') || t.startsWith('zadanie')) {
      return 'puzzle';
    }
    if (t.startsWith('rozwi') || t.startsWith('odpowied') || t.startsWith('solution') || t.startsWith('answer')) {
      return 'solution';
    }
    if (t.startsWith('podpowied') || t.startsWith('wskaz') || t.startsWith('hint')) {
      return 'hints';
    }
    if (t.startsWith('typ') || t.startsWith('type') || t.startsWith('widget')) {
      return 'type';
    }
    if (t.startsWith('mechani')) return 'mechanism';
    if (t.startsWith('notatk') || t.startsWith('projekt') || t.startsWith('uzasadn') || t.startsWith('design')) {
      return 'notes';
    }
    if (t.startsWith('sprawdz') || t.startsWith('weryfik') || t.startsWith('check')) {
      return 'check';
    }
    return 'place';
  }

  static List<String> _parseList(String txt) {
    final out = <String>[];
    for (final line in txt.split('\n')) {
      final m = _listItem.firstMatch(line);
      if (m != null) {
        out.add(m.group(1)!.trim());
      } else if (line.trim().isNotEmpty && out.isNotEmpty) {
        out[out.length - 1] = '${out.last} ${line.trim()}';
      } else if (line.trim().isNotEmpty) {
        out.add(line.trim());
      }
    }
    return out;
  }

  static String _join(String a, String b) => a.isEmpty ? b : '$a\n\n$b';

  static String _unquote(String v) {
    if (v.length >= 2 &&
        ((v.startsWith('"') && v.endsWith('"')) ||
            (v.startsWith("'") && v.endsWith("'")))) {
      return v.substring(1, v.length - 1);
    }
    return v;
  }

  static String _yaml(String v) =>
      v.contains(':') || v.contains('#') ? '"${v.replaceAll('"', '\\"')}"' : v;
}

class _StageDraft {
  _StageDraft({required this.title});
  String title;
  String place = '';
  String puzzle = '';
  String solution = '';
  final List<String> hints = [];
  String type = '';
  String mechanism = '';
  String notes = '';
  String check = '';
}
