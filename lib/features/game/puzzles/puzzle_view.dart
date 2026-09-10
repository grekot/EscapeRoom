import 'package:flutter/material.dart';

import '../../../domain/puzzle.dart';
import 'dial_combination_widget.dart';
import 'matching_widget.dart';
import 'multiple_choice_widget.dart';
import 'open_explanation_widget.dart';
import 'pin_code_widget.dart';
import 'sequence_order_widget.dart';
import 'text_answer_widget.dart';
import 'toggle_grid_widget.dart';

/// Called with the typed answer and its human-readable form.
typedef AnswerSubmit = void Function(Object answer, String display);

/// Dispatches a [Puzzle] to its interactive widget.
class PuzzleView extends StatelessWidget {
  const PuzzleView({
    super.key,
    required this.puzzle,
    required this.enabled,
    required this.onSubmit,
    required this.accent,
  });

  final Puzzle puzzle;
  final bool enabled;
  final AnswerSubmit onSubmit;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final body = switch (puzzle) {
      SequenceOrderPuzzle p => SequenceOrderWidget(
          key: ValueKey(p), puzzle: p, enabled: enabled, onSubmit: onSubmit, accent: accent),
      PinCodePuzzle p => PinCodeWidget(
          key: ValueKey(p), puzzle: p, enabled: enabled, onSubmit: onSubmit, accent: accent),
      MultipleChoicePuzzle p => MultipleChoiceWidget(
          key: ValueKey(p), puzzle: p, enabled: enabled, onSubmit: onSubmit, accent: accent),
      TextAnswerPuzzle p => TextAnswerWidget(
          key: ValueKey(p), puzzle: p, enabled: enabled, onSubmit: onSubmit, accent: accent),
      MatchingPuzzle p => MatchingWidget(
          key: ValueKey(p), puzzle: p, enabled: enabled, onSubmit: onSubmit, accent: accent),
      ToggleGridPuzzle p => ToggleGridWidget(
          key: ValueKey(p), puzzle: p, enabled: enabled, onSubmit: onSubmit, accent: accent),
      DialCombinationPuzzle p => DialCombinationWidget(
          key: ValueKey(p), puzzle: p, enabled: enabled, onSubmit: onSubmit, accent: accent),
      OpenExplanationPuzzle p => OpenExplanationWidget(
          key: ValueKey(p), puzzle: p, enabled: enabled, onSubmit: onSubmit, accent: accent),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          puzzle.prompt,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
        ),
        const SizedBox(height: 14),
        body,
      ],
    );
  }
}

/// Shared "submit" button look.
class SubmitButton extends StatelessWidget {
  const SubmitButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.accent,
    this.icon = Icons.check,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.black,
        disabledBackgroundColor: accent.withValues(alpha: 0.25),
      ),
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
