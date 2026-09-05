import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/privacy_finding.dart';
import '../theme/app_theme.dart';
import 'finding_style.dart';

/// Draws a numbered box around each finding.
///
/// This widget must be laid out at EXACTLY the displayed size of the image,
/// with the image's aspect ratio. The parent guarantees that with an
/// AspectRatio widget, which is what removes letterboxing from the maths:
/// there is no black-bar offset to subtract, only a single scale factor.
class DetectionOverlay extends StatelessWidget {
  const DetectionOverlay({
    super.key,
    required this.findings,
    required this.imageSize,
    this.highlightedId,
    this.draftRect,
    this.debugTextBounds = const [],
  });

  final List<PrivacyFinding> findings;

  /// The ORIGINAL image dimensions in pixels.
  final Size imageSize;

  /// The finding currently being looked at, drawn emphasised so it can be
  /// picked out of a crowd of identical boxes.
  final String? highlightedId;

  /// The rectangle being dragged right now, in original image pixels.
  /// Drawn live so the user can see what they are about to hide.
  final Rect? draftRect;

  /// Every line OCR read, drawn faintly. A debugging aid: if a phone
  /// number is not flagged, this shows instantly whether OCR failed to
  /// read it or the rules failed to classify it. Two very different bugs.
  final List<Rect> debugTextBounds;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // RepaintBoundary stops the box layer from repainting the photo
    // underneath it every time a switch is toggled.
    return RepaintBoundary(
      child: CustomPaint(
        painter: _FindingBoxPainter(
          findings: findings,
          imageSize: imageSize,
          scheme: scheme,
          riskColor: context.semantics.risk,
          highlightedId: highlightedId,
          draftRect: draftRect,
          debugTextBounds: debugTextBounds,
        ),
      ),
    );
  }
}

class _FindingBoxPainter extends CustomPainter {
  _FindingBoxPainter({
    required this.findings,
    required this.imageSize,
    required this.scheme,
    required this.riskColor,
    required this.highlightedId,
    required this.draftRect,
    required this.debugTextBounds,
  });

  final List<PrivacyFinding> findings;
  final Size imageSize;
  final ColorScheme scheme;
  final Color riskColor;
  final String? highlightedId;
  final Rect? draftRect;
  final List<Rect> debugTextBounds;

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize.isEmpty) return;

    // 'size' is the displayed size of the image. Because the parent forced
    // the image's own aspect ratio, scaleX and scaleY are equal - but we
    // compute both so a future layout change fails visibly rather than
    // silently skewing every box.
    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;

    Rect toScreen(Rect r) => Rect.fromLTRB(
      r.left * scaleX,
      r.top * scaleY,
      r.right * scaleX,
      r.bottom * scaleY,
    );

    // Debug layer first, so real findings draw on top of it.
    final debugStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.45);

    for (final bounds in debugTextBounds) {
      canvas.drawRect(toScreen(bounds), debugStroke);
    }

    final hasFocus = highlightedId != null;

    for (final (index, finding) in findings.indexed) {
      final rect = toScreen(finding.bounds);
      final color = colorForFinding(finding.type, scheme, riskColor);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
      final isHighlighted = finding.id == highlightedId;

      // When one finding is being pointed at, everything else recedes.
      // Drawing the chosen box a little thicker was not enough to pick it
      // out of twenty faces; dimming its neighbours is what makes it read.
      final fade = hasFocus && !isHighlighted ? 0.28 : 1.0;

      if (finding.selected) {
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = color.withValues(
              alpha: (isHighlighted ? 0.34 : 0.20) * fade,
            ),
        );
        canvas.drawRRect(
          rrect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = isHighlighted ? 6 : 3
            ..color = color.withValues(alpha: fade),
        );
      } else {
        // Kept, not hidden. Still drawn, so the user can see what the
        // scan found and change their mind - but visibly de-emphasised.
        canvas.drawRRect(
          rrect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = isHighlighted ? 4 : 1.5
            ..color = color.withValues(
              alpha: (isHighlighted ? 1.0 : 0.45) * fade,
            ),
        );
      }

      // A white ring outside the box, so the highlight survives being
      // drawn over a bright or busy part of the photo.
      if (isHighlighted) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.inflate(3), const Radius.circular(9)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white.withValues(alpha: 0.85),
        );
      }

      _drawBadge(canvas, size, rect, index + 1, color, isHighlighted, fade);
    }

    // The rectangle currently under the finger, drawn on top of
    // everything so it is never hidden behind an existing box.
    final draft = draftRect;
    if (draft != null && !draft.isEmpty) {
      final rect = toScreen(draft);
      final color = scheme.secondary;

      canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.25));
      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color,
      );
    }
  }

  /// The number that ties this box to its row in the list.
  ///
  /// With five faces in one photo, "Face" five times tells you nothing.
  /// A number on both the box and the card is what makes them one thing.
  void _drawBadge(
    Canvas canvas,
    Size size,
    Rect rect,
    int number,
    Color color,
    bool isHighlighted,
    double fade,
  ) {
    final radius = isHighlighted ? 16.0 : 11.0;
    const gap = 3.0;

    // Keep the badge OUTSIDE the box it labels. Sitting it on the corner
    // covered the first character of every flagged phone number, email
    // and address - the badge hid the very thing it was pointing at.
    //
    // Prefer the left edge, because findings that stack vertically (lines
    // of text) have room beside them but not above. Fall back to above,
    // then inside, when the box is against an edge of the image.
    final Offset centre;
    if (rect.left - radius - gap >= 0) {
      centre = Offset(rect.left - radius - gap, rect.center.dy);
    } else if (rect.top - radius - gap >= 0) {
      centre = Offset(rect.left + radius, rect.top - radius - gap);
    } else {
      centre = Offset(rect.left + radius + gap, rect.top + radius + gap);
    }

    // Never let it fall off the edge of the canvas.
    final clamped = Offset(
      centre.dx.clamp(radius, math.max(radius, size.width - radius)),
      centre.dy.clamp(radius, math.max(radius, size.height - radius)),
    );

    canvas.drawCircle(
      clamped,
      radius,
      Paint()..color = color.withValues(alpha: fade),
    );
    final ink = onFindingColor(color);

    canvas.drawCircle(
      clamped,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = ink.withValues(alpha: 0.9 * fade),
    );

    final painter = TextPainter(
      text: TextSpan(
        text: '$number',
        style: TextStyle(
          color: ink.withValues(alpha: fade),
          fontSize: radius,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(
      canvas,
      clamped - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_FindingBoxPainter oldDelegate) {
    return oldDelegate.findings != findings ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.scheme != scheme ||
        oldDelegate.riskColor != riskColor ||
        oldDelegate.highlightedId != highlightedId ||
        oldDelegate.draftRect != draftRect ||
        oldDelegate.debugTextBounds != debugTextBounds;
  }
}
