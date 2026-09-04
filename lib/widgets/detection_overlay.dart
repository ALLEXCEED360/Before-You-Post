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
  });

  final List<PrivacyFinding> findings;

  /// The ORIGINAL image dimensions in pixels.
  final Size imageSize;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FindingBoxPainter(
        findings: findings,
        imageSize: imageSize,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _FindingBoxPainter extends CustomPainter {
  _FindingBoxPainter({
    required this.findings,
    required this.imageSize,
    required this.color,
  });

  final List<PrivacyFinding> findings;
  final Size imageSize;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize.isEmpty) return;

    // 'size' is the displayed size of the image. Because the parent forced
    // the image's own aspect ratio, scaleX and scaleY are equal - but we
    // compute both so a future layout change fails visibly rather than
    // silently skewing every box.
    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = color;

    final fill = Paint()..color = color.withValues(alpha: 0.15);

    for (final finding in findings) {
      final rect = Rect.fromLTRB(
        finding.bounds.left * scaleX,
        finding.bounds.top * scaleY,
        finding.bounds.right * scaleX,
        finding.bounds.bottom * scaleY,
      );
      canvas.drawRect(rect, fill);
      canvas.drawRect(rect, stroke);
    }
  }

  @override
  bool shouldRepaint(_FindingBoxPainter oldDelegate) {
    return oldDelegate.findings != findings ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.color != color;
  }
}
