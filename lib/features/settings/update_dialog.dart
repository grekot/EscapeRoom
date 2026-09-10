import 'package:flutter/material.dart';

import '../../core/platform/native_update.dart';
import '../../core/update/app_update.dart';

/// Shows what is new and lets the player install (Android) or open the
/// release page (other platforms).
Future<void> showUpdateDialog(BuildContext context, ReleaseInfo release) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _UpdateDialog(release: release),
  );
}

/// Manual check from Settings: reports "up to date" or opens the dialog.
Future<void> checkForUpdates(BuildContext context, String repo) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final r = await UpdateChecker().latest(repo);
    if (!context.mounted) return;
    if (r == null) {
      messenger.showSnackBar(const SnackBar(content: Text('W repozytorium nie ma jeszcze żadnego wydania.')));
    } else if (!r.isNewer) {
      messenger.showSnackBar(SnackBar(content: Text('Masz najnowszą wersję (${AppVersion.current}).')));
    } else {
      await showUpdateDialog(context, r);
    }
  } on UpdateException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.release});
  final ReleaseInfo release;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double? _progress; // null = idle, 0..1 = downloading
  String? _error;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.release;
    final canInstall = NativeUpdate.canInstallApk && r.apkUrl != null;
    final size = r.apkSize > 0 ? ' (${(r.apkSize / (1024 * 1024)).toStringAsFixed(1)} MB)' : '';
    return AlertDialog(
      title: Text('Aktualizacja ${r.version}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 360),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Masz wersję ${AppVersion.current}, dostępna jest ${r.version}.'),
              if (r.notes.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(r.notes.trim(), style: const TextStyle(fontSize: 12.5, height: 1.35)),
              ],
              if (_progress != null) ...[
                const SizedBox(height: 14),
                LinearProgressIndicator(value: _progress! > 0 ? _progress : null),
                const SizedBox(height: 4),
                Text('Pobieranie… ${(_progress! * 100).round()}%', style: const TextStyle(fontSize: 12)),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12.5)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Później'),
        ),
        if (canInstall)
          FilledButton.icon(
            onPressed: _busy ? null : _downloadAndInstall,
            icon: const Icon(Icons.system_update),
            label: Text('Pobierz i zainstaluj$size'),
          )
        else
          FilledButton.icon(
            onPressed: () => NativeUpdate.openUrl(r.htmlUrl),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Otwórz stronę wydania'),
          ),
      ],
    );
  }

  Future<void> _downloadAndInstall() async {
    setState(() {
      _busy = true;
      _error = null;
      _progress = 0;
    });
    try {
      final file = await AppUpdater().downloadApk(widget.release, onProgress: (got, total) {
        if (!mounted) return;
        setState(() => _progress = total > 0 ? got / total : 0);
      });
      final ok = await NativeUpdate.installApk(file.path);
      if (!ok) {
        throw const UpdateException('Nie udało się uruchomić instalatora. Zezwól aplikacji na instalowanie nieznanych aplikacji w ustawieniach systemu.');
      }
      if (mounted) Navigator.of(context).pop();
    } on UpdateException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Błąd: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }
}
