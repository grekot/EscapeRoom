import 'dart:math';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Procedural room illustration used when a stage has no AI image yet.
/// Each backdrop kind maps to one of a few archetypes drawn in perspective.
class BackdropPainter extends CustomPainter {
  BackdropPainter({
    required this.backdrop,
    required this.ambient,
    required this.palette,
    required this.t,
  });

  final String backdrop;
  final Color ambient;
  final ThemePalette palette;
  final double t;

  static String archetype(String b) => switch (b) {
        'workshop' || 'control_room' || 'engine_room' || 'generator_room' || 'cockpit' || 'kitchen' => 'machine',
        'corridor' || 'airlock' || 'bunker_hall' || 'dungeon' || 'vault' || 'cargo_hold' => 'corridor',
        'cavern' || 'underground_lake' || 'tomb' || 'sand_chamber' => 'cave',
        'deck' || 'observatory' || 'tower' || 'clearing' || 'garden' => 'open',
        _ => 'wooden', // reading_room, archive, cabin, hut, throne_hall
      };

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final base = Color.lerp(palette.top, ambient, 0.35)!;
    final dark = palette.bottom;
    switch (archetype(backdrop)) {
      case 'machine':
        _room(canvas, size, base, dark, wallStripes: true);
        _pipes(canvas, size, ambient);
      case 'corridor':
        _corridor(canvas, size, base, dark);
      case 'cave':
        _cave(canvas, size, base, dark);
      case 'open':
        _open(canvas, size, base, dark);
      default:
        _room(canvas, size, Color.lerp(const Color(0xFF3B2A1A), ambient, 0.25)!,
            const Color(0xFF1A110A), wood: true);
    }
    // vignette
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
          stops: const [0.55, 1],
        ).createShader(rect),
    );
  }

  void _room(Canvas canvas, Size s, Color base, Color dark,
      {bool wallStripes = false, bool wood = false}) {
    final w = s.width, h = s.height;
    final horizon = h * 0.62;
    // back wall
    canvas.drawRect(Rect.fromLTWH(0, 0, w, horizon),
        Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [dark, base]).createShader(Rect.fromLTWH(0, 0, w, horizon)));
    // floor
    final floor = Path()..addRect(Rect.fromLTWH(0, horizon, w, h - horizon));
    canvas.drawPath(floor, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(base, Colors.black, 0.35)!, dark]).createShader(Rect.fromLTWH(0, horizon, w, h - horizon)));
    // floor perspective lines
    final lp = Paint()..color = Colors.white.withValues(alpha: 0.06)..strokeWidth = 1;
    for (var i = -3; i <= 3; i++) {
      canvas.drawLine(Offset(w / 2 + i * w * 0.12, horizon), Offset(w / 2 + i * w * 0.45, h), lp);
    }
    for (var i = 1; i <= 4; i++) {
      final y = horizon + (h - horizon) * (i * i / 20);
      canvas.drawLine(Offset(0, y), Offset(w, y), lp);
    }
    // side walls
    final left = Path()..moveTo(0, 0)..lineTo(w * 0.12, h * 0.08)..lineTo(w * 0.12, horizon)..lineTo(0, h * 0.75)..close();
    final right = Path()..moveTo(w, 0)..lineTo(w * 0.88, h * 0.08)..lineTo(w * 0.88, horizon)..lineTo(w, h * 0.75)..close();
    canvas.drawPath(left, Paint()..color = Colors.black.withValues(alpha: 0.35));
    canvas.drawPath(right, Paint()..color = Colors.black.withValues(alpha: 0.25));
    if (wallStripes) {
      final sp = Paint()..color = Colors.white.withValues(alpha: 0.05)..strokeWidth = 2;
      for (var i = 1; i < 6; i++) {
        canvas.drawLine(Offset(w * 0.12 + i * w * 0.76 / 6, h * 0.08), Offset(w * 0.12 + i * w * 0.76 / 6, horizon), sp);
      }
      canvas.drawLine(Offset(w * 0.12, h * 0.3), Offset(w * 0.88, h * 0.3), sp);
    }
    if (wood) {
      final plank = Paint()..color = Colors.black.withValues(alpha: 0.18)..strokeWidth = 1.5;
      for (var i = 1; i < 9; i++) {
        canvas.drawLine(Offset(w * 0.12, h * 0.08 + i * (horizon - h * 0.08) / 9), Offset(w * 0.88, h * 0.08 + i * (horizon - h * 0.08) / 9), plank);
      }
      // a shelf with books
      final shelf = Rect.fromLTWH(w * 0.2, h * 0.32, w * 0.3, h * 0.02);
      canvas.drawRect(shelf, Paint()..color = const Color(0xFF5B3A1E));
      final rng = Random(3);
      var x = shelf.left + 4;
      while (x < shelf.right - 6) {
        final bw = 5.0 + rng.nextInt(6);
        final bh = h * (0.06 + rng.nextDouble() * 0.05);
        canvas.drawRect(Rect.fromLTWH(x, shelf.top - bh, bw, bh),
            Paint()..color = Color.lerp(ambient, Colors.black, rng.nextDouble() * 0.5)!);
        x += bw + 1.5;
      }
    }
    // ceiling light cone
    final cone = Path()..moveTo(w * 0.5, 0)..lineTo(w * 0.2, horizon)..lineTo(w * 0.8, horizon)..close();
    canvas.drawPath(cone, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [ambient.withValues(alpha: 0.25), ambient.withValues(alpha: 0)]).createShader(Rect.fromLTWH(0, 0, w, horizon)));
  }

  void _pipes(Canvas canvas, Size s, Color ambient) {
    final w = s.width, h = s.height;
    final p = Paint()..color = const Color(0xFF334155)..strokeWidth = h * 0.05..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.12, h * 0.14), Offset(w * 0.88, h * 0.14), p);
    canvas.drawLine(Offset(w * 0.3, h * 0.14), Offset(w * 0.3, h * 0.6), p);
    final hi = Paint()..color = Colors.white.withValues(alpha: 0.08)..strokeWidth = h * 0.015;
    canvas.drawLine(Offset(w * 0.12, h * 0.125), Offset(w * 0.88, h * 0.125), hi);
    // a console silhouette on the right
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.62, h * 0.42, w * 0.24, h * 0.2), const Radius.circular(3)), Paint()..color = const Color(0xFF1E293B));
    final led = Paint()..color = ambient.withValues(alpha: 0.5 + 0.5 * (0.5 + 0.5 * sin(t * 2 * pi)));
    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(Offset(w * 0.66 + i * w * 0.05, h * 0.47), 2, led);
    }
  }

  void _corridor(Canvas canvas, Size s, Color base, Color dark) {
    final w = s.width, h = s.height;
    final rect = Offset.zero & s;
    canvas.drawRect(rect, Paint()..color = dark);
    // receding frames
    for (var i = 6; i >= 0; i--) {
      final k = i / 6;
      final inset = Rect.fromLTRB(w * 0.42 * k, h * 0.38 * k, w - w * 0.42 * k, h - h * 0.28 * k);
      canvas.drawRect(inset, Paint()..color = Color.lerp(base, dark, k * 0.9)!);
      canvas.drawRect(inset, Paint()..color = Colors.white.withValues(alpha: 0.05)..style = PaintingStyle.stroke..strokeWidth = 2);
    }
    // far door glow
    final far = Rect.fromLTRB(w * 0.42, h * 0.38, w * 0.58, h * 0.72);
    canvas.drawRect(far, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [ambient.withValues(alpha: 0.6), ambient.withValues(alpha: 0.1)]).createShader(far));
    // floor lights
    for (var i = 0; i < 5; i++) {
      final k = i / 5;
      final y = h * 0.72 + (h * 0.28) * k * k;
      final on = sin(t * 2 * pi + i) > -0.2;
      canvas.drawCircle(Offset(w * 0.42 - w * 0.42 * k * 0.9, y), 2 + k * 2, Paint()..color = ambient.withValues(alpha: on ? 0.8 : 0.2));
      canvas.drawCircle(Offset(w * 0.58 + w * 0.42 * k * 0.9, y), 2 + k * 2, Paint()..color = ambient.withValues(alpha: on ? 0.8 : 0.2));
    }
  }

  void _cave(Canvas canvas, Size s, Color base, Color dark) {
    final w = s.width, h = s.height;
    final rect = Offset.zero & s;
    canvas.drawRect(rect, Paint()..shader = RadialGradient(center: const Alignment(0, 0.2), radius: 0.9, colors: [base, dark]).createShader(rect));
    final rng = Random(11);
    // stalactites
    final rock = Paint()..color = Colors.black.withValues(alpha: 0.55);
    var x = 0.0;
    while (x < w) {
      final wd = 14 + rng.nextDouble() * 30;
      final ht = h * (0.1 + rng.nextDouble() * 0.25);
      canvas.drawPath(Path()..moveTo(x, 0)..lineTo(x + wd, 0)..lineTo(x + wd / 2, ht)..close(), rock);
      x += wd * 0.8;
    }
    // ground
    canvas.drawPath(Path()..moveTo(0, h)..lineTo(0, h * 0.78)..quadraticBezierTo(w * 0.3, h * 0.7, w * 0.5, h * 0.78)..quadraticBezierTo(w * 0.75, h * 0.86, w, h * 0.76)..lineTo(w, h)..close(), Paint()..color = Colors.black.withValues(alpha: 0.5));
    // glowing crystals
    for (var i = 0; i < 5; i++) {
      final cx = w * (0.1 + rng.nextDouble() * 0.8);
      final cy = h * (0.55 + rng.nextDouble() * 0.25);
      final pulse = 0.5 + 0.5 * sin(t * 2 * pi + i);
      canvas.drawCircle(Offset(cx, cy), 10 + pulse * 6, Paint()..color = ambient.withValues(alpha: 0.25 * pulse)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      canvas.drawPath(Path()..moveTo(cx, cy - 12)..lineTo(cx + 5, cy)..lineTo(cx - 5, cy)..close(), Paint()..color = ambient.withValues(alpha: 0.8));
    }
  }

  void _open(Canvas canvas, Size s, Color base, Color dark) {
    final w = s.width, h = s.height;
    final sky = Rect.fromLTWH(0, 0, w, h * 0.7);
    canvas.drawRect(sky, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [dark, base]).createShader(sky));
    final rng = Random(5);
    final star = Paint()..color = Colors.white;
    for (var i = 0; i < 40; i++) {
      final sx = rng.nextDouble() * w, sy = rng.nextDouble() * h * 0.55;
      final tw = 0.5 + 0.5 * sin(t * 2 * pi * 2 + i);
      canvas.drawCircle(Offset(sx, sy), 0.6 + tw, star..color = Colors.white.withValues(alpha: 0.4 + 0.6 * tw));
    }
    // moon
    canvas.drawCircle(Offset(w * 0.78, h * 0.18), h * 0.08, Paint()..color = const Color(0xFFF1F5F9));
    canvas.drawCircle(Offset(w * 0.8, h * 0.17), h * 0.07, Paint()..color = Color.lerp(base, dark, 0.6)!);
    // ground / deck
    canvas.drawRect(Rect.fromLTWH(0, h * 0.7, w, h * 0.3), Paint()..color = Color.lerp(dark, Colors.black, 0.4)!);
    final lp = Paint()..color = Colors.white.withValues(alpha: 0.06);
    for (var i = 1; i < 6; i++) {
      canvas.drawLine(Offset(0, h * 0.7 + i * h * 0.05), Offset(w, h * 0.7 + i * h * 0.05), lp);
    }
    // distant silhouette
    canvas.drawPath(Path()..moveTo(0, h * 0.7)..lineTo(w * 0.15, h * 0.55)..lineTo(w * 0.3, h * 0.66)..lineTo(w * 0.5, h * 0.5)..lineTo(w * 0.7, h * 0.64)..lineTo(w * 0.85, h * 0.58)..lineTo(w, h * 0.7)..close(), Paint()..color = Colors.black.withValues(alpha: 0.6));
  }

  @override
  bool shouldRepaint(covariant BackdropPainter old) => old.t != t || old.backdrop != backdrop || old.ambient != ambient;
}
