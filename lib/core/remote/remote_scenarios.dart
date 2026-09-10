import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// A scenario file (`.md` / `.json`) published in a public GitHub repository.
class RemoteScenario {
  const RemoteScenario({
    required this.name,
    required this.path,
    required this.downloadUrl,
    required this.size,
  });

  final String name;
  final String path;
  final String downloadUrl;
  final int size;

  /// "latarnia_w-sztormie.md" → "latarnia w sztormie"
  String get title => name
      .replaceFirst(RegExp(r'\.(md|json)$', caseSensitive: false), '')
      .replaceAll(RegExp(r'[_\-]+'), ' ')
      .trim();

  bool get isJson => name.toLowerCase().endsWith('.json');
}

class RemoteException implements Exception {
  const RemoteException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Lists and fetches scenarios from `owner/repo`: files in the repository
/// root plus a `scenarios/` (or `scenariusze/`) folder, one level deep.
class RemoteScenarioCatalog {
  RemoteScenarioCatalog({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const defaultRepo = 'grekot/EscapeRoomScenario';
  static const folders = {'scenarios', 'scenariusze'};

  static const _headers = {
    'Accept': 'application/vnd.github+json',
    'User-Agent': 'escape-room-app',
  };

  Future<List<RemoteScenario>> list(String repo) async {
    final out = <RemoteScenario>[];
    final root = await _contents(repo, '');
    for (final e in root) {
      final type = (e['type'] ?? '').toString();
      final name = (e['name'] ?? '').toString();
      if (type == 'file' && isScenarioFile(name)) {
        out.add(_entry(e));
      } else if (type == 'dir' && folders.contains(name.toLowerCase())) {
        for (final f in await _contents(repo, (e['path'] ?? name).toString())) {
          if ((f['type'] ?? '') == 'file' && isScenarioFile((f['name'] ?? '').toString())) {
            out.add(_entry(f));
          }
        }
      }
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  Future<String> fetch(RemoteScenario s) async {
    final r = await _get(Uri.parse(s.downloadUrl));
    if (r.statusCode != 200) {
      throw RemoteException('Nie udało się pobrać „${s.name}” (kod ${r.statusCode}).');
    }
    return utf8.decode(r.bodyBytes);
  }

  /// Documentation files are not scenarios.
  static bool isScenarioFile(String name) {
    final n = name.toLowerCase();
    if (!(n.endsWith('.md') || n.endsWith('.json'))) return false;
    const docs = ['readme', 'license', 'licence', 'changelog', 'contributing', 'format', 'prompt', 'instrukcja'];
    return !docs.any(n.startsWith);
  }

  RemoteScenario _entry(Map<String, dynamic> e) => RemoteScenario(
        name: (e['name'] ?? '').toString(),
        path: (e['path'] ?? e['name'] ?? '').toString(),
        downloadUrl: (e['download_url'] ?? '').toString(),
        size: (e['size'] as num?)?.toInt() ?? 0,
      );

  Future<List<Map<String, dynamic>>> _contents(String repo, String path) async {
    final uri = Uri.parse('https://api.github.com/repos/${repo.trim()}/contents/$path');
    final r = await _get(uri);
    if (r.statusCode == 404) return const []; // empty repository or no such folder
    if (r.statusCode == 403) {
      throw const RemoteException('GitHub odrzucił zapytanie (limit anonimowych zapytań). Spróbuj za godzinę.');
    }
    if (r.statusCode != 200) {
      throw RemoteException('GitHub odpowiedział kodem ${r.statusCode} dla ${repo.trim()}.');
    }
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    if (j is! List) return const [];
    return [for (final e in j) if (e is Map) Map<String, dynamic>.from(e)];
  }

  Future<http.Response> _get(Uri uri) async {
    try {
      return await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 20));
    } on SocketException {
      throw const RemoteException('Brak połączenia z GitHub.');
    } on HttpException catch (e) {
      throw RemoteException('Błąd sieci: ${e.message}');
    }
  }
}
