import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/platform/native_share.dart';

/// Shares [content] as a text file via the system share sheet; falls back to
/// copying the text to the clipboard when sharing is unavailable.
Future<void> shareTextFile(BuildContext context,
    {required String fileName, required String content, String? subject}) async {
  try {
    final dir = Directory('${(await getTemporaryDirectory()).path}${Platform.pathSeparator}shared');
    if (!await dir.exists()) await dir.create(recursive: true);
    final f = File('${dir.path}${Platform.pathSeparator}$fileName');
    await f.writeAsString(content, flush: true);
    final mime = fileName.endsWith('.json') ? 'application/json' : 'text/markdown';
    final ok = await NativeShare.file(f.path, mimeType: mime, subject: subject);
    if (!ok) {
      await Clipboard.setData(ClipboardData(text: content));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Udostępnianie niedostępne – skopiowano treść do schowka.')));
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Nie udało się udostępnić: $e')));
    }
  }
}

String safeFileName(String title, String ext) {
  final base = title
      .toLowerCase()
      .replaceAll(RegExp(r'[ąćęłńóśźż]'), '')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return '${base.isEmpty ? 'scenariusz' : base}.$ext';
}
