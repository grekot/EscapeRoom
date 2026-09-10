import 'dart:io';
import 'dart:ui' as ui;

import 'package:escape_room/app/theme.dart';
import 'package:escape_room/domain/catalog.dart';
import 'package:escape_room/features/game/props/prop_painter.dart';
import 'package:escape_room/features/game/widgets/backdrop_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders every prop (idle + active) and every backdrop archetype into PNGs
/// so the artwork can be reviewed without a device. Files land in the system
/// temp dir (or PROPS_GALLERY_DIR); the test itself only checks they render.
void main() {
  testWidgets('props and backdrops gallery renders', (tester) async {
    final outDir = Directory(Platform.environment['PROPS_GALLERY_DIR'] ??
        Directory.systemTemp.path);
    final types = PropTypes.all.keys.toList();
    const cell = 120.0;
    final cols = 6;
    final rows = (types.length / cols).ceil();

    Widget grid(double active) => RepaintBoundary(
          child: Container(
            color: const Color(0xFF0F172A),
            width: cols * cell,
            height: rows * (cell + 18),
            child: Wrap(
              children: [
                for (var i = 0; i < types.length; i++)
                  SizedBox(
                    width: cell,
                    height: cell + 18,
                    child: Column(children: [
                      SizedBox(
                        width: cell - 16,
                        height: cell - 16,
                        child: CustomPaint(
                          painter: PropPainter(
                            type: types[i],
                            t: 0.37,
                            active: active,
                            accent: const Color(0xFF2DD4BF),
                            seed: i,
                          ),
                        ),
                      ),
                      Text(types[i],
                          style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ]),
                  ),
              ],
            ),
          ),
        );

    Future<void> snap(Widget w, String name) async {
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Center(child: RepaintBoundary(key: key, child: w)),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: name);
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await boundary.toImage(pixelRatio: 2);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        await File('${outDir.path}${Platform.pathSeparator}$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
      });
    }

    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await snap(grid(0), 'gallery_props_idle');
    await snap(grid(1), 'gallery_props_active');

    final backdrops = ['workshop', 'corridor', 'cavern', 'deck', 'reading_room'];
    await snap(
      RepaintBoundary(
        child: Wrap(
          children: [
            for (final b in backdrops)
              SizedBox(
                width: 320,
                height: 180,
                child: CustomPaint(
                  painter: BackdropPainter(
                    backdrop: b,
                    ambient: const Color(0xFF0E7490),
                    palette: ThemePalette.of(VisualTheme.ship),
                    t: 0.2,
                  ),
                ),
              ),
          ],
        ),
      ),
      'gallery_backdrops',
    );
  });
}
