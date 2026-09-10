import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Platform side of in-app updates (MainActivity.kt on Android).
class NativeUpdate {
  const NativeUpdate._();

  static const _channel = MethodChannel('pl.escaperoom/update');

  /// Only Android can install a downloaded package from inside the app.
  static bool get canInstallApk => !kIsWeb && Platform.isAndroid;

  /// Launches the system installer on an APK inside the app's cache dir.
  static Future<bool> installApk(String path) async {
    try {
      await _channel.invokeMethod<void>('installApk', {'path': path});
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Opens a web page in the default browser (release page on Windows).
  static Future<bool> openUrl(String url) async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod<void>('openUrl', {'url': url});
        return true;
      } on PlatformException {
        return false;
      } on MissingPluginException {
        return false;
      }
    }
    try {
      if (Platform.isWindows) {
        await Process.start('rundll32', ['url.dll,FileProtocolHandler', url]);
      } else if (Platform.isMacOS) {
        await Process.start('open', [url]);
      } else {
        await Process.start('xdg-open', [url]);
      }
      return true;
    } on ProcessException {
      return false;
    }
  }
}
