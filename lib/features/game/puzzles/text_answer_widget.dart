import 'package:flutter/material.dart';

import '../../../domain/puzzle.dart';
import 'puzzle_view.dart';

class TextAnswerWidget extends StatefulWidget {
  const TextAnswerWidget({
    super.key,
    required this.puzzle,
    required this.enabled,
    required this.onSubmit,
    required this.accent,
  });

  final TextAnswerPuzzle puzzle;
  final bool enabled;
  final AnswerSubmit onSubmit;
  final Color accent;

  @override
  State<TextAnswerWidget> createState() => _TextAnswerWidgetState();
}

class _TextAnswerWidgetState extends State<TextAnswerWidget> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final t = _c.text.trim();
    if (t.isEmpty) return;
    widget.onSubmit(t, t);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _c,
          enabled: widget.enabled,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: 'Wpiszcie odpowiedź…',
            prefixIcon: Icon(Icons.edit, color: widget.accent),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        SubmitButton(
          label: 'Sprawdź',
          accent: widget.accent,
          onPressed: widget.enabled && _c.text.trim().isNotEmpty ? _submit : null,
        ),
      ],
    );
  }
}
