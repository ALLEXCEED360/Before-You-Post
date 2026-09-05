// Tests the redaction engine directly, with no device, no files and no
// isolate - the pixel logic is a pure function, so it can be checked the
// same way any other pure function is.
//
// The engine takes raw RGBA, which is what Flutter hands it after
// decoding. That is deliberate: it means the engine never has to
// understand a container format, so AVIF, HEIC, palette PNGs and anything
// else the platform can display all arrive here identically.
//
// Output is requested as PNG so assertions can compare exact pixel
// values. Asserting against a JPEG round-trip would be flaky.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:before_you_post/models/privacy_finding.dart';
import 'package:before_you_post/services/redaction_service.dart';

/// A 100x100 image: red everywhere, with a blue 20x20 square at (20,20).
/// The blue square is the thing we redact; the red is what must survive.
img.Image buildFixture() {
  final image = img.Image(width: 100, height: 100);
  img.fill(image, color: img.ColorRgb8(255, 0, 0));
  img.fillRect(
    image,
    x1: 20,
    y1: 20,
    x2: 39,
    y2: 39,
    color: img.ColorRgb8(0, 0, 255),
  );
  return image;
}

/// Runs the engine over an image, the way the app does.
img.Image run(img.Image source, List<RedactionInstruction> instructions) {
  final rgba = source
      .convert(numChannels: 4)
      .getBytes(order: img.ChannelOrder.rgba);

  return img.decodeImage(
    renderRedacted(
      rgba: Uint8List.fromList(rgba),
      width: source.width,
      height: source.height,
      asPng: true,
      instructions: instructions,
    ),
  )!;
}

RedactionInstruction squareAt(RedactionMethod method) => RedactionInstruction(
  left: 20,
  top: 20,
  width: 20,
  height: 20,
  method: method,
);

/// Reads one pixel as (r, g, b).
(int, int, int) pixel(img.Image image, int x, int y) {
  final p = image.getPixel(x, y);
  return (p.r.toInt(), p.g.toInt(), p.b.toInt());
}

void main() {
  test('blackout fills the region and leaves the rest untouched', () {
    final out = run(buildFixture(), [squareAt(RedactionMethod.blackout)]);

    expect(pixel(out, 30, 30), (0, 0, 0));

    // Corners far from the region keep their original colour. This is the
    // half of the assertion that catches an engine which redacts the
    // whole image, or lands the box in the wrong place entirely.
    expect(pixel(out, 90, 90), (255, 0, 0));
    expect(pixel(out, 5, 5), (255, 0, 0));
  });

  test('blur mixes content across an edge and leaves distant pixels', () {
    final out = run(buildFixture(), [squareAt(RedactionMethod.blur)]);

    // Sample the blue/red boundary. A blur must blend the two into
    // something that is neither.
    //
    // Note what this does NOT assert: that the centre of the square
    // changed. A solid colour blurred is still that solid colour - there
    // is no detail there to destroy - so checking the centre would pass
    // for a blur of any strength, including one far too weak to be
    // useful. Strength is pinned by the stripe test below instead.
    final edge = pixel(out, 39, 30);
    expect(edge, isNot((0, 0, 255)), reason: 'edge should not stay pure blue');
    expect(edge, isNot((255, 0, 0)), reason: 'edge should not stay pure red');

    expect(pixel(out, 90, 90), (255, 0, 0));
  });

  test('blur is strong enough to destroy text-sized detail', () {
    // Fine vertical stripes stand in for the strokes of text: a 20px-tall
    // band of hard black-on-white edges. A real screenshot showed a blur
    // that left phone numbers readable, so this pins the strength.
    final image = img.Image(width: 100, height: 100);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    for (var x = 20; x < 80; x += 4) {
      img.fillRect(
        image,
        x1: x,
        y1: 40,
        x2: x + 1,
        y2: 59,
        color: img.ColorRgb8(0, 0, 0),
      );
    }

    final out = run(image, [
      const RedactionInstruction(
        left: 20,
        top: 40,
        width: 60,
        height: 20,
        method: RedactionMethod.blur,
      ),
    ]);

    // Measure the surviving contrast across the middle of the band.
    var darkest = 255;
    var lightest = 0;
    for (var x = 25; x < 75; x++) {
      final value = out.getPixel(x, 50).r.toInt();
      darkest = darkest < value ? darkest : value;
      lightest = lightest > value ? lightest : value;
    }

    // Original contrast is the full 0-255 range. If the blur leaves most
    // of that intact, the strokes - and therefore the characters - are
    // still there.
    expect(
      lightest - darkest,
      lessThan(100),
      reason: 'blur left too much contrast; text would still be readable',
    );
  });

  test('pixelate produces uniform blocks', () {
    final out = run(buildFixture(), [squareAt(RedactionMethod.pixelate)]);

    // Neighbouring pixels inside one block must be identical - that is
    // what distinguishes pixelation from a blur.
    expect(pixel(out, 30, 30), pixel(out, 31, 30));
    expect(pixel(out, 90, 90), (255, 0, 0));
  });

  test('a region extending past the edge is clamped, not a crash', () {
    // Detectors do return boxes that overhang the image. Cropping outside
    // the buffer would throw.
    final out = run(buildFixture(), [
      const RedactionInstruction(
        left: 80,
        top: 80,
        width: 50,
        height: 50,
        method: RedactionMethod.blackout,
      ),
    ]);

    expect(out.width, 100);
    expect(out.height, 100);
    expect(pixel(out, 95, 95), (0, 0, 0));
  });

  test('a one-pixel region is handled without throwing', () {
    // ML Kit really does return boxes this small - a single character
    // picked out of a barcode caption, for instance.
    final out = run(buildFixture(), [
      const RedactionInstruction(
        left: 50,
        top: 50,
        width: 1,
        height: 1,
        method: RedactionMethod.pixelate,
      ),
    ]);

    expect(out.width, 100);
  });

  test('several regions and methods apply in one pass', () {
    final out = run(buildFixture(), [
      squareAt(RedactionMethod.blackout),
      const RedactionInstruction(
        left: 60,
        top: 60,
        width: 20,
        height: 20,
        method: RedactionMethod.pixelate,
      ),
    ]);

    expect(pixel(out, 30, 30), (0, 0, 0));
    expect(pixel(out, 5, 5), (255, 0, 0));
  });
}
