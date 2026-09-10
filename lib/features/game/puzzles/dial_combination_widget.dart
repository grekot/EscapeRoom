import 'package:flutter/material.dart';

import '../../../domain/puzzle.dart';
import 'puzzle_view.dart';

class DialCombinationWidget extends StatefulWidget {
  const DialCombinationWidget({
    super.key,
    required this.puzzle,
    required this.enabled,
    required this.onSubmit,
    required this.accent,
  });

  final DialCombinationPuzzle puzzle;
  final bool enabled;
  final AnswerSubmit onSubmit;
  final Color accent;

  @override
  State<DialCombinationWidget> createState() => _DialCombinationWidgetState();
}

class _DialCombinationWidgetState extends State<DialCombinationWidget> {
  late final List<int> _values = [for (final d in widget.puzzle.dials) d.min];

  @override
  Widget build(BuildContext context) {
    final p = widget.puzzle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < p.dials.length; i++)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text(p.dials[i].label,
                              style: Theme.of(context).textTheme.titleSmall)),
                      IconButton(
                        onPressed: widget.enabled && _values[i] > p.dials[i].min
                            ? () => setState(() => _values[i]--)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Container(
                        width: 56,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A0F1A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: widget.accent.withValues(alpha: 0.5)),
                        ),
                        child: Text('${_values[i]}',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: widget.accent)),
                      ),
                      IconButton(
                        onPressed: widget.enabled && _values[i] < p.dials[i].max
                            ? () => setState(() => _values[i]++)
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  if (p.dials[i].max - p.dials[i].min <= 100)
                    Slider(
                      value: _values[i].toDouble(),
                      min: p.dials[i].min.toDouble(),
                      max: p.dials[i].max.toDouble(),
                      divisions: (p.dials[i].max - p.dials[i].min).clamp(1, 1000),
                      activeColor: widget.accent,
                      onChanged: widget.enabled
                          ? (v) => setState(() => _values[i] = v.round())
                          : null,
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 4),
        SubmitButton(
          label: 'Ustaw',
          icon: Icons.tune,
          accent: widget.accent,
          onPressed: widget.enabled
              ? () => widget.onSubmit(
                    List<int>.of(_values),
                    [
                      for (var i = 0; i < p.dials.length; i++)
                        '${p.dials[i].label}=${_values[i]}'
                    ].join(', '),
                  )
              : null,
        ),
      ],
    );
  }
}
