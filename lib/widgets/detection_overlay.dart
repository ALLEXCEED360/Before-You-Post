import 'package:flutter/material.dart';

import '../models/privacy_finding.dart';

/// Draws a box around each finding.
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
    this.debugTextBounds = const [],
  });

  final List<PrivacyFinding> findings;

  /// The ORIGINAL image dimensions in pixels.
  final Size imageSize;

  /// Every line OCR read, drawn faintly. A debugging aid: if a phone
  /// number is not flagged, this shows instantly whether OCR failed to
  /// read it or the rules failed to classify it. Two very different bugs.
  final List<Rect> debugTextBounds;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FindingBoxPainter(
        findings: findings,
        imageSize: imageSize,
        scheme: Theme.of(context).colorScheme,
        debugTextBounds: debugTextBounds,
      ),
    );
  }
}

class _FindingBoxPainter extends CustomPainter {
  _FindingBoxPainter({
    required this.findings,
    required this.imageSize,
    required this.scheme,
    required this.debugTextBounds,
  });

  final List<PrivacyFinding> findings;
  final Size imageSize;
  final ColorScheme scheme;
  final List<Rect> debugTextBounds;

  Color _colorFor(FindingType type) => switch (type) {
    FindingType.face => scheme.primary,
    FindingType.qrCode => scheme.tertiary,
    FindingType.manual => scheme.secondary,
    // Every text-derived risk shares the alarm colour.
    _ => scheme.error,
  };

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

    for (final finding in findings) {
      final rect = toScreen(finding.bounds);
      final color = _colorFor(finding.type);

      canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.18));
      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_FindingBoxPainter oldDelegate) {
    return oldDelegate.findings != findings ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.scheme != scheme ||
        oldDelegate.debugTextBounds != debugTextBounds;
  }
}
