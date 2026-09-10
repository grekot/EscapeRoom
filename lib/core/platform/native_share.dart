import 'package:flutter/services.dart';

/// Android share sheet via a small MethodChannel in `MainActivity.kt`
/// (replaces the share_plus plugin, which conflicts with flutter_secure_storage 11).
class NativeShare {
  static const _channel = MethodChannel('pl.escaperoom/share');

  static Future<bool> text(String text, {String? subject}) async {
    try {
      await _channel.invokeMethod<void>('shareText', {
        'text': text,
        'subject': subject,
      });
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// [path] must be inside the app's cache directory (FileProvider scope).
  static Future<bool> file(String path,
      {required String mimeType, String? subject}) async {
    try {
      await _channel.invokeMethod<void>('shareFile', {
        'path': path,
        'mimeType': mimeType,
        'subject': subject,
      });
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
