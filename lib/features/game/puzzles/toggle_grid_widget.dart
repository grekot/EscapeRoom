import 'package:flutter/material.dart';

import '../../../domain/puzzle.dart';
import 'puzzle_view.dart';

class ToggleGridWidget extends StatefulWidget {
  const ToggleGridWidget({
    super.key,
    required this.puzzle,
    required this.enabled,
    required this.onSubmit,
    required this.accent,
  });

  final ToggleGridPuzzle puzzle;
  final bool enabled;
  final AnswerSubmit onSubmit;
  final Color accent;

  @override
  State<ToggleGridWidget> createState() => _ToggleGridWidgetState();
}

class _ToggleGridWidgetState extends State<ToggleGridWidget> {
  late final List<bool> _state =
      List.filled(widget.puzzle.rows * widget.puzzle.cols, false);

  @override
  Widget build(BuildContext context) {
    final p = widget.puzzle;
    final cols = p.cols.clamp(1, 6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _state.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: p.labels.isEmpty ? 1.2 : 1.0,
          ),
          itemBuilder: (context, i) {
            final on = _state[i];
            final label = i < p.labels.length ? p.labels[i] : '';
            return Material(
              color: on ? widget.accent.withValues(alpha: 0.25) : const Color(0xFF162032),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: widget.enabled
                    ? () => setState(() => _state[i] = !_state[i])
                    : null,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: on ? widget.accent : Colors.white12),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(on ? Icons.toggle_on : Icons.toggle_off,
                          size: 40, color: on ? widget.accent : Colors.white38),
                      if (label.isNotEmpty)
                        Text(label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        SubmitButton(
          label: 'Zatwierdź ustawienie',
          icon: Icons.power,
          accent: widget.accent,
          onPressed: widget.enabled
              ? () => widget.onSubmit(
                    List<bool>.of(_state),
                    _state.map((b) => b ? '1' : '0').join(),
                  )
              : null,
        ),
      ],
    );
  }
}
