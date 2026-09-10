import 'package:escape_room/core/ai/pipeline/chroma_key.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('cuts a magenta background out and crops to the object', () {
    // 64x64 magenta canvas with a 20x20 brown box in the middle.
    final src = img.Image(width: 64, height: 64, numChannels: 3);
    img.fill(src, color: img.ColorRgb8(255, 0, 255));
    img.fillRect(src, x1: 22, y1: 22, x2: 41, y2: 41, color: img.ColorRgb8(120, 80, 40));
    final out = ChromaKey.cutOut(img.encodePng(src));
    final res = img.decodePng(out)!;
    expect(res.numChannels, 4);
    // cropped to box + 4px padding
    expect(res.width, 28);
    expect(res.height, 28);
    expect(res.getPixel(14, 14).a, 255);
    expect(res.getPixel(0, 0).a, 0);
    expect(res.getPixel(14, 14).r, 120);
  });

  test('tolerates a slightly off-key background', () {
    final src = img.Image(width: 32, height: 32, numChannels: 3);
    img.fill(src, color: img.ColorRgb8(240, 20, 235)); // drifted magenta
    img.fillRect(src, x1: 10, y1: 10, x2: 20, y2: 20, color: img.ColorRgb8(30, 200, 60));
    final res = img.decodePng(ChromaKey.cutOut(img.encodePng(src)))!;
    expect(res.getPixel(0, 0).a, 0);
    expect(res.getPixel(res.width ~/ 2, res.height ~/ 2).a, 255);
  });
}
