import 'package:flutter/material.dart';

import '../../../domain/puzzle.dart';
import 'puzzle_view.dart';

class OpenExplanationWidget extends StatefulWidget {
  const OpenExplanationWidget({
    super.key,
    required this.puzzle,
    required this.enabled,
    required this.onSubmit,
    required this.accent,
  });

  final OpenExplanationPuzzle puzzle;
  final bool enabled;
  final AnswerSubmit onSubmit;
  final Color accent;

  @override
  State<OpenExplanationWidget> createState() => _OpenExplanationWidgetState();
}

class _OpenExplanationWidgetState extends State<OpenExplanationWidget> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _c,
          enabled: widget.enabled,
          minLines: 4,
          maxLines: 8,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Opiszcie krok po kroku, co zrobicie…',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        SubmitButton(
          label: 'Wyślij Mistrzowi Gry',
          icon: Icons.send,
          accent: widget.accent,
          onPressed: widget.enabled && _c.text.trim().length >= 10
              ? () => widget.onSubmit(_c.text.trim(), _c.text.trim())
              : null,
        ),
      ],
    );
  }
}
