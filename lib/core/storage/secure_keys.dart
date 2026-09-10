import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// API keys live in the Android Keystore-backed secure storage, never in
/// shared preferences or files.
class SecureKeys {
  SecureKeys({FlutterSecureStorage? storage})
      : _s = storage ?? const FlutterSecureStorage();

  static const _kAnthropic = 'anthropic_api_key';
  static const _kGemini = 'gemini_api_key';

  final FlutterSecureStorage _s;

  Future<String> anthropic() async => (await _s.read(key: _kAnthropic)) ?? '';
  Future<String> gemini() async => (await _s.read(key: _kGemini)) ?? '';

  Future<void> setAnthropic(String v) => _write(_kAnthropic, v);
  Future<void> setGemini(String v) => _write(_kGemini, v);

  Future<void> _write(String key, String v) async {
    final t = v.trim();
    if (t.isEmpty) {
      await _s.delete(key: key);
    } else {
      await _s.write(key: key, value: t);
    }
  }
}
