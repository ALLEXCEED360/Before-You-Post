// Pure Dart tests - no emulator, no ML Kit, no device.
//
// This is the payoff for keeping the rules (lib/utils/regex_utils.dart)
// separate from OCR: the part most likely to be wrong is also the part
// that is cheapest to test. Outline section 33.

import 'package:flutter_test/flutter_test.dart';

import 'package:before_you_post/models/privacy_finding.dart';
import 'package:before_you_post/utils/regex_utils.dart';

void main() {
  group('Luhn', () {
    test('accepts a valid card number', () {
      // The standard Visa test number.
      expect(passesLuhn('4111111111111111'), isTrue);
      expect(passesLuhn('4111 1111 1111 1111'), isTrue);
    });

    test('rejects a number with one digit changed', () {
      expect(passesLuhn('4111111111111112'), isFalse);
    });

    test('rejects runs that are too short or too long', () {
      expect(passesLuhn('411111111111'), isFalse); // 12 digits
      expect(passesLuhn('41111111111111111111'), isFalse); // 20 digits
    });
  });

  group('phone numbers', () {
    test('detects common formats', () {
      for (final sample in [
        'Call me at 713-555-1234',
        'Call me at (713) 555-1234',
        'Call me at 713.555.1234',
        'Call me at +1 713 555 1234',
      ]) {
        final matches = findSensitive(sample);
        expect(
          matches.map((m) => m.type),
          contains(FindingType.phoneNumber),
          reason: 'failed on: $sample',
        );
      }
    });

    test('does not flag a date', () {
      expect(findSensitive('Invoice dated 2024-01-15'), isEmpty);
    });
  });

  group('other rules', () {
    test('detects an email address', () {
      final matches = findSensitive('Reach me at aryan@example.com please');
      expect(matches.single.type, FindingType.email);
      expect(matches.single.text, 'aryan@example.com');
    });

    test('detects a URL', () {
      expect(
        findSensitive('see www.example.com/thing').single.type,
        FindingType.url,
      );
    });

    test('detects a street address', () {
      expect(
        findSensitive('1600 Pennsylvania Ave').single.type,
        FindingType.address,
      );
    });

    test('a valid card is reported as a card, not a phone number', () {
      // Ordering matters: a 16-digit run also satisfies the phone
      // pattern, so cards must be tested first.
      final matches = findSensitive('Card 4111 1111 1111 1111');
      expect(matches.single.type, FindingType.cardNumber);
    });

    test('a long digit run that fails Luhn is not a card', () {
      final matches = findSensitive('Order 1234 5678 9012 3456');
      expect(matches.map((m) => m.type), isNot(contains(FindingType.cardNumber)));
    });

    test('ordinary text produces nothing', () {
      expect(findSensitive('The quick brown fox'), isEmpty);
    });
  });
}
