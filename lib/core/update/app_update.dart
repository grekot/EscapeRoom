import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// The running app's version. CI passes the release tag through
/// `--dart-define=APP_VERSION=1.2.0`; local builds fall back to the default.
class AppVersion {
  const AppVersion._();

  static const current =
      String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

  /// Compares dotted versions numerically ("1.2.10" > "1.2.9"); a leading
  /// `v` and any suffix after the third number are ignored.
  static int compare(String a, String b) {
    final pa = _parts(a), pb = _parts(b);
    for (var i = 0; i < 3; i++) {
      final d = pa[i].compareTo(pb[i]);
      if (d != 0) return d;
    }
    return 0;
  }

  static List<int> _parts(String v) {
    final m = RegExp(r'(\d+)(?:\.(\d+))?(?:\.(\d+))?')
        .firstMatch(v.trim().replaceFirst(RegExp(r'^[vV]'), ''));
    return [for (var i = 1; i <= 3; i++) int.tryParse(m?.group(i) ?? '') ?? 0];
  }
}

/// A published GitHub release of the app.
class ReleaseInfo {
  const ReleaseInfo({
    required this.tag,
    required this.version,
    required this.name,
    required this.notes,
    required this.htmlUrl,
    this.apkUrl,
    this.apkSize = 0,
    this.windowsUrl,
    this.publishedAt,
  });

  final String tag;
  final String version;
  final String name;
  final String notes;
  final String htmlUrl;

  /// Direct download of the Android package, when the release has one.
  final String? apkUrl;
  final int apkSize;

  /// Windows build archive, when the release has one.
  final String? windowsUrl;
  final DateTime? publishedAt;

  bool get isNewer => AppVersion.compare(version, AppVersion.current) > 0;

  factory ReleaseInfo.fromJson(Map<String, dynamic> j) {
    final tag = (j['tag_name'] ?? '').toString();
    String? apk, win;
    var apkSize = 0;
    for (final a in (j['assets'] as List? ?? const [])) {
      if (a is! Map) continue;
      final name = (a['name'] ?? '').toString().toLowerCase();
      final url = (a['browser_download_url'] ?? '').toString();
      if (name.endsWith('.apk') && apk == null) {
        apk = url;
        apkSize = (a['size'] as num?)?.toInt() ?? 0;
      } else if (name.endsWith('.zip') && name.contains('windows') && win == null) {
        win = url;
      }
    }
    return ReleaseInfo(
      tag: tag,
      version: tag.replaceFirst(RegExp(r'^[vV]'), ''),
      name: (j['name'] ?? tag).toString(),
      notes: (j['body'] ?? '').toString(),
      htmlUrl: (j['html_url'] ?? '').toString(),
      apkUrl: apk,
      apkSize: apkSize,
      windowsUrl: win,
      publishedAt: DateTime.tryParse((j['published_at'] ?? '').toString()),
    );
  }
}

class UpdateException implements Exception {
  const UpdateException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Reads the latest release of a public GitHub repository (`owner/repo`).
class UpdateChecker {
  UpdateChecker({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const defaultRepo = 'grekot/EscapeRoom';

  static const _headers = {
    'Accept': 'application/vnd.github+json',
    'User-Agent': 'escape-room-app',
  };

  /// `null` when the repository has no releases yet.
  Future<ReleaseInfo?> latest(String repo) async {
    final uri = Uri.parse('https://api.github.com/repos/${repo.trim()}/releases/latest');
    final http.Response r;
    try {
      r = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 20));
    } on SocketException {
      throw const UpdateException('Brak połączenia z GitHub.');
    } on HttpException catch (e) {
      throw UpdateException('Błąd sieci: ${e.message}');
    }
    if (r.statusCode == 404) return null;
    if (r.statusCode == 403) {
      throw const UpdateException('GitHub odrzucił zapytanie (limit anonimowych zapytań). Spróbuj za godzinę.');
    }
    if (r.statusCode != 200) {
      throw UpdateException('GitHub odpowiedział kodem ${r.statusCode}.');
    }
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    if (j is! Map<String, dynamic>) throw const UpdateException('Niepoprawna odpowiedź GitHub.');
    return ReleaseInfo.fromJson(j);
  }
}

/// Downloads the release APK into the app's cache so the platform installer
/// can be launched on it.
class AppUpdater {
  AppUpdater({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<File> downloadApk(ReleaseInfo release,
      {void Function(int received, int total)? onProgress}) async {
    final url = release.apkUrl;
    if (url == null) throw const UpdateException('To wydanie nie zawiera pliku APK.');
    final dir = Directory('${(await getTemporaryDirectory()).path}${Platform.pathSeparator}updates');
    await dir.create(recursive: true);
    final file = File('${dir.path}${Platform.pathSeparator}escape_room-${release.version}.apk');
    final req = http.Request('GET', Uri.parse(url))..headers['User-Agent'] = 'escape-room-app';
    final resp = await _client.send(req).timeout(const Duration(minutes: 2));
    if (resp.statusCode != 200) {
      throw UpdateException('Pobieranie nie powiodło się (kod ${resp.statusCode}).');
    }
    final total = resp.contentLength ?? release.apkSize;
    var received = 0;
    final sink = file.openWrite();
    try {
      await for (final chunk in resp.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
    } finally {
      await sink.close();
    }
    return file;
  }
}
