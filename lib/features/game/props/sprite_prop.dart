import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../domain/game_spec.dart';
import 'prop_painter.dart';

/// An AI-generated cut-out sprite with a generic animation.
class SpriteProp extends StatelessWidget {
  const SpriteProp({
    super.key,
    required this.prop,
    required this.t,
    required this.active,
    required this.accent,
    required this.seed,
  });

  final SceneProp prop;
  final double t;
  final double active;
  final Color accent;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final image = _image();
    if (image == null) {
      // Sprite not generated (no key / failure): a glowing crystal placeholder.
      return CustomPaint(
        painter: PropPainter(type: 'crystal', t: t, active: active, accent: accent, seed: seed),
      );
    }
    final phase = t * 2 * pi + seed;
    Offset offset = Offset.zero;
    double angle = 0;
    double scale = 1;
    switch (prop.animation) {
      case 'bob':
        offset = Offset(0, sin(phase) * 3);
      case 'pulse':
        scale = 1 + 0.04 * sin(phase * 1.5);
      case 'swing':
        angle = sin(phase) * 0.12;
      case 'spin':
        angle = t * 2 * pi;
      default:
        break;
    }
    scale *= 1 + 0.08 * active;
    return Transform.translate(
      offset: offset,
      child: Transform.rotate(
        angle: angle,
        child: Transform.scale(
          scale: scale,
          child: DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: [
                if (active > 0.05 || prop.animation == 'pulse')
                  BoxShadow(
                    color: accent.withValues(
                        alpha: (0.15 + 0.5 * active + (prop.animation == 'pulse' ? 0.15 * (0.5 + 0.5 * sin(phase * 1.5)) : 0))
                            .clamp(0, 0.8)),
                    blurRadius: 24 + 20 * active,
                    spreadRadius: 2,
                  ),
              ],
              shape: BoxShape.circle,
            ),
            child: image,
          ),
        ),
      ),
    );
  }

  Widget? _image() {
    final path = prop.spritePath;
    if (path != null && File(path).existsSync()) {
      return Image.file(File(path), fit: BoxFit.contain, filterQuality: FilterQuality.medium);
    }
    if (prop.spriteAsset != null) {
      return Image.asset(prop.spriteAsset!, fit: BoxFit.contain, filterQuality: FilterQuality.medium);
    }
    return null;
  }
}
