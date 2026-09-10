/// Small helpers for tolerant JSON parsing of AI-generated documents.
library;

String jStr(Map<String, dynamic> j, String key, {String fallback = ''}) {
  final v = j[key];
  if (v == null) return fallback;
  if (v is String) return v;
  return v.toString();
}

String? jStrOrNull(Map<String, dynamic> j, String key) {
  final v = j[key];
  if (v == null) return null;
  if (v is String) return v.isEmpty ? null : v;
  return v.toString();
}

int jInt(Map<String, dynamic> j, String key, {int fallback = 0}) {
  final v = j[key];
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? fallback;
  return fallback;
}

bool jBool(Map<String, dynamic> j, String key, {bool fallback = false}) {
  final v = j[key];
  if (v is bool) return v;
  if (v is String) {
    final s = v.toLowerCase().trim();
    if (s == 'true' || s == 'yes' || s == 'tak') return true;
    if (s == 'false' || s == 'no' || s == 'nie') return false;
  }
  if (v is num) return v != 0;
  return fallback;
}

List<String> jStrList(Map<String, dynamic> j, String key) {
  final v = j[key];
  if (v is List) return v.map((e) => e.toString()).toList();
  if (v is String && v.isNotEmpty) return [v];
  return const [];
}

List<int> jIntList(Map<String, dynamic> j, String key) {
  final v = j[key];
  if (v is List) {
    return v.map((e) {
      if (e is int) return e;
      if (e is num) return e.toInt();
      return int.tryParse(e.toString()) ?? 0;
    }).toList();
  }
  return const [];
}

List<bool> jBoolList(Map<String, dynamic> j, String key) {
  final v = j[key];
  if (v is List) {
    return v.map((e) {
      if (e is bool) return e;
      if (e is num) return e != 0;
      final s = e.toString().toLowerCase();
      return s == 'true' || s == '1' || s == 'on';
    }).toList();
  }
  return const [];
}

Map<String, dynamic> jMap(Map<String, dynamic> j, String key) {
  final v = j[key];
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
  return const {};
}

List<Map<String, dynamic>> jMapList(Map<String, dynamic> j, String key) {
  final v = j[key];
  if (v is List) {
    return v
        .whereType<Map>()
        .map((m) => m.map((k, val) => MapEntry(k.toString(), val)))
        .toList();
  }
  return const [];
}

DateTime jDate(Map<String, dynamic> j, String key) {
  final v = j[key];
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  return DateTime.now();
}

Map<String, dynamic> asJsonMap(Object? v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
  throw const FormatException('Oczekiwano obiektu JSON.');
}
