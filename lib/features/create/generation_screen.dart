import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ai/ai_errors.dart';

/// A long-running AI task. [run] reports status lines and returns the route
/// to navigate to when done.
class GenerationJob {
  const GenerationJob({required this.title, required this.run});

  final String title;
  final Future<String> Function(WidgetRef ref, void Function(String) status) run;
}

class GenerationScreen extends ConsumerStatefulWidget {
  const GenerationScreen({super.key, required this.job});

  final GenerationJob job;

  @override
  ConsumerState<GenerationScreen> createState() => _GenerationScreenState();
}

class _GenerationScreenState extends ConsumerState<GenerationScreen> {
  final List<String> _log = [];
  String? _error;
  bool _running = false;
  Timer? _ticker;
  int _tick = 0;

  static const _flavour = [
    'Odkurzam stare mechanizmy…',
    'Sprawdzam, czy zamki mają dokładnie jeden klucz…',
    'Ustawiam światło w pokojach…',
    'Ukrywam wskazówki w przedmiotach…',
    'Liczę cyfry w logach sejfu…',
    'Nasłuchuję syku pneumatycznych drzwi…',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _running = true;
      _log.clear();
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted) setState(() => _tick++);
    });
    try {
      final route = await widget.job.run(ref, (s) {
        if (mounted) setState(() => _log.add(s));
      });
      if (!mounted) return;
      context.go(route);
    } on AiException catch (e) {
      await _logError(e.toString(), e.body);
      if (mounted) setState(() => _error = e.userMessage);
    } catch (e, st) {
      await _logError('$e\n$st', null);
      if (mounted) setState(() => _error = 'Nieoczekiwany błąd: $e');
    } finally {
      _ticker?.cancel();
      if (mounted) setState(() => _running = false);
    }
  }

  /// Keeps the last failures (message + raw model output) in
  /// `<documents>/logs/` so a "niepoprawne dane" error can be diagnosed.
  Future<void> _logError(String message, String? body) async {
    try {
      final base = await getApplicationDocumentsDirectory();
      final dir = Directory('${base.path}${Platform.pathSeparator}logs');
      if (!await dir.exists()) await dir.create(recursive: true);
      final stamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final f = File('${dir.path}${Platform.pathSeparator}error_$stamp.txt');
      await f.writeAsString('${widget.job.title}\n$message\n\n--- odpowiedź modelu ---\n${body ?? '(brak)'}');
      // keep at most 10 logs
      final files = dir.listSync().whereType<File>().toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      for (final old in files.skip(10)) {
        try {
          old.deleteSync();
        } catch (_) {}
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.job.title),
        leading: _running
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        automaticallyImplyLeading: !_running,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error == null) ...[
              SizedBox(
                height: 90,
                width: 90,
                child: Center(
                  child: _running
                      ? CircularProgressIndicator(color: accent, strokeWidth: 5)
                      : Icon(Icons.check_circle, size: 80, color: accent),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _log.isEmpty ? 'Łączę się z Mistrzem Gry…' : _log.last,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Text(
                _flavour[_tick % _flavour.length],
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 24),
              const Text(
                'To może potrwać od kilkunastu sekund do 2 minut.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ] else ...[
              const Icon(Icons.error_outline, size: 72, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.refresh),
                label: const Text('Spróbuj ponownie'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => context.push('/settings'),
                icon: const Icon(Icons.settings),
                label: const Text('Ustawienia (klucz API, model)'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => context.go('/'),
                child: const Text('Wróć do biblioteki'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
