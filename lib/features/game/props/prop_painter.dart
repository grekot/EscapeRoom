import 'dart:math';

import 'package:flutter/material.dart';

/// Draws one animated prop. [t] is a looping 0..1 clock shared by the scene,
/// [active] is 0..1 (0 = idle/closed, 1 = activated/open) and animates when
/// the stage is solved or the player pokes the prop.
class PropPainter extends CustomPainter {
  PropPainter({
    required this.type,
    required this.t,
    required this.active,
    required this.accent,
    required this.seed,
  });

  final String type;
  final double t;
  final double active;
  final Color accent;
  final int seed;

  static const _metal = Color(0xFF3B4556);
  static const _metalDark = Color(0xFF1F2733);
  static const _metalLight = Color(0xFF6B7789);

  @override
  void paint(Canvas canvas, Size size) {
    switch (type) {
      case 'lever':
        _lever(canvas, size);
      case 'switch':
        _switch(canvas, size);
      case 'pinpad':
        _pinpad(canvas, size);
      case 'gauge':
        _gauge(canvas, size);
      case 'lamp':
        _lamp(canvas, size);
      case 'gear':
        _gear(canvas, size);
      case 'steam':
        _steam(canvas, size);
      case 'sparks':
        _sparks(canvas, size);
      case 'door':
        _door(canvas, size);
      case 'screen':
        _screen(canvas, size);
      case 'pendulum':
        _pendulum(canvas, size);
      case 'valve':
        _valve(canvas, size);
      case 'candle':
        _candle(canvas, size);
      case 'window':
        _window(canvas, size);
      case 'radar':
        _radar(canvas, size);
      case 'chest':
        _chest(canvas, size);
      case 'crystal':
        _crystal(canvas, size);
      case 'fan':
        _fan(canvas, size);
      case 'scroll':
        _scroll(canvas, size);
      case 'potion':
        _potion(canvas, size);
      case 'book':
        _book(canvas, size);
      default:
        _lamp(canvas, size);
    }
  }

  // ---------- helpers ----------

  double _noise(double phase) => sin(t * 2 * pi * 3 + phase + seed) * 0.5 +
      sin(t * 2 * pi * 7 + phase * 1.7 + seed) * 0.5;

  Paint _fill(Color c) => Paint()..color = c;

  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..strokeWidth = w
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  void _glow(Canvas canvas, Offset c, double r, Color color, double alpha) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = color.withValues(alpha: alpha.clamp(0, 1))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.6),
    );
  }

  void _plate(Canvas canvas, Rect r, {double radius = 6}) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [_metalLight, _metal, _metalDark],
        ).createShader(r),
    );
    canvas.drawRRect(rr, _stroke(Colors.black.withValues(alpha: 0.6), 1.2));
    // screws
    final sp = _fill(_metalDark);
    for (final o in [
      r.topLeft + const Offset(5, 5),
      r.topRight + const Offset(-5, 5),
      r.bottomLeft + const Offset(5, -5),
      r.bottomRight + const Offset(-5, -5),
    ]) {
      canvas.drawCircle(o, 1.6, sp);
    }
  }

  // ---------- props ----------

  void _lever(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    _plate(canvas, Rect.fromLTWH(w * 0.15, h * 0.55, w * 0.7, h * 0.4));
    final pivot = Offset(w * 0.5, h * 0.72);
    // slot
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: pivot, width: w * 0.5, height: h * 0.1),
          const Radius.circular(4)),
      _fill(Colors.black.withValues(alpha: 0.7)),
    );
    // arm: down-left when idle, up-right when active
    final angle = lerpDouble(2.4, 0.7, Curves.easeInOutBack.transform(active))!;
    final len = h * 0.6;
    final tip = pivot + Offset(cos(angle) * len, -sin(angle) * len);
    canvas.drawLine(pivot, tip, _stroke(_metalLight, w * 0.09));
    canvas.drawLine(pivot, tip, _stroke(_metal, w * 0.05));
    canvas.drawCircle(pivot, w * 0.08, _fill(_metalDark));
    // knob
    final knob = Color.lerp(const Color(0xFFB91C1C), accent, active)!;
    canvas.drawCircle(tip, w * 0.13, _fill(knob));
    canvas.drawCircle(tip + Offset(-w * 0.04, -w * 0.04), w * 0.05,
        _fill(Colors.white.withValues(alpha: 0.35)));
    if (active > 0.5) _glow(canvas, tip, w * 0.2, accent, (active - 0.5) * 0.8);
  }

  void _switch(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    _plate(canvas, Rect.fromLTWH(w * 0.1, h * 0.15, w * 0.8, h * 0.7));
    final body = Rect.fromLTWH(w * 0.3, h * 0.25, w * 0.4, h * 0.5);
    canvas.drawRRect(RRect.fromRectAndRadius(body, const Radius.circular(5)),
        _fill(Colors.black.withValues(alpha: 0.75)));
    // rocker
    final on = Curves.easeInOut.transform(active);
    final rocker = Rect.fromLTWH(
        w * 0.33, lerpDouble(h * 0.47, h * 0.27, on)!, w * 0.34, h * 0.26);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rocker, const Radius.circular(4)),
      Paint()
        ..shader = LinearGradient(
          begin: on > 0.5 ? Alignment.bottomCenter : Alignment.topCenter,
          end: on > 0.5 ? Alignment.topCenter : Alignment.bottomCenter,
          colors: const [Color(0xFFCBD5E1), Color(0xFF64748B)],
        ).createShader(rocker),
    );
    // LED
    final led = Offset(w * 0.8, h * 0.5);
    final ledColor = Color.lerp(const Color(0xFF7F1D1D), accent, on)!;
    canvas.drawCircle(led, w * 0.05, _fill(ledColor));
    _glow(canvas, led, w * 0.1, ledColor, 0.5 + 0.3 * on);
  }

  void _pinpad(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    _plate(canvas, Rect.fromLTWH(w * 0.1, h * 0.05, w * 0.8, h * 0.9), radius: 8);
    // display
    final disp = Rect.fromLTWH(w * 0.2, h * 0.12, w * 0.6, h * 0.16);
    canvas.drawRRect(RRect.fromRectAndRadius(disp, const Radius.circular(3)),
        _fill(const Color(0xFF0A1A12)));
    final blink = (sin(t * 2 * pi * 2 + seed) > 0) || active > 0.5;
    if (blink) {
      final txt = Paint()..color = accent.withValues(alpha: 0.9);
      for (var i = 0; i < 3; i++) {
        canvas.drawRect(
            Rect.fromLTWH(disp.left + 6 + i * (disp.width - 12) / 3,
                disp.center.dy - 2, (disp.width - 12) / 3 - 4, 4),
            txt);
      }
    }
    // keys 3x4
    final kw = w * 0.6 / 3, kh = h * 0.6 / 4;
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 3; c++) {
        final k = Rect.fromLTWH(w * 0.2 + c * kw + 2, h * 0.33 + r * kh + 2, kw - 4, kh - 4);
        canvas.drawRRect(RRect.fromRectAndRadius(k, const Radius.circular(2)),
            _fill(const Color(0xFF111827)));
        canvas.drawCircle(k.center, 1.3, _fill(Colors.white24));
      }
    }
    // status LED
    final led = Offset(w * 0.5, h * 0.965 - 4);
    final ledColor = Color.lerp(const Color(0xFFDC2626), const Color(0xFF22C55E), active)!;
    final pulse = active > 0.5 ? 1.0 : (sin(t * 2 * pi * 1.5 + seed) > 0.3 ? 1.0 : 0.3);
    canvas.drawCircle(led, 2.5, _fill(ledColor.withValues(alpha: pulse)));
    _glow(canvas, led, 6, ledColor, 0.5 * pulse);
  }

  void _gauge(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final c = Offset(w / 2, h * 0.55);
    final r = min(w, h) * 0.42;
    canvas.drawCircle(c, r + 3, _fill(_metalDark));
    canvas.drawCircle(c, r, _fill(const Color(0xFFF1F5F9)));
    // zones
    final rect = Rect.fromCircle(center: c, radius: r * 0.82);
    canvas.drawArc(rect, pi * 0.75, pi * 1.0, false,
        _stroke(const Color(0xFF16A34A).withValues(alpha: 0.5), r * 0.14));
    canvas.drawArc(rect, pi * 1.75, pi * 0.5, false,
        _stroke(const Color(0xFFDC2626).withValues(alpha: 0.6), r * 0.14));
    for (var i = 0; i <= 12; i++) {
      final a = pi * 0.75 + i * (pi * 1.5 / 12);
      final p1 = c + Offset(cos(a), sin(a)) * r * 0.7;
      final p2 = c + Offset(cos(a), sin(a)) * r * (i.isEven ? 0.58 : 0.63);
      canvas.drawLine(p1, p2, _stroke(_metalDark, i.isEven ? 1.6 : 1));
    }
    // needle: idle jitters in the red, active settles in the green
    final idleAngle = pi * 1.75 + 0.35 + _noise(1.0) * 0.18;
    final activeAngle = pi * 0.75 + 0.8 + _noise(2.0) * 0.03;
    final a = lerpDouble(idleAngle, activeAngle, Curves.easeOutBack.transform(active))!;
    final tip = c + Offset(cos(a), sin(a)) * r * 0.75;
    canvas.drawLine(c, tip, _stroke(const Color(0xFFB91C1C), 2.2));
    canvas.drawCircle(c, r * 0.1, _fill(_metalDark));
    canvas.drawCircle(c, r, _stroke(_metalLight, 2));
  }

  void _lamp(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final c = Offset(w / 2, h * 0.45);
    final r = min(w, h) * 0.22;
    final pulse = 0.55 + 0.45 * (0.5 + 0.5 * sin(t * 2 * pi * 1.2 + seed));
    final a = lerpDouble(pulse * 0.6, 1.0, active)!;
    _glow(canvas, c, r * 2.6, accent, a * 0.7);
    canvas.drawCircle(c, r, _fill(Color.lerp(accent, Colors.white, 0.35 * a)!));
    canvas.drawCircle(c + Offset(-r * 0.3, -r * 0.3), r * 0.28,
        _fill(Colors.white.withValues(alpha: 0.55)));
    // bracket
    canvas.drawRect(Rect.fromLTWH(w * 0.42, h * 0.62, w * 0.16, h * 0.3), _fill(_metal));
    canvas.drawRect(Rect.fromLTWH(w * 0.3, h * 0.88, w * 0.4, h * 0.08), _fill(_metalDark));
  }

  void _gearShape(Canvas canvas, Offset c, double r, double angle, Color color) {
    final path = Path();
    const teeth = 10;
    for (var i = 0; i < teeth * 2; i++) {
      final a = angle + i * pi / teeth;
      final rr = i.isEven ? r : r * 0.78;
      final p = c + Offset(cos(a), sin(a)) * rr;
      final a2 = angle + (i + 0.5) * pi / teeth;
      final p2 = c + Offset(cos(a2), sin(a2)) * rr;
      if (i == 0) path.moveTo(p.dx, p.dy);
      path.lineTo(p.dx, p.dy);
      path.lineTo(p2.dx, p2.dy);
    }
    path.close();
    canvas.drawPath(path, _fill(color));
    canvas.drawCircle(c, r * 0.3, _fill(_metalDark));
    canvas.drawCircle(c, r * 0.55, _stroke(_metalDark, r * 0.08));
  }

  void _gear(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final speed = lerpDouble(0.15, 1.0, active)!;
    final a = t * 2 * pi * speed;
    final r1 = min(w, h) * 0.27, r2 = r1 * 0.66;
    _gearShape(canvas, Offset(w * 0.3, h * 0.48), r1, a, const Color(0xFFB08D57));
    _gearShape(canvas, Offset(w * 0.3 + r1 + r2 * 0.9, h * 0.48 + r1 * 0.4), r2,
        -a * r1 / r2 + 0.3, const Color(0xFF8A6D3B));
  }

  void _steam(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    // pipe
    canvas.drawRect(Rect.fromLTWH(w * 0.4, h * 0.6, w * 0.2, h * 0.4), _fill(_metal));
    canvas.drawRect(Rect.fromLTWH(w * 0.34, h * 0.56, w * 0.32, h * 0.08), _fill(_metalDark));
    final rng = Random(seed);
    final intensity = lerpDouble(1.0, 0.3, active)!;
    for (var i = 0; i < 7; i++) {
      final phase = rng.nextDouble();
      final life = (t * 0.8 + phase) % 1.0;
      final x = w * 0.5 + sin(life * 6 + i) * w * 0.12 * life + (rng.nextDouble() - 0.5) * w * 0.1;
      final y = h * 0.58 - life * h * 0.55;
      final r = w * (0.06 + life * 0.14);
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color = Colors.white.withValues(alpha: (1 - life) * 0.35 * intensity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.7),
      );
    }
  }

  void _sparks(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    // frayed cable
    final p = Path()
      ..moveTo(0, h * 0.5)
      ..cubicTo(w * 0.3, h * 0.3, w * 0.4, h * 0.75, w * 0.62, h * 0.5);
    canvas.drawPath(p, _stroke(const Color(0xFF111827), w * 0.09));
    canvas.drawPath(p, _stroke(const Color(0xFFB45309), w * 0.03));
    final origin = Offset(w * 0.62, h * 0.5);
    // bursts fade out when active (power restored)
    final burst = sin(t * 2 * pi * 4 + seed) > 0.4 ? 1.0 : 0.0;
    final intensity = burst * (1 - active);
    if (intensity > 0) {
      final rng = Random(seed + (t * 40).floor());
      for (var i = 0; i < 9; i++) {
        final a = rng.nextDouble() * 2 * pi;
        final len = w * (0.1 + rng.nextDouble() * 0.3);
        final end = origin + Offset(cos(a), sin(a)) * len;
        canvas.drawLine(origin, end,
            _stroke(i.isEven ? const Color(0xFFFDE68A) : const Color(0xFFF59E0B), 1.4));
      }
      _glow(canvas, origin, w * 0.15, const Color(0xFFFDE68A), 0.8);
    } else if (active > 0.5) {
      canvas.drawCircle(origin, w * 0.05, _fill(_metalLight));
    }
  }

  void _door(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final frame = Rect.fromLTWH(w * 0.08, h * 0.04, w * 0.84, h * 0.94);
    // dark opening with light when opened
    canvas.drawRect(frame, _fill(Color.lerp(const Color(0xFF020617), accent, active * 0.45)!));
    if (active > 0.05) _glow(canvas, frame.center, w * 0.3, Colors.white, active * 0.35);
    final open = Curves.easeInOutCubic.transform(active);
    final half = frame.width / 2;
    final leftDoor = Rect.fromLTWH(frame.left - half * open, frame.top, half, frame.height);
    final rightDoor = Rect.fromLTWH(frame.center.dx + half * open, frame.top, half, frame.height);
    for (final d in [leftDoor, rightDoor]) {
      canvas.save();
      canvas.clipRect(frame);
      canvas.drawRect(
        d,
        Paint()
          ..shader = const LinearGradient(colors: [_metalLight, _metal, _metalDark])
              .createShader(d),
      );
      canvas.drawRect(d.deflate(w * 0.05), _stroke(_metalDark, 2));
      // rivets
      for (var i = 0; i < 4; i++) {
        canvas.drawCircle(Offset(d.left + w * 0.09, d.top + h * 0.15 + i * h * 0.22), 2, _fill(_metalDark));
        canvas.drawCircle(Offset(d.right - w * 0.09, d.top + h * 0.15 + i * h * 0.22), 2, _fill(_metalDark));
      }
      canvas.restore();
    }
    canvas.drawRect(frame, _stroke(_metalDark, 3));
  }

  void _screen(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    _plate(canvas, Rect.fromLTWH(0, 0, w, h * 0.85), radius: 5);
    final scr = Rect.fromLTWH(w * 0.08, h * 0.08, w * 0.84, h * 0.66);
    canvas.drawRRect(RRect.fromRectAndRadius(scr, const Radius.circular(3)), _fill(const Color(0xFF031611)));
    final rng = Random(seed);
    final lines = 6;
    final scroll = (t * 2) % 1.0;
    final lineH = scr.height / lines;
    final ink = Color.lerp(const Color(0xFF34D399), accent, active)!;
    canvas.save();
    canvas.clipRect(scr);
    for (var i = -1; i < lines; i++) {
      final y = scr.top + (i + scroll) * lineH + lineH * 0.35;
      final len = scr.width * (0.3 + rng.nextDouble() * 0.6);
      canvas.drawRect(Rect.fromLTWH(scr.left + 4, y, len, lineH * 0.3),
          _fill(ink.withValues(alpha: 0.75)));
    }
    canvas.restore();
    if (sin(t * 2 * pi * 4) > 0) {
      canvas.drawRect(Rect.fromLTWH(scr.left + 4, scr.bottom - lineH * 0.55, 5, lineH * 0.35), _fill(ink));
    }
    // stand
    canvas.drawRect(Rect.fromLTWH(w * 0.42, h * 0.85, w * 0.16, h * 0.1), _fill(_metalDark));
    canvas.drawRect(Rect.fromLTWH(w * 0.25, h * 0.94, w * 0.5, h * 0.06), _fill(_metal));
  }

  void _pendulum(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final pivot = Offset(w / 2, h * 0.06);
    final swing = sin(t * 2 * pi * 2 + seed) * 0.5 * (1 - active * 0.7);
    final len = h * 0.8;
    final bob = pivot + Offset(sin(swing) * len, cos(swing) * len);
    canvas.drawLine(pivot, bob, _stroke(const Color(0xFFD4AF37), 2.5));
    canvas.drawCircle(bob, w * 0.14, _fill(const Color(0xFFD4AF37)));
    canvas.drawCircle(bob + Offset(-w * 0.04, -w * 0.04), w * 0.05,
        _fill(Colors.white.withValues(alpha: 0.4)));
    canvas.drawCircle(pivot, 3, _fill(_metalDark));
  }

  void _valve(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    // pipe behind
    canvas.drawRect(Rect.fromLTWH(0, h * 0.62, w, h * 0.16), _fill(_metal));
    canvas.drawRect(Rect.fromLTWH(w * 0.42, h * 0.3, w * 0.16, h * 0.35), _fill(_metalDark));
    final c = Offset(w / 2, h * 0.3);
    final r = min(w, h) * 0.28;
    final a = t * 2 * pi * lerpDouble(0.12, 0.8, active)!;
    canvas.drawCircle(c, r, _stroke(const Color(0xFFB91C1C), r * 0.22));
    for (var i = 0; i < 4; i++) {
      final ang = a + i * pi / 2;
      canvas.drawLine(c, c + Offset(cos(ang), sin(ang)) * r, _stroke(const Color(0xFF991B1B), r * 0.16));
    }
    canvas.drawCircle(c, r * 0.22, _fill(_metalLight));
  }

  void _candle(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final body = Rect.fromLTWH(w * 0.38, h * 0.45, w * 0.24, h * 0.5);
    canvas.drawRRect(RRect.fromRectAndRadius(body, const Radius.circular(3)),
        _fill(const Color(0xFFF5F5DC)));
    canvas.drawRect(Rect.fromLTWH(w * 0.3, h * 0.92, w * 0.4, h * 0.08), _fill(const Color(0xFF8B5E3C)));
    final flick = _noise(0.5);
    final tip = Offset(w * 0.5 + flick * w * 0.05, h * 0.12 - flick.abs() * h * 0.06);
    final base = Offset(w * 0.5, h * 0.44);
    _glow(canvas, base + Offset(0, -h * 0.12), w * 0.35, const Color(0xFFFBBF24), 0.55 + flick.abs() * 0.2);
    final flame = Path()
      ..moveTo(base.dx - w * 0.09, base.dy)
      ..quadraticBezierTo(tip.dx - w * 0.12, base.dy - h * 0.15, tip.dx, tip.dy)
      ..quadraticBezierTo(tip.dx + w * 0.12, base.dy - h * 0.15, base.dx + w * 0.09, base.dy)
      ..close();
    canvas.drawPath(flame, _fill(const Color(0xFFF97316)));
    final inner = Path()
      ..moveTo(base.dx - w * 0.045, base.dy)
      ..quadraticBezierTo(tip.dx - w * 0.05, base.dy - h * 0.1, tip.dx, base.dy - h * 0.2)
      ..quadraticBezierTo(tip.dx + w * 0.05, base.dy - h * 0.1, base.dx + w * 0.045, base.dy)
      ..close();
    canvas.drawPath(inner, _fill(const Color(0xFFFDE68A)));
  }

  void _window(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final frame = Rect.fromLTWH(0, 0, w, h);
    final flash = (sin(t * 2 * pi * 3 + seed) > 0.93 || sin(t * 2 * pi * 3.7 + seed * 2) > 0.96) ? 1.0 : 0.0;
    final sky = Color.lerp(const Color(0xFF0B1B36), const Color(0xFFCBD5E1), flash * 0.8)!;
    canvas.drawRect(frame, _fill(sky));
    if (flash > 0) {
      final bolt = Path()
        ..moveTo(w * 0.55, 0)
        ..lineTo(w * 0.45, h * 0.35)
        ..lineTo(w * 0.55, h * 0.4)
        ..lineTo(w * 0.42, h * 0.8);
      canvas.drawPath(bolt, _stroke(Colors.white, 2));
    }
    // rain
    final rng = Random(seed);
    for (var i = 0; i < 24; i++) {
      final x0 = rng.nextDouble() * w;
      final phase = rng.nextDouble();
      final y0 = ((t * 2.5 + phase) % 1.0) * h;
      canvas.drawLine(Offset(x0, y0), Offset(x0 - 3, y0 + h * 0.08),
          _stroke(Colors.white.withValues(alpha: 0.35), 1));
    }
    // frame bars
    canvas.drawRect(frame, _stroke(const Color(0xFF3F2A14), 4));
    canvas.drawLine(Offset(w / 2, 0), Offset(w / 2, h), _stroke(const Color(0xFF3F2A14), 3));
    canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2), _stroke(const Color(0xFF3F2A14), 3));
  }

  void _radar(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final c = Offset(w / 2, h / 2);
    final r = min(w, h) * 0.46;
    canvas.drawCircle(c, r + 3, _fill(_metalDark));
    canvas.drawCircle(c, r, _fill(const Color(0xFF031611)));
    final ink = const Color(0xFF34D399);
    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(c, r * i / 3, _stroke(ink.withValues(alpha: 0.35), 1));
    }
    canvas.drawLine(c - Offset(r, 0), c + Offset(r, 0), _stroke(ink.withValues(alpha: 0.3), 1));
    canvas.drawLine(c - Offset(0, r), c + Offset(0, r), _stroke(ink.withValues(alpha: 0.3), 1));
    final a = t * 2 * pi;
    final sweep = Path()
      ..moveTo(c.dx, c.dy)
      ..arcTo(Rect.fromCircle(center: c, radius: r), a - 0.6, 0.6, false)
      ..close();
    canvas.drawPath(
      sweep,
      Paint()
        ..shader = SweepGradient(
          startAngle: a - 0.6,
          endAngle: a,
          colors: [ink.withValues(alpha: 0), ink.withValues(alpha: 0.6)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // blips
    final rng = Random(seed);
    for (var i = 0; i < 3; i++) {
      final ba = rng.nextDouble() * 2 * pi;
      final br = r * (0.3 + rng.nextDouble() * 0.6);
      final age = ((a - ba) % (2 * pi)) / (2 * pi);
      final p = c + Offset(cos(ba), sin(ba)) * br;
      canvas.drawCircle(p, 2.5, _fill((active > 0.5 ? accent : ink).withValues(alpha: (1 - age).clamp(0.1, 1))));
    }
  }

  void _chest(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final body = Rect.fromLTWH(w * 0.1, h * 0.45, w * 0.8, h * 0.5);
    canvas.drawRRect(RRect.fromRectAndRadius(body, const Radius.circular(4)), _fill(const Color(0xFF6B3F1D)));
    for (final x in [w * 0.28, w * 0.72]) {
      canvas.drawRect(Rect.fromLTWH(x - w * 0.03, body.top, w * 0.06, body.height), _fill(const Color(0xFFB08D57)));
    }
    // lid rotates open
    final open = Curves.easeOutBack.transform(active) * 0.75;
    canvas.save();
    canvas.translate(w * 0.1, h * 0.45);
    canvas.rotate(-open);
    final lid = Rect.fromLTWH(0, -h * 0.3, w * 0.8, h * 0.3);
    canvas.drawRRect(RRect.fromRectAndRadius(lid, const Radius.circular(6)), _fill(const Color(0xFF7C4A22)));
    canvas.drawRect(Rect.fromLTWH(0, -h * 0.05, w * 0.8, h * 0.05), _fill(const Color(0xFFB08D57)));
    canvas.restore();
    if (active > 0.2) {
      _glow(canvas, Offset(w * 0.5, h * 0.45), w * 0.3, const Color(0xFFFDE68A), (active - 0.2) * 0.9);
    }
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.44, h * 0.42, w * 0.12, h * 0.16), const Radius.circular(2)),
        _fill(const Color(0xFFD4AF37)));
  }

  void _crystal(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final pulse = 0.5 + 0.5 * sin(t * 2 * pi * 1.5 + seed);
    final c = Offset(w / 2, h * 0.5);
    _glow(canvas, c, w * 0.45, accent, 0.4 + 0.4 * max(pulse, active));
    final path = Path()
      ..moveTo(w * 0.5, h * 0.05)
      ..lineTo(w * 0.75, h * 0.4)
      ..lineTo(w * 0.62, h * 0.95)
      ..lineTo(w * 0.38, h * 0.95)
      ..lineTo(w * 0.25, h * 0.4)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withValues(alpha: 0.9), accent, Color.lerp(accent, Colors.black, 0.4)!],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    canvas.drawLine(Offset(w * 0.5, h * 0.05), Offset(w * 0.45, h * 0.95), _stroke(Colors.white.withValues(alpha: 0.5), 1));
  }

  void _fan(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final c = Offset(w / 2, h / 2);
    final r = min(w, h) * 0.46;
    canvas.drawCircle(c, r, _fill(_metalDark));
    canvas.drawCircle(c, r - 3, _fill(const Color(0xFF0F172A)));
    final a = t * 2 * pi * lerpDouble(0.6, 2.5, active)!;
    for (var i = 0; i < 4; i++) {
      final ang = a + i * pi / 2;
      final blade = Path()
        ..moveTo(c.dx, c.dy)
        ..quadraticBezierTo(c.dx + cos(ang - 0.35) * r * 0.9, c.dy + sin(ang - 0.35) * r * 0.9,
            c.dx + cos(ang) * r * 0.85, c.dy + sin(ang) * r * 0.85)
        ..quadraticBezierTo(c.dx + cos(ang + 0.35) * r * 0.9, c.dy + sin(ang + 0.35) * r * 0.9, c.dx, c.dy);
      canvas.drawPath(blade, _fill(_metalLight.withValues(alpha: 0.85)));
    }
    canvas.drawCircle(c, r * 0.18, _fill(_metal));
    // grille
    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(c, r * i / 3.2, _stroke(_metalDark.withValues(alpha: 0.8), 1.5));
    }
  }

  void _scroll(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    // Rolled at rest, unrolls when active.
    final open = Curves.easeOutCubic.transform(active);
    final bodyH = lerpDouble(h * 0.28, h * 0.78, open)!;
    final top = h * 0.5 - bodyH / 2;
    final paper = Rect.fromLTWH(w * 0.14, top, w * 0.72, bodyH);
    final parchment = Color.lerp(const Color(0xFFE8D5A8), const Color(0xFFFFF1C9), active)!;
    if (active > 0.3) _glow(canvas, paper.center, w * 0.4, const Color(0xFFFDE68A), (active - 0.3) * 0.5);
    canvas.drawRect(paper, _fill(parchment));
    canvas.drawRect(paper, _stroke(const Color(0xFF8B6B3E), 1.5));
    // text lines
    final ink = Paint()..color = const Color(0xFF6B4F2A).withValues(alpha: 0.75);
    final rng = Random(seed);
    var y = paper.top + 10;
    while (y < paper.bottom - 8) {
      final len = paper.width * (0.45 + rng.nextDouble() * 0.4);
      canvas.drawRect(Rect.fromLTWH(paper.left + 8, y, len, 2.2), ink);
      y += 7;
    }
    // rollers
    for (final ry in [paper.top, paper.bottom]) {
      final roll = Rect.fromCenter(center: Offset(w * 0.5, ry), width: w * 0.86, height: h * 0.11);
      canvas.drawRRect(
        RRect.fromRectAndRadius(roll, Radius.circular(h * 0.055)),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFD9BE8C), Color(0xFF8B6B3E)],
          ).createShader(roll),
      );
      canvas.drawCircle(Offset(roll.left, ry), h * 0.055, _fill(const Color(0xFF5B3F1E)));
      canvas.drawCircle(Offset(roll.right, ry), h * 0.055, _fill(const Color(0xFF5B3F1E)));
    }
  }

  void _potion(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final liquid = Color.lerp(const Color(0xFF7C3AED), accent, active)!;
    // flask: neck + round body
    final body = Path()
      ..moveTo(w * 0.42, h * 0.08)
      ..lineTo(w * 0.42, h * 0.38)
      ..cubicTo(w * 0.12, h * 0.5, w * 0.12, h * 0.95, w * 0.5, h * 0.95)
      ..cubicTo(w * 0.88, h * 0.95, w * 0.88, h * 0.5, w * 0.58, h * 0.38)
      ..lineTo(w * 0.58, h * 0.08)
      ..close();
    canvas.save();
    canvas.clipPath(body);
    // liquid with sloshing surface
    final level = h * (0.58 + 0.02 * _noise(0.3));
    canvas.drawRect(Rect.fromLTWH(0, level, w, h), _fill(liquid.withValues(alpha: 0.85)));
    // bubbles
    final rng = Random(seed);
    for (var i = 0; i < 6; i++) {
      final phase = rng.nextDouble();
      final life = (t * 1.3 + phase) % 1.0;
      final bx = w * (0.3 + rng.nextDouble() * 0.4) + sin(life * 8 + i) * 3;
      final by = h * 0.95 - life * (h * 0.95 - level);
      canvas.drawCircle(Offset(bx, by), 1.5 + rng.nextDouble() * 2.5,
          _fill(Colors.white.withValues(alpha: 0.5 * (1 - life))));
    }
    canvas.restore();
    _glow(canvas, Offset(w * 0.5, h * 0.72), w * 0.35, liquid, 0.25 + 0.25 * active);
    // glass
    canvas.drawPath(body, _fill(Colors.white.withValues(alpha: 0.08)));
    canvas.drawPath(body, _stroke(Colors.white.withValues(alpha: 0.6), 1.6));
    // highlight
    canvas.drawLine(Offset(w * 0.3, h * 0.55), Offset(w * 0.24, h * 0.8),
        _stroke(Colors.white.withValues(alpha: 0.35), 2));
    // cork
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.4, h * 0.02, w * 0.2, h * 0.1), const Radius.circular(2)),
        _fill(const Color(0xFF8B5E3C)));
  }

  void _book(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    // cover
    final cover = Rect.fromLTWH(w * 0.06, h * 0.25, w * 0.88, h * 0.55);
    canvas.drawRRect(RRect.fromRectAndRadius(cover, const Radius.circular(3)), _fill(const Color(0xFF6B2D2D)));
    // pages (two halves)
    final left = Rect.fromLTWH(w * 0.1, h * 0.28, w * 0.39, h * 0.49);
    final right = Rect.fromLTWH(w * 0.51, h * 0.28, w * 0.39, h * 0.49);
    final page = Color.lerp(const Color(0xFFF3E9D2), const Color(0xFFFFF7DC), active)!;
    canvas.drawRect(left, _fill(page));
    canvas.drawRect(right, _fill(page));
    final ink = Paint()..color = const Color(0xFF3F3A2E).withValues(alpha: 0.6);
    final rng = Random(seed);
    for (final r in [left, right]) {
      var y = r.top + 7;
      while (y < r.bottom - 6) {
        canvas.drawRect(Rect.fromLTWH(r.left + 5, y, r.width * (0.5 + rng.nextDouble() * 0.4), 1.8), ink);
        y += 6;
      }
    }
    // turning page
    final flip = ((t * 0.5) % 1.0);
    final ang = flip * pi;
    final pw = right.width * cos(ang).abs();
    final flipping = Rect.fromLTWH(
        ang < pi / 2 ? right.left : right.left - pw, right.top, pw, right.height);
    canvas.drawRect(flipping, _fill(page.withValues(alpha: 0.9)));
    canvas.drawRect(flipping, _stroke(const Color(0xFFB9AD8F), 1));
    // spine
    canvas.drawLine(Offset(w * 0.5, cover.top), Offset(w * 0.5, cover.bottom), _stroke(const Color(0xFF3F1A1A), 2));
    if (active > 0.3) _glow(canvas, Offset(w * 0.5, h * 0.5), w * 0.35, const Color(0xFFFDE68A), (active - 0.3) * 0.5);
  }

  @override
  bool shouldRepaint(covariant PropPainter old) =>
      old.t != t || old.active != active || old.type != type || old.accent != accent;
}

double? lerpDouble(num a, num b, double t) => a + (b - a) * t;
