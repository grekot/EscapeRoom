import 'package:flutter/material.dart';

import '../../../domain/puzzle.dart';
import 'puzzle_view.dart';

/// Drag items into order. Items named after colours get a coloured "wire".
class SequenceOrderWidget extends StatefulWidget {
  const SequenceOrderWidget({
    super.key,
    required this.puzzle,
    required this.enabled,
    required this.onSubmit,
    required this.accent,
  });

  final SequenceOrderPuzzle puzzle;
  final bool enabled;
  final AnswerSubmit onSubmit;
  final Color accent;

  @override
  State<SequenceOrderWidget> createState() => _SequenceOrderWidgetState();
}

class _SequenceOrderWidgetState extends State<SequenceOrderWidget> {
  late final List<String> _items = List.of(widget.puzzle.items);

  static Color? _colorFor(String s) {
    final t = s.toLowerCase();
    if (t.contains('czerwon')) return const Color(0xFFEF4444);
    if (t.contains('zielon')) return const Color(0xFF22C55E);
    if (t.contains('niebiesk')) return const Color(0xFF3B82F6);
    if (t.contains('żółt') || t.contains('zolt')) return const Color(0xFFFACC15);
    if (t.contains('biał') || t.contains('bial')) return const Color(0xFFF8FAFC);
    if (t.contains('czarn')) return const Color(0xFF1F2937);
    if (t.contains('pomarańcz') || t.contains('pomarancz')) return const Color(0xFFF97316);
    if (t.contains('fiolet') || t.contains('purpur')) return const Color(0xFFA855F7);
    if (t.contains('róż') || t.contains('roz')) return const Color(0xFFEC4899);
    if (t.contains('brąz') || t.contains('braz')) return const Color(0xFF92400E);
    if (t.contains('szar')) return const Color(0xFF9CA3AF);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Przeciągnij, aby zmienić kolejność',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: Colors.white54)),
        const SizedBox(height: 6),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: _items.length,
          onReorder: !widget.enabled
              ? (_, _) {}
              : (o, n) {
                  setState(() {
                    if (n > o) n -= 1;
                    final it = _items.removeAt(o);
                    _items.insert(n, it);
                  });
                },
          itemBuilder: (context, i) {
            final item = _items[i];
            final c = _colorFor(item);
            return ReorderableDelayedDragStartListener(
              key: ValueKey('seq_$item'),
              index: i,
              enabled: widget.enabled,
              child: Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: widget.accent.withValues(alpha: 0.2),
                    child: Text('${i + 1}',
                        style: TextStyle(
                            color: widget.accent, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(item),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (c != null)
                        Container(
                          width: 46,
                          height: 10,
                          decoration: BoxDecoration(
                            color: c,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: Colors.white24),
                          ),
                        ),
                      const SizedBox(width: 10),
                      ReorderableDragStartListener(
                        index: i,
                        enabled: widget.enabled,
                        child: const Icon(Icons.drag_handle, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        SubmitButton(
          label: 'Zatwierdź kolejność',
          icon: Icons.electrical_services,
          accent: widget.accent,
          onPressed: widget.enabled
              ? () => widget.onSubmit(List<String>.of(_items), _items.join(' → '))
              : null,
        ),
      ],
    );
  }
}
