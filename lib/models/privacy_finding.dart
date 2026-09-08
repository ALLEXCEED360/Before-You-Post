import 'dart:ui';

/// How a region should be hidden (outline section 14).
enum RedactionMethod { blur, pixelate, blackout }

/// Every kind of thing the app can flag (outline section 12).
///
/// Each type carries its own sensible default redaction: faces read better
/// blurred, while text is safer blacked out - a blurred phone number can
/// sometimes still be reconstructed.
enum FindingType {
  face('Face', RedactionMethod.blur),
  phoneNumber('Phone number', RedactionMethod.blackout),
  email('Email address', RedactionMethod.blackout),
  url('Link', RedactionMethod.blackout),
  cardNumber('Card number', RedactionMethod.blackout),
  address('Address', RedactionMethod.blackout),
  licensePlate('Number plate', RedactionMethod.blackout),
  secret('API key or secret', RedactionMethod.blackout),
  qrCode('QR code', RedactionMethod.pixelate),
  manual('Manual selection', RedactionMethod.blackout);

  const FindingType(this.label, this.defaultRedaction);

  final String label;
  final RedactionMethod defaultRedaction;
}

/// One potential privacy risk found in an image.
///
/// THE INVARIANT THAT MATTERS: [bounds] is always expressed in the
/// ORIGINAL image's pixel coordinates - never in screen or widget
/// coordinates. Every detector produces this space, and only the drawing
/// layer converts out of it. Mixing the two is outline section 34, and it
/// is the bug that will cost you the most time if this rule ever bends.
class PrivacyFinding {
  PrivacyFinding({
    required this.id,
    required FindingType type,
    required this.bounds,
    this.confidence = 1.0,
    this.detail,
    this.selected = true,
    RedactionMethod? redaction,
  }) : type = type,
       redaction = redaction ?? type.defaultRedaction;

  final String id;
  final FindingType type;

  /// Region of the risk, in original image pixels.
  final Rect bounds;

  /// 0.0 - 1.0. Rule-based detectors use 1.0; models report their own.
  final double confidence;

  /// Optional extra context, e.g. the actual matched text.
  final String? detail;

  /// Whether the user wants this hidden. Defaults to true so the safe
  /// choice is the default, but the user always gets the final say
  /// (outline section 13).
  final bool selected;

  final RedactionMethod redaction;

  PrivacyFinding copyWith({bool? selected, RedactionMethod? redaction}) {
    return PrivacyFinding(
      id: id,
      type: type,
      bounds: bounds,
      confidence: confidence,
      detail: detail,
      selected: selected ?? this.selected,
      redaction: redaction ?? this.redaction,
    );
  }

  @override
  String toString() =>
      'PrivacyFinding(${type.name}, ${bounds.left.toStringAsFixed(0)},'
      '${bounds.top.toStringAsFixed(0)} '
      '${bounds.width.toStringAsFixed(0)}x${bounds.height.toStringAsFixed(0)})';
}
