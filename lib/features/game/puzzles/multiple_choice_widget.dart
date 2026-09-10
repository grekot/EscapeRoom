import 'package:flutter/material.dart';

import '../../../domain/puzzle.dart';
import 'puzzle_view.dart';

class MultipleChoiceWidget extends StatefulWidget {
  const MultipleChoiceWidget({
    super.key,
    required this.puzzle,
    required this.enabled,
    required this.onSubmit,
    required this.accent,
  });

  final MultipleChoicePuzzle puzzle;
  final bool enabled;
  final AnswerSubmit onSubmit;
  final Color accent;

  @override
  State<MultipleChoiceWidget> createState() => _MultipleChoiceWidgetState();
}

class _MultipleChoiceWidgetState extends State<MultipleChoiceWidget> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final letters = 'ABCDEFGH';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.puzzle.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: _selected == i
                  ? widget.accent.withValues(alpha: 0.18)
                  : const Color(0xFF162032),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: widget.enabled ? () => setState(() => _selected = i) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: _selected == i ? widget.accent : Colors.white12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: _selected == i
                            ? widget.accent
                            : Colors.white12,
                        child: Text(letters[i % letters.length],
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _selected == i ? Colors.black : Colors.white)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(widget.puzzle.options[i])),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 4),
        SubmitButton(
          label: 'Wybieram',
          accent: widget.accent,
          onPressed: widget.enabled && _selected != null
              ? () => widget.onSubmit(_selected!, widget.puzzle.options[_selected!])
              : null,
        ),
      ],
    );
  }
}
