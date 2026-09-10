import 'package:flutter/material.dart';

import '../../../domain/puzzle.dart';
import 'puzzle_view.dart';

/// Tap a left item, then a right item, to pair them.
class MatchingWidget extends StatefulWidget {
  const MatchingWidget({
    super.key,
    required this.puzzle,
    required this.enabled,
    required this.onSubmit,
    required this.accent,
  });

  final MatchingPuzzle puzzle;
  final bool enabled;
  final AnswerSubmit onSubmit;
  final Color accent;

  @override
  State<MatchingWidget> createState() => _MatchingWidgetState();
}

class _MatchingWidgetState extends State<MatchingWidget> {
  final Map<String, String> _pairs = {};
  String? _pendingLeft;

  static const _palette = [
    Color(0xFF22D3EE),
    Color(0xFFF472B6),
    Color(0xFFA3E635),
    Color(0xFFFBBF24),
    Color(0xFFC084FC),
    Color(0xFFFB923C),
  ];

  Color? _colorOfLeft(String l) {
    final i = widget.puzzle.leftItems.indexOf(l);
    return _pairs.containsKey(l) || _pendingLeft == l
        ? _palette[i % _palette.length]
        : null;
  }

  String? _leftOfRight(String r) {
    for (final e in _pairs.entries) {
      if (e.value == r) return e.key;
    }
    return null;
  }

  void _tapLeft(String l) {
    if (!widget.enabled) return;
    setState(() {
      if (_pendingLeft == l) {
        _pendingLeft = null;
      } else {
        _pendingLeft = l;
      }
    });
  }

  void _tapRight(String r) {
    if (!widget.enabled) return;
    setState(() {
      final l = _pendingLeft;
      if (l == null) {
        // unpair
        final owner = _leftOfRight(r);
        if (owner != null) _pairs.remove(owner);
        return;
      }
      final owner = _leftOfRight(r);
      if (owner != null) _pairs.remove(owner);
      _pairs[l] = r;
      _pendingLeft = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.puzzle;
    final complete = _pairs.length == p.leftItems.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _pendingLeft == null
              ? 'Dotknij element po lewej, potem pasujący po prawej.'
              : 'Teraz wybierz, do czego pasuje: „$_pendingLeft”.',
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: Colors.white54),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  for (final l in p.leftItems)
                    _Tile(
                      text: l,
                      color: _colorOfLeft(l),
                      selected: _pendingLeft == l,
                      onTap: () => _tapLeft(l),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                children: [
                  for (final r in p.rightItems)
                    _Tile(
                      text: r,
                      color: () {
                        final l = _leftOfRight(r);
                        return l == null ? null : _colorOfLeft(l);
                      }(),
                      selected: false,
                      onTap: () => _tapRight(r),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SubmitButton(
          label: 'Sprawdź dopasowania',
          accent: widget.accent,
          onPressed: widget.enabled && complete
              ? () => widget.onSubmit(
                    Map<String, String>.of(_pairs),
                    _pairs.entries.map((e) => '${e.key} ↔ ${e.value}').join('; '),
                  )
              : null,
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.text,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: color?.withValues(alpha: 0.18) ?? const Color(0xFF162032),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.all(10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? Colors.white : (color ?? Colors.white12),
                width: selected ? 2 : 1,
              ),
            ),
            child: Text(text, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.5)),
          ),
        ),
      ),
    );
  }
}
