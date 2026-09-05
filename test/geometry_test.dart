// Pure maths, no device. The manual-redaction drag is exactly the kind of
// code that looks obviously correct and is wrong in one of four
// directions, so it is worth pinning all four.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:before_you_post/utils/geometry.dart';

const image = Size(1000, 800);

void main() {
  group('rectFromDrag', () {
    test('a top-left to bottom-right drag', () {
      expect(
        rectFromDrag(const Offset(100, 100), const Offset(300, 250), image),
        const Rect.fromLTRB(100, 100, 300, 250),
      );
    });

    test('normalises a drag in every other direction', () {
      const expected = Rect.fromLTRB(100, 100, 300, 250);

      // Right to left, bottom to top, and both at once. Without
      // normalising, these produce negative width or height - a rectangle
      // that draws nothing and redacts nothing, with no error anywhere.
      expect(
        rectFromDrag(const Offset(300, 100), const Offset(100, 250), image),
        expected,
      );
      expect(
        rectFromDrag(const Offset(100, 250), const Offset(300, 100), image),
        expected,
      );
      expect(
        rectFromDrag(const Offset(300, 250), const Offset(100, 100), image),
        expected,
      );
    });

    test('clamps a drag that runs off the edge of the photo', () {
      final rect = rectFromDrag(
        const Offset(-50, -20),
        const Offset(1200, 900),
        image,
      );

      expect(rect, const Rect.fromLTRB(0, 0, 1000, 800));
    });

    test('a tap with no movement is an empty rect, not a negative one', () {
      final rect = rectFromDrag(
        const Offset(500, 400),
        const Offset(500, 400),
        image,
      );

      expect(rect.width, 0);
      expect(rect.height, 0);
      expect(rect.isEmpty, isTrue);
    });
  });

  group('screenToImage', () {
    test('scales a point back into image pixels', () {
      // A 400x320 widget showing a 1000x800 image: 2.5x in both axes.
      expect(
        screenToImage(const Offset(40, 32), const Size(400, 320), image),
        const Offset(100, 80),
      );
    });

    test('is the inverse of the overlay scale factor', () {
      const displayed = Size(400, 320);
      const pointInImage = Offset(250, 600);

      // Forward: image -> screen, the way DetectionOverlay draws.
      final onScreen = Offset(
        pointInImage.dx * displayed.width / image.width,
        pointInImage.dy * displayed.height / image.height,
      );

      expect(screenToImage(onScreen, displayed, image), pointInImage);
    });

    test('a zero-sized widget does not divide by zero', () {
      expect(
        screenToImage(const Offset(10, 10), Size.zero, image),
        Offset.zero,
      );
    });
  });
}
