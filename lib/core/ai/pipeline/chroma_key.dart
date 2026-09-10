import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Removes a flat magenta key colour from a generated sprite and returns a
/// PNG with an alpha channel, trimmed to the object's bounding box.
class ChromaKey {
  const ChromaKey._();

  /// Pixels closer than this (RGB distance) to the key are fully transparent.
  static const double _inner = 70;

  /// Pixels farther than this are fully opaque; in between they fade.
  static const double _outer = 150;

  static Uint8List cutOut(Uint8List pngOrJpeg) {
    final src = img.decodeImage(pngOrJpeg);
    if (src == null) return pngOrJpeg;
    final image = src.convert(numChannels: 4);
    final key = _estimateKey(image);

    var minX = image.width, minY = image.height, maxX = -1, maxY = -1;
    for (final p in image) {
      final d = _dist(p.r.toDouble(), p.g.toDouble(), p.b.toDouble(), key);
      if (d <= _inner) {
        p.a = 0;
        continue;
      }
      if (d < _outer) {
        final a = (d - _inner) / (_outer - _inner);
        p.a = (a * 255).round();
        // De-spill: pull the magenta tint out of edge pixels.
        final avg = (p.r + p.b) / 2;
        if (p.g < avg) {
          p.r = (p.r * a + avg * (1 - a)).round().clamp(0, 255);
          p.b = (p.b * a + avg * (1 - a)).round().clamp(0, 255);
          p.g = (p.g * a + avg * (1 - a)).round().clamp(0, 255);
        }
      }
      if (p.a > 10) {
        if (p.x < minX) minX = p.x;
        if (p.y < minY) minY = p.y;
        if (p.x > maxX) maxX = p.x;
        if (p.y > maxY) maxY = p.y;
      }
    }
    if (maxX < 0) return Uint8List.fromList(img.encodePng(image));
    final pad = 4;
    final crop = img.copyCrop(
      image,
      x: (minX - pad).clamp(0, image.width - 1),
      y: (minY - pad).clamp(0, image.height - 1),
      width: (maxX - minX + 1 + 2 * pad).clamp(1, image.width),
      height: (maxY - minY + 1 + 2 * pad).clamp(1, image.height),
    );
    return Uint8List.fromList(img.encodePng(crop));
  }

  /// The key is the average colour of the image border, which is expected to
  /// be the flat background even if the model drifted from pure magenta.
  static List<double> _estimateKey(img.Image im) {
    var r = 0.0, g = 0.0, b = 0.0, n = 0;
    void take(int x, int y) {
      final p = im.getPixel(x, y);
      r += p.r;
      g += p.g;
      b += p.b;
      n++;
    }
    final step = (im.width / 64).ceil().clamp(1, 64);
    for (var x = 0; x < im.width; x += step) {
      take(x, 0);
      take(x, im.height - 1);
    }
    for (var y = 0; y < im.height; y += step) {
      take(0, y);
      take(im.width - 1, y);
    }
    if (n == 0) return [255, 0, 255];
    final key = [r / n, g / n, b / n];
    // If the border is not magenta-ish, fall back to pure magenta.
    if (key[1] > 120 || key[0] < 120 || key[2] < 120) return [255, 0, 255];
    return key;
  }

  static double _dist(double r, double g, double b, List<double> k) {
    final dr = r - k[0], dg = g - k[1], db = b - k[2];
    return _sqrt(dr * dr + dg * dg + db * db);
  }

  static double _sqrt(double v) {
    if (v <= 0) return 0;
    var x = v;
    for (var i = 0; i < 20; i++) {
      x = 0.5 * (x + v / x);
    }
    return x;
  }
}
