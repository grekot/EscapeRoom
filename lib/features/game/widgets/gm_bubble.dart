import 'package:flutter/material.dart';

/// Game master speech bubble with a typewriter effect.
class GmBubble extends StatelessWidget {
  const GmBubble({
    super.key,
    required this.text,
    required this.mood,
    required this.accent,
    this.busyLabel,
    this.fromAi = false,
  });

  final String text;
  final String mood;
  final Color accent;
  final String? busyLabel;
  final bool fromAi;

  Color get _moodColor => switch (mood) {
        'encouraging' => const Color(0xFFFBBF24),
        'tense' => const Color(0xFFF87171),
        'triumphant' => const Color(0xFF4ADE80),
        _ => accent,
      };

  IconData get _moodIcon => switch (mood) {
        'encouraging' => Icons.emoji_objects,
        'tense' => Icons.priority_high,
        'triumphant' => Icons.celebration,
        _ => Icons.record_voice_over,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111A2B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _moodColor.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _moodColor.withValues(alpha: 0.18),
              border: Border.all(color: _moodColor.withValues(alpha: 0.6)),
            ),
            child: Icon(_moodIcon, size: 20, color: _moodColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Mistrz Gry',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: _moodColor, fontWeight: FontWeight.w700)),
                    if (fromAi) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.auto_awesome, size: 12, color: _moodColor.withValues(alpha: 0.8)),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                if (busyLabel != null)
                  Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _moodColor),
                      ),
                      const SizedBox(width: 10),
                      Text(busyLabel!,
                          style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic)),
                    ],
                  )
                else
                  TypewriterText(
                    key: ValueKey(text),
                    text: text,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TypewriterText extends StatefulWidget {
  const TypewriterText({
    super.key,
    required this.text,
    this.style,
    this.charsPerSecond = 55,
  });

  final String text;
  final TextStyle? style;
  final int charsPerSecond;

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    final ms = (widget.text.length / widget.charsPerSecond * 1000)
        .clamp(200, 6000)
        .toInt();
    _c = AnimationController(vsync: this, duration: Duration(milliseconds: ms))
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _c.value = 1,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final n = (widget.text.length * _c.value).round();
          return Text(widget.text.substring(0, n), style: widget.style);
        },
      ),
    );
  }
}
