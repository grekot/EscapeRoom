import 'package:flutter/services.dart';

/// Text handed to the app by Android via "Open with…" / "Share" of a
/// `.md` / `.json` / plain-text file. Backed by a small MethodChannel in
/// `MainActivity.kt`; each text is delivered once.
class IncomingIntent {
  static const _channel = MethodChannel('pl.escaperoom/incoming');

  static Future<String?> takeText() async {
    try {
      final v = await _channel.invokeMethod<String>('takeText');
      return (v == null || v.trim().isEmpty) ? null : v;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
