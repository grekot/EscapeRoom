import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/remote/remote_scenarios.dart';
import '../create/import_flow.dart';

/// Scenarios published in the configured GitHub repository, ready to import.
class RemoteScenariosCard extends ConsumerStatefulWidget {
  const RemoteScenariosCard({super.key, required this.repo});
  final String repo;

  @override
  ConsumerState<RemoteScenariosCard> createState() => _RemoteScenariosCardState();
}

class _RemoteScenariosCardState extends ConsumerState<RemoteScenariosCard> {
  String? _downloading;

  @override
  Widget build(BuildContext context) {
    final remote = ref.watch(remoteScenariosProvider);
    final accent = Theme.of(context).colorScheme.primary;
    return Card(
      color: const Color(0xFF13202C),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_download_outlined, color: accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Scenariusze z GitHub', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(widget.repo, style: const TextStyle(fontSize: 12, color: Colors.white54)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Odśwież',
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.invalidate(remoteScenariosProvider),
                ),
              ],
            ),
            remote.when(
              loading: () => const Padding(
                padding: EdgeInsets.fromLTRB(0, 10, 6, 4),
                child: LinearProgressIndicator(minHeight: 3),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.only(top: 8, right: 6),
                child: Text('$e', style: const TextStyle(fontSize: 12.5, color: Colors.orangeAccent)),
              ),
              data: (items) => items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.only(top: 8, right: 6),
                      child: Text(
                        'Repozytorium nie zawiera jeszcze scenariuszy. Wrzuć tam pliki .md lub .json (w katalogu głównym albo w folderze scenarios/), a pojawią się tutaj.',
                        style: TextStyle(fontSize: 12.5, color: Colors.white70),
                      ),
                    )
                  : Column(
                      children: [
                        for (final s in items)
                          ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.only(left: 2, right: 4),
                            leading: Icon(s.isJson ? Icons.data_object : Icons.article_outlined,
                                color: Colors.white70, size: 20),
                            title: Text(s.title, style: const TextStyle(fontSize: 13.5)),
                            subtitle: Text(
                              '${s.path} · ${(s.size / 1024).toStringAsFixed(s.size < 10240 ? 1 : 0)} KB',
                              style: const TextStyle(fontSize: 11.5),
                            ),
                            trailing: _downloading == s.path
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : FilledButton.tonal(
                                    onPressed: _downloading != null ? null : () => _import(s),
                                    child: const Text('Pobierz'),
                                  ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _import(RemoteScenario s) async {
    setState(() => _downloading = s.path);
    try {
      final text = await RemoteScenarioCatalog().fetch(s);
      if (!mounted) return;
      await importText(context, ref, text);
    } on RemoteException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _downloading = null);
    }
  }
}
