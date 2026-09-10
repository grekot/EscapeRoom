import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../domain/game_spec.dart';

/// The players' notebook: findings collected by examining scene objects in
/// the current stage, plus how many objects still hide something.
class ClueNotebook extends StatelessWidget {
  const ClueNotebook({
    super.key,
    required this.stage,
    required this.discovered,
    required this.accent,
  });

  final GameStage stage;
  final Set<String> discovered;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scene = stage.scene;
    final found = [
      for (final o in scene.clueObjects)
        if (discovered.contains(o.id)) o,
    ];
    final hidden = scene.clueObjects.length - found.length;
    return Card(
      color: const Color(0xFF15202F),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.menu_book_outlined, size: 18, color: accent),
                const SizedBox(width: 8),
                Text('Notatnik', style: TextStyle(fontWeight: FontWeight.w700, color: accent)),
                const Spacer(),
                Text(
                  hidden > 0
                      ? 'Odkrycia: ${found.length}/${scene.clueObjects.length}'
                      : 'Wszystko zbadane',
                  style: const TextStyle(fontSize: 11.5, color: Colors.white60),
                ),
              ],
            ),
            if (found.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Zbadajcie przedmioty w pokoju – każde odkrycie zapisze się tutaj.',
                  style: TextStyle(fontSize: 12.5, color: Colors.white70, fontStyle: FontStyle.italic),
                ),
              ),
            for (final o in found)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(sceneIcon(o.icon), size: 16, color: accent.withValues(alpha: 0.85)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: '${o.label}: ',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextSpan(text: o.clue),
                        ]),
                        style: const TextStyle(fontSize: 12.5, height: 1.35),
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
}
