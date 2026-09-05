import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A small crop of the image, showing exactly what a finding covers.
///
/// With several faces in one photo, a list of identical "Face" rows is
/// guesswork - you have to toggle one and watch the picture to find out
/// which is which. Showing the actual pixels removes the guessing.
///
/// Draws straight from the already-decoded image, so there is no crop,
/// no re-encode and no extra memory beyond the image already on screen.
class RegionThumbnail extends StatelessWidget {
  const RegionThumbnail({
    super.key,
    required this.image,
    required this.bounds,
    this.size = 44,
  });

  final ui.Image image;

  /// In original image pixels, like every bounds in this app.
  final Rect bounds;

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RegionPainter(
            image: image,
            bounds: bounds,
            background: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ),
      ),
    );
  }
}

class _RegionPainter extends CustomPainter {
  _RegionPainter({
    required this.image,
    required this.bounds,
    required this.background,
  });

  final ui.Image image;
  final Rect bounds;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);

    if (bounds.isEmpty) return;

    // A SQUARE source region centred on the finding, sized from the
    // finding's SHORTER side.
    //
    // Sizing from the longer side seems more natural and is wrong: a
    // phone-number box is a wide thin strip, so a square that covers its
    // width also swallows the three findings above and below it, and the
    // thumbnail ends up showing everything except the thing it labels.
    // Sizing from the shorter side keeps the crop inside the finding -
    // a face gets useful context, a text strip gets a zoomed piece of
    // itself, and neither borrows its neighbours.
    final side = math.max(bounds.shortestSide * 1.5, 12.0);
    final centre = bounds.center;

    // For a wide strip, anchor the crop at its START rather than its
    // middle. The first characters of a phone number or an address
    // identify it; the middle two characters do not.
    final anchorX = bounds.width > bounds.height * 1.5
        ? bounds.left + side / 2
        : centre.dx;

    var left = anchorX - side / 2;
    var top = centre.dy - side / 2;

    // Keep the square inside the image rather than sampling past its edge.
    left = left.clamp(0.0, math.max(0.0, image.width - side));
    top = top.clamp(0.0, math.max(0.0, image.height - side));

    final src = Rect.fromLTWH(
      left,
      top,
      math.min(side, image.width.toDouble()),
      math.min(side, image.height.toDouble()),
    );

    canvas.drawImageRect(
      image,
      src,
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_RegionPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.bounds != bounds ||
      oldDelegate.background != background;
}
