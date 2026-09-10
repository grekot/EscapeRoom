import 'package:flutter/material.dart';

/// Shows revealed hints and lets the player reveal the next one.
Future<void> showHintSheet(
  BuildContext context, {
  required List<String> hints,
  required int Function() revealed,
  required Future<String?> Function() onReveal,
  required Color accent,
}) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    backgroundColor: const Color(0xFF0F172A),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final n = revealed();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb, color: accent),
                  const SizedBox(width: 8),
                  Text('Podpowiedzi ($n/${hints.length})',
                      style: Theme.of(ctx).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 12),
              if (n == 0)
                const Text(
                  'Jeszcze żadnej nie użyliście. Każda odsłonięta podpowiedź liczy się do wyniku.',
                  style: TextStyle(color: Colors.white70),
                ),
              for (var i = 0; i < n && i < hints.length; i++)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: accent.withValues(alpha: 0.2),
                      child: Text('${i + 1}',
                          style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(hints[i]),
                  ),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: n >= hints.length
                    ? null
                    : () async {
                        await onReveal();
                        if (ctx.mounted) setState(() {});
                      },
                icon: const Icon(Icons.visibility),
                label: Text(n >= hints.length
                    ? 'To już wszystkie podpowiedzi'
                    : 'Odsłoń podpowiedź ${n + 1}'),
              ),
            ],
          ),
        );
      },
    ),
  );
}
