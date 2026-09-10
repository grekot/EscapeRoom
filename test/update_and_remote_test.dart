import 'dart:convert';

import 'package:escape_room/core/remote/remote_scenarios.dart';
import 'package:escape_room/core/storage/settings_repository.dart';
import 'package:escape_room/core/update/app_update.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('version comparison is numeric and ignores the v prefix', () {
    expect(AppVersion.compare('1.2.10', '1.2.9'), greaterThan(0));
    expect(AppVersion.compare('v1.0.0', '1.0.0'), 0);
    expect(AppVersion.compare('1.0', '1.0.1'), lessThan(0));
    expect(AppVersion.compare('2.0.0-beta', '1.9.9'), greaterThan(0));
    expect(AppVersion.current, isNotEmpty);
  });

  test('update checker reads the latest release and its assets', () async {
    final client = MockClient((req) async {
      expect(req.url.path, '/repos/grekot/EscapeRoom/releases/latest');
      expect(req.headers['User-Agent'], isNotNull);
      return http.Response(
        jsonEncode({
          'tag_name': 'v9.1.0',
          'name': 'Pokój Zagadek AI 9.1.0',
          'body': 'Nowe rzeczy',
          'html_url': 'https://github.com/grekot/EscapeRoom/releases/tag/v9.1.0',
          'published_at': '2026-09-10T10:00:00Z',
          'assets': [
            {'name': 'escape_room-windows-9.1.0.zip', 'browser_download_url': 'https://x/win.zip', 'size': 10},
            {'name': 'escape_room-9.1.0.apk', 'browser_download_url': 'https://x/app.apk', 'size': 65000000},
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final r = await UpdateChecker(client: client).latest('grekot/EscapeRoom');
    expect(r, isNotNull);
    expect(r!.version, '9.1.0');
    expect(r.isNewer, isTrue);
    expect(r.apkUrl, 'https://x/app.apk');
    expect(r.apkSize, 65000000);
    expect(r.windowsUrl, 'https://x/win.zip');
    expect(r.publishedAt, isNotNull);

    final none = await UpdateChecker(client: MockClient((_) async => http.Response('', 404)))
        .latest('grekot/EscapeRoom');
    expect(none, isNull);

    expect(
      () => UpdateChecker(client: MockClient((_) async => http.Response('', 403))).latest('a/b'),
      throwsA(isA<UpdateException>()),
    );
  });

  test('remote catalogue lists scenario files from root and scenarios/, skipping docs', () async {
    final client = MockClient((req) async {
      final p = req.url.path;
      if (p == '/repos/grekot/EscapeRoomScenario/contents/') {
        return http.Response(jsonEncode([
          {'type': 'file', 'name': 'README.md', 'path': 'README.md', 'download_url': 'https://raw/README.md', 'size': 100},
          {'type': 'file', 'name': 'Zamek_Czarodzieja.md', 'path': 'Zamek_Czarodzieja.md', 'download_url': 'https://raw/z.md', 'size': 4000},
          {'type': 'file', 'name': 'notes.txt', 'path': 'notes.txt', 'download_url': 'https://raw/n.txt', 'size': 5},
          {'type': 'dir', 'name': 'scenarios', 'path': 'scenarios'},
        ]), 200);
      }
      if (p == '/repos/grekot/EscapeRoomScenario/contents/scenarios') {
        return http.Response(jsonEncode([
          {'type': 'file', 'name': 'atlantyda.json', 'path': 'scenarios/atlantyda.json', 'download_url': 'https://raw/a.json', 'size': 20480},
        ]), 200);
      }
      if (p == '/repos/grekot/Empty/contents/') return http.Response('{"message":"This repository is empty."}', 404);
      return http.Response('nope', 500);
    });
    final cat = RemoteScenarioCatalog(client: client);
    final items = await cat.list('grekot/EscapeRoomScenario');
    expect(items.map((s) => s.path), ['scenarios/atlantyda.json', 'Zamek_Czarodzieja.md']);
    expect(items.last.title, 'Zamek Czarodzieja');
    expect(items.first.isJson, isTrue);
    expect(await cat.list('grekot/Empty'), isEmpty);
    expect(RemoteScenarioCatalog.isScenarioFile('FORMAT.md'), isFalse);
    expect(RemoteScenarioCatalog.isScenarioFile('latarnia.MD'), isTrue);
  });

  test('settings keep the repositories and the update switch', () {
    const s = Settings(updateRepo: 'me/app', scenarioRepo: 'me/scn', checkUpdates: false);
    final back = Settings.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
    expect(back.updateRepo, 'me/app');
    expect(back.scenarioRepo, 'me/scn');
    expect(back.checkUpdates, isFalse);
    expect(const Settings().updateRepo, UpdateChecker.defaultRepo);
    expect(const Settings().scenarioRepo, RemoteScenarioCatalog.defaultRepo);
  });
}
