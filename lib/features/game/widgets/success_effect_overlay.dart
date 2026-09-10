import 'dart:math';

import 'package:flutter/material.dart';

import '../../../domain/catalog.dart';

/// Full-screen, short celebratory animation for a solved stage.
class SuccessEffectOverlay extends StatefulWidget {
  const SuccessEffectOverlay({
    super.key,
    required this.effect,
    required this.accent,
    required this.onDone,
  });

  final SuccessEffect effect;
  final Color accent;
  final VoidCallback onDone;

  @override
  State<SuccessEffectOverlay> createState() => _SuccessEffectOverlayState();
}

class _SuccessEffectOverlayState extends State<SuccessEffectOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  final _rng = Random(7);

  @override
  void initState() {
    super.initState();
    if (widget.effect == SuccessEffect.none) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone());
      return;
    }
    _c.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.effect == SuccessEffect.none) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_c.value);
          final fade = t < 0.8 ? 1.0 : (1 - (t - 0.8) / 0.2);
          return Opacity(
            opacity: fade.clamp(0, 1),
            child: switch (widget.effect) {
              SuccessEffect.lightsOn => ColoredBox(
                  color: Colors.white.withValues(alpha: (1 - t) * 0.85)),
              SuccessEffect.doorSlide => Stack(children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: 0.5 * (1 - t),
                      heightFactor: 1,
                      child: ColoredBox(color: const Color(0xFF1F2937)),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FractionallySizedBox(
                      widthFactor: 0.5 * (1 - t),
                      heightFactor: 1,
                      child: ColoredBox(color: const Color(0xFF1F2937)),
                    ),
                  ),
                ]),
              SuccessEffect.safeOpen => Center(
                  child: Transform.rotate(
                    angle: t * pi * 2,
                    child: Transform.scale(
                      scale: 1 + t * 1.5,
                      child: Icon(Icons.lock_open, size: 110, color: widget.accent),
                    ),
                  ),
                ),
              SuccessEffect.gearsTurn => Stack(children: [
                  for (var i = 0; i < 5; i++)
                    Align(
                      alignment: Alignment(-0.8 + i * 0.4, -0.3 + (i.isEven ? 0.4 : -0.2)),
                      child: Transform.rotate(
                        angle: t * pi * (i.isEven ? 2 : -2),
                        child: Icon(Icons.settings,
                            size: 70 + i * 8.0,
                            color: widget.accent.withValues(alpha: 0.8)),
                      ),
                    ),
                ]),
              SuccessEffect.sparkle => Stack(children: [
                  for (var i = 0; i < 24; i++)
                    Align(
                      alignment: Alignment(
                          _rng.nextDouble() * 2 - 1, _rng.nextDouble() * 2 - 1),
                      child: Transform.scale(
                        scale: sin(min(1, t * 1.3 + i * 0.03) * pi) * 1.6,
                        child: Icon(Icons.star,
                            size: 22 + (i % 4) * 8.0,
                            color: i.isEven ? widget.accent : Colors.amber),
                      ),
                    ),
                ]),
              SuccessEffect.none => const SizedBox.shrink(),
            },
          );
        },
      ),
    );
  }
}
