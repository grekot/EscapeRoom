import 'package:flutter/material.dart';

import '../../../domain/puzzle.dart';
import 'puzzle_view.dart';

class PinCodeWidget extends StatefulWidget {
  const PinCodeWidget({
    super.key,
    required this.puzzle,
    required this.enabled,
    required this.onSubmit,
    required this.accent,
  });

  final PinCodePuzzle puzzle;
  final bool enabled;
  final AnswerSubmit onSubmit;
  final Color accent;

  @override
  State<PinCodeWidget> createState() => _PinCodeWidgetState();
}

class _PinCodeWidgetState extends State<PinCodeWidget> {
  String _code = '';

  void _tap(String d) {
    if (!widget.enabled || _code.length >= widget.puzzle.codeLength) return;
    setState(() => _code += d);
  }

  void _back() {
    if (_code.isEmpty) return;
    setState(() => _code = _code.substring(0, _code.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.puzzle;
    final mono = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (p.clues.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.terminal, size: 18, color: widget.accent),
                    const SizedBox(width: 8),
                    Text('Analiza błędnych kodów',
                        style: Theme.of(context).textTheme.labelLarge),
                  ]),
                  const SizedBox(height: 8),
                  for (final c in p.clues)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.code.split('').join(' '), style: mono?.copyWith(color: widget.accent)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(c.text ?? c.describe(),
                                style: Theme.of(context).textTheme.bodyMedium),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 14),
        // Display
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0F1A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: widget.accent.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < p.codeLength; i++)
                Container(
                  width: 40,
                  height: 52,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                            color: i < _code.length
                                ? widget.accent
                                : Colors.white24,
                            width: 2)),
                  ),
                  child: Text(
                    i < _code.length ? _code[i] : '',
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: widget.accent),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Keypad
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['⌫', '0', 'OK'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                for (final k in row)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _Key(
                        label: k,
                        accent: widget.accent,
                        primary: k == 'OK',
                        enabled: widget.enabled &&
                            (k != 'OK' || _code.length == p.codeLength),
                        onTap: () {
                          if (k == '⌫') {
                            _back();
                          } else if (k == 'OK') {
                            widget.onSubmit(_code, _code);
                            setState(() => _code = '');
                          } else {
                            _tap(k);
                          }
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.label,
    required this.accent,
    required this.enabled,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final Color accent;
  final bool enabled;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary
          ? (enabled ? accent : accent.withValues(alpha: 0.25))
          : const Color(0xFF1B2638),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 52,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: primary ? 18 : 22,
                fontWeight: FontWeight.w600,
                color: primary ? Colors.black : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
