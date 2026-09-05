import 'dart:math' as math;
import 'dart:ui';

/// Builds a rectangle from the two ends of a drag.
///
/// Two jobs, both easy to get wrong by hand:
///
///  * **Normalising.** People drag in all four directions. Dragging right
///    to left produces a start point to the RIGHT of the end point, and
///    `Rect.fromLTRB` with left > right yields a negative-width rectangle
///    that silently draws nothing and redacts nothing.
///  * **Clamping.** A drag that runs off the edge of the photo would
///    otherwise produce bounds outside the image, which the redaction
///    engine has to defend against all over again.
///
/// Both points are in ORIGINAL image pixels, like every bounds in this app.
Rect rectFromDrag(Offset start, Offset end, Size imageSize) {
  final left = math.min(start.dx, end.dx).clamp(0.0, imageSize.width);
  final right = math.max(start.dx, end.dx).clamp(0.0, imageSize.width);
  final top = math.min(start.dy, end.dy).clamp(0.0, imageSize.height);
  final bottom = math.max(start.dy, end.dy).clamp(0.0, imageSize.height);

  return Rect.fromLTRB(left, top, right, bottom);
}

/// Converts a point on screen back into image pixels.
///
/// The exact inverse of what DetectionOverlay does when it draws. It is a
/// single scale factor and no offset only because the image is laid out
/// inside an AspectRatio, so there is no letterboxing to subtract.
Offset screenToImage(Offset point, Size displayedSize, Size imageSize) {
  if (displayedSize.isEmpty) return Offset.zero;

  return Offset(
    point.dx * imageSize.width / displayedSize.width,
    point.dy * imageSize.height / displayedSize.height,
  );
}
