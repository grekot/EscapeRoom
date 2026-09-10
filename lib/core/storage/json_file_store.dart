import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// One JSON document per file inside `<app documents>/<dirName>/`.
class JsonFileStore {
  JsonFileStore(this.dirName, {Directory? root}) : _root = root;

  final String dirName;
  final Directory? _root;
  Directory? _dir;

  Future<Directory> _directory() async {
    if (_dir != null) return _dir!;
    final base = _root ?? await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}${Platform.pathSeparator}$dirName');
    if (!await d.exists()) await d.create(recursive: true);
    return _dir = d;
  }

  File _file(Directory d, String id) =>
      File('${d.path}${Platform.pathSeparator}${_safe(id)}.json');

  static String _safe(String id) => id.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');

  Future<List<Map<String, dynamic>>> readAll() async {
    final d = await _directory();
    final out = <Map<String, dynamic>>[];
    await for (final e in d.list()) {
      if (e is File && e.path.endsWith('.json')) {
        try {
          final v = jsonDecode(await e.readAsString());
          if (v is Map<String, dynamic>) out.add(v);
        } catch (_) {
          // skip corrupt file
        }
      }
    }
    return out;
  }

  Future<Map<String, dynamic>?> read(String id) async {
    final f = _file(await _directory(), id);
    if (!await f.exists()) return null;
    try {
      final v = jsonDecode(await f.readAsString());
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String id, Map<String, dynamic> json) async {
    final f = _file(await _directory(), id);
    await f.writeAsString(const JsonEncoder.withIndent('  ').convert(json),
        flush: true);
  }

  Future<void> delete(String id) async {
    final f = _file(await _directory(), id);
    if (await f.exists()) await f.delete();
  }
}
