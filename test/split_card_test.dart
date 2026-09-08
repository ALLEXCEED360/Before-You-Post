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

  test('pairs a security code with a label on another line', () {
    // The reported case. On a card the label and the digits are set
    // apart, so ML Kit returns them as separate lines and the same-line
    // rule sees neither half.
    final findings = detector.detect([
      OcrLine(
        text: 'CVV',
        bounds: const Rect.fromLTWH(0, 100, 60, 24),
        tokens: const [],
      ),
      OcrLine(
        text: '123',
        bounds: const Rect.fromLTWH(80, 100, 50, 24),
        tokens: const [],
      ),
    ]);

    expect(findings.single.type, FindingType.securityCode);
    // The digits, not the label. Hiding the word "CVV" protects nothing.
    expect(findings.single.bounds, const Rect.fromLTWH(80, 100, 50, 24));
  });

  test('does not pair a label with a distant number', () {
    final findings = detector.detect([
      OcrLine(
        text: 'CVV',
        bounds: const Rect.fromLTWH(0, 100, 60, 24),
        tokens: const [],
      ),
      OcrLine(
        text: '499',
        bounds: const Rect.fromLTWH(900, 1400, 50, 24),
        tokens: const [],
      ),
    ]);

    expect(findings, isEmpty);
  });

  test('a three digit number with no label anywhere is ignored', () {
    final findings = detector.detect([
      OcrLine(
        text: '123',
        bounds: const Rect.fromLTWH(0, 100, 50, 24),
        tokens: const [],
      ),
    ]);

    expect(findings, isEmpty);
  });

  test('pairs a code with a SECURITY CODE label on one line', () {
    final findings = detector.detect([
      OcrLine(
        text: 'SECURITY CODE',
        bounds: const Rect.fromLTWH(0, 100, 140, 24),
        tokens: const [],
      ),
      OcrLine(
        text: '456',
        bounds: const Rect.fromLTWH(160, 100, 50, 24),
        tokens: const [],
      ),
    ]);

    expect(findings.single.type, FindingType.securityCode);
    expect(findings.single.bounds, const Rect.fromLTWH(160, 100, 50, 24));
  });

  test('pairs a code with a label OCR split into two words', () {
    // A card stacks "SECURITY" above "CODE" in small print, and ML Kit
    // returns each as its own line. Neither half is a label alone.
    final findings = detector.detect([
      OcrLine(
        text: 'SECURITY',
        bounds: const Rect.fromLTWH(0, 100, 90, 20),
        tokens: const [],
      ),
      OcrLine(
        text: 'CODE',
        bounds: const Rect.fromLTWH(0, 124, 60, 20),
        tokens: const [],
      ),
      OcrLine(
        text: '789',
        bounds: const Rect.fromLTWH(110, 112, 50, 20),
        tokens: const [],
      ),
    ]);

    expect(findings.single.type, FindingType.securityCode);
    expect(findings.single.bounds, const Rect.fromLTWH(110, 112, 50, 20));
  });

  test('the word "code" alone is not a label', () {
    // "code" is far too common to stand on its own - promo codes, error
    // codes, area codes. Only both halves together count.
    final findings = detector.detect([
      OcrLine(
        text: 'CODE',
        bounds: const Rect.fromLTWH(0, 100, 60, 20),
        tokens: const [],
      ),
      OcrLine(
        text: '404',
        bounds: const Rect.fromLTWH(70, 100, 50, 20),
        tokens: const [],
      ),
    ]);

    expect(findings, isEmpty);
  });

  test('a labelled code on one line is reported once, not twice', () {
    // The same-line rule and the pairing pass can both see this. Only
    // one finding should come out.
    final findings = detector.detect([
      OcrLine(
        text: 'CVV 123',
        bounds: const Rect.fromLTWH(0, 100, 120, 24),
        tokens: const [],
      ),
    ]);

    expect(
      findings.where((f) => f.type == FindingType.securityCode),
      hasLength(1),
    );
  });

  test('a whole card front: number and code, each in the right place', () {
    // The passes are independent, so each one can look right on its own
    // and still fight the other on a real card. This is the layout they
    // actually meet: the number in four groups across one row, the small
    // print beneath it.
    //
    // It caught a genuine bug. Pairing by centre distance alone has no
    // sense of direction, so the SECURITY CODE label claimed the third
    // group of the card number - which sits closer to it than the real
    // code does - and reported that as the security code.
    final findings = const SensitiveTextDetector().detect([
      row('4111', 60, 300, 150, 50),
      row('1111', 240, 300, 150, 50),
      row('1111', 420, 300, 150, 50),
      row('1111', 600, 300, 150, 50),
      row('VALID THRU', 60, 400, 200, 25),
      row('12/28', 280, 400, 100, 25),
      row('SECURITY CODE', 450, 400, 220, 25),
      row('123', 690, 400, 70, 25),
      row('A CARDHOLDER', 60, 460, 300, 30),
    ]);

    final card = findings.singleWhere((f) => f.type == FindingType.cardNumber);
    final code = findings.singleWhere(
      (f) => f.type == FindingType.securityCode,
    );

    // The number's box spans all four groups.
    expect(card.bounds, const Rect.fromLTRB(60, 300, 750, 350));
    // And the code's box is on the code, not on part of the number.
    expect(code.bounds, const Rect.fromLTRB(690, 400, 760, 425));
    expect(card.bounds.overlaps(code.bounds), isFalse);
  });
}

/// A line of arbitrary size, for layouts where the geometry is the point.
OcrLine row(String text, double l, double t, double w, double h) {
  final bounds = Rect.fromLTWH(l, t, w, h);
  return OcrLine(
    text: text,
    bounds: bounds,
    tokens: [OcrToken(text: text, bounds: bounds)],
  );
}
