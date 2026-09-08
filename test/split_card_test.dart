// The detector's geometry, tested without a device.
//
// SensitiveTextDetector takes OcrLine values, which are plain data, so
// an ML Kit result can be described by hand - including results this app
// cannot easily produce on demand, like a card number the recogniser has
// broken into four separate lines.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:before_you_post/models/privacy_finding.dart';
import 'package:before_you_post/services/sensitive_text_detector.dart';
import 'package:before_you_post/services/text_recognition_service.dart';

/// One group of digits, positioned like embossed text on a card.
///
/// Each group is 80 wide and 30 tall with a 30px gap, which is roughly
/// what the spacing on a real card looks like once scaled.
OcrLine group(String text, {required double left, double top = 100}) {
  final bounds = Rect.fromLTWH(left, top, 80, 30);
  return OcrLine(
    text: text,
    bounds: bounds,
    tokens: [OcrToken(text: text, bounds: bounds)],
  );
}

const detector = SensitiveTextDetector();

void main() {
  test('rejoins a card number split across four OCR lines', () {
    // The reported bug. ML Kit groups text into lines by proximity, and
    // the gaps in an embossed card number are wide enough that each
    // group comes back on its own. Every per-line rule then sees "1111".
    final findings = detector.detect([
      group('4111', left: 0),
      group('1111', left: 110),
      group('1111', left: 220),
      group('1111', left: 330),
    ]);

    expect(findings.single.type, FindingType.cardNumber);
    // The box has to cover all four groups, or the redaction hides one
    // quarter of the number and leaves the rest legible.
    expect(findings.single.bounds, const Rect.fromLTRB(0, 100, 410, 130));
  });

  test('rejoins a card split into two halves', () {
    // ML Kit's line grouping is proximity-based and inconsistent: the
    // same card comes back as four groups on one photo and two halves
    // on another. A rule that only understood single groups would fix
    // one of those and not the other.
    final findings = detector.detect([
      OcrLine(
        text: '4111 1111',
        bounds: const Rect.fromLTWH(0, 100, 190, 30),
        tokens: const [],
      ),
      OcrLine(
        text: '1111 1111',
        bounds: const Rect.fromLTWH(220, 100, 190, 30),
        tokens: const [],
      ),
    ]);

    expect(findings.single.type, FindingType.cardNumber);
    expect(findings.single.bounds, const Rect.fromLTRB(0, 100, 410, 130));
  });

  test('does not join groups that fail Luhn', () {
    // Without the checksum this whole approach would invent card numbers
    // out of any row of numbers - a table of prices, a spreadsheet.
    final findings = detector.detect([
      group('1234', left: 0),
      group('5678', left: 110),
      group('9012', left: 220),
      group('3456', left: 330),
    ]);

    expect(
      findings.map((f) => f.type),
      isNot(contains(FindingType.cardNumber)),
    );
  });

  test('does not join across a wide gap', () {
    // Two unrelated numbers sharing a row are not one card number, even
    // when the digits happen to satisfy Luhn end to end.
    final findings = detector.detect([
      group('4111', left: 0),
      group('1111', left: 110),
      group('1111', left: 1200),
      group('1111', left: 1310),
    ]);

    expect(
      findings.map((f) => f.type),
      isNot(contains(FindingType.cardNumber)),
    );
  });

  test('does not join groups on different rows', () {
    final findings = detector.detect([
      group('4111', left: 0, top: 100),
      group('1111', left: 110, top: 400),
      group('1111', left: 220, top: 700),
      group('1111', left: 330, top: 1000),
    ]);

    expect(
      findings.map((f) => f.type),
      isNot(contains(FindingType.cardNumber)),
    );
  });

  test('a card already read as one line is not reported twice', () {
    final line = OcrLine(
      text: '4111 1111 1111 1111',
      bounds: const Rect.fromLTWH(0, 100, 410, 30),
      tokens: const [],
    );

    expect(
      detector.detect([line]).where((f) => f.type == FindingType.cardNumber),
      hasLength(1),
    );
  });
}
