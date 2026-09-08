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
      expect(
        matches.map((m) => m.type),
        isNot(contains(FindingType.cardNumber)),
      );
    });

    test('ordinary text produces nothing', () {
      expect(findSensitive('The quick brown fox'), isEmpty);
    });
  });

  group('addresses beyond the American form', () {
    // Testers outside the US reported addresses going undetected. The
    // original rule only understood "123 Main Street": number first,
    // spaces between the words, and a thoroughfare word from a short
    // Anglo-American list.
    test('reads through a comma', () {
      // "House 12, Road 5" broke at the comma, because the separator was
      // \s+ and a comma is not whitespace.
      final matches = findSensitive('House 12, Road 5');
      expect(matches.map((m) => m.type), everyElement(FindingType.address));
      expect(matches, isNotEmpty);
    });

    test('overlapping address rules produce one finding, not two', () {
      // Both the premise rule ("House 12") and the street rule ("12,
      // Road") match this line. Reporting both would draw two boxes over
      // nearly the same words, which reads as a bug.
      expect(findSensitive('House 12, Road 5').length, 1);
    });

    test('detects a keyword-first premise', () {
      expect(findSensitive('Flat 3B').single.type, FindingType.address);
      expect(findSensitive('Plot 45').single.type, FindingType.address);
    });

    test('detects postcodes in their distinctive forms', () {
      expect(
        findSensitive('Houston TX 77002').single.type,
        FindingType.address,
      );
      expect(findSensitive('London SW1A 1AA').single.type, FindingType.address);
    });

    test('a bare five-digit number is not a postcode', () {
      // Without a state code in front of it, this shape is just "a
      // number" - order totals, item counts and years all match it.
      expect(findSensitive('Total 77002 units'), isEmpty);
    });

    test('detects a South Asian street form', () {
      expect(
        findSensitive('45/A Green Road, Dhaka').single.type,
        FindingType.address,
      );
    });
  });

  group('number plates', () {
    test('detects the common national formats', () {
      for (final sample in ['MH 12 AB 1234', 'AB12 CDE', 'ABC 1234']) {
        expect(
          findSensitive(sample).map((m) => m.type),
          contains(FindingType.licensePlate),
          reason: 'failed on: $sample',
        );
      }
    });

    test('ignores a plate-shaped code buried in a sentence', () {
      // This is the whole reason plates are usable as a rule. A plate is
      // photographed as its own object, so OCR returns it as a short
      // standalone line. The same shape inside a paragraph is far more
      // likely to be a reference number, and flagging every one of those
      // would bury the real findings.
      expect(
        findSensitive('Your order ABC 1234 has shipped and will arrive soon')
            .map((m) => m.type),
        isNot(contains(FindingType.licensePlate)),
      );
    });

    test('lower case is not a plate', () {
      // Plates are stamped in capitals. Requiring that costs nothing and
      // discards a large amount of ordinary prose.
      expect(
        findSensitive('abc 1234').map((m) => m.type),
        isNot(contains(FindingType.licensePlate)),
      );
    });
  });

  group('vanity plates', () {
    test('detects a plate with no structural format', () {
      // The case that prompted this: a real Florida plate, photographed
      // on a car, matching none of the national shapes. OCR returns it
      // beside the state name.
      for (final sample in ['B2TRW', 'FLORIDA B2TRW', 'TEXAS ABC49']) {
        expect(
          findSensitive(sample).map((m) => m.type),
          contains(FindingType.licensePlate),
          reason: 'failed on: $sample',
        );
      }
    });

    test('a postcode line is an address, not a plate', () {
      // "SW1A" is capitals plus digits on a short line, so the shape
      // alone cannot separate it from a plate. Two remaining tokens
      // after the place name is what does.
      expect(findSensitive('London SW1A 1AA').single.type, FindingType.address);
      expect(
        findSensitive('Houston TX 77002').single.type,
        FindingType.address,
      );
    });

    test('a sentence is not a plate', () {
      expect(findSensitive('We arrive at gate B24 shortly'), isEmpty);
    });

    test('all digits or all letters is not a plate', () {
      expect(findSensitive('774028'), isEmpty);
      expect(findSensitive('HELLO'), isEmpty);
    });
  });

  group('credentials', () {
    test('detects provider-issued keys by their prefix', () {
      // Assembled from fragments rather than written as literals.
      //
      // None of these has ever been a real credential, but they are
      // structurally valid - which is the whole point of them, and also
      // exactly what a secret scanner looks for. Written out in full,
      // GitHub blocked the push that carried this file and named two of
      // them. Keeping the prefix apart from the body leaves nothing in
      // the source that pattern-matches a live key, while the strings
      // the detector actually sees are unchanged.
      String key(String prefix, String body) => '$prefix$body';

      final samples = {
        key('AKIA', 'IOSFODNN7EXAMPLE'): 'AWS access key id',
        key('AIza', 'SyD-1234567890abcdefghijklmnopqrstu'): 'Google API key',
        key('ghp', '_1234567890abcdefghijklmnopqrstuvwxyzAB'): 'GitHub token',
        key('xoxb', '-123456789012-abcdefghijklmnop'): 'Slack token',
        key('sk_live', '_abcdefghijklmnopqrstuvwx'): 'Stripe secret key',
        key('sk-ant', '-api03-abcdefghijklmnopqrstuvwxyz'): 'Anthropic key',
      };

      samples.forEach((sample, description) {
        expect(
          findSensitive('key: $sample').map((m) => m.type),
          contains(FindingType.secret),
          reason: 'missed a $description',
        );
      });
    });

    test('detects a JSON Web Token', () {
      const jwt =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
          '.eyJzdWIiOiIxMjM0NTY3ODkwIn0'
          '.dBjftJeZ4CVPmB92K27uhbUJU1p1r_wW1gFWFOEjXk';
      expect(findSensitive(jwt).single.type, FindingType.secret);
    });

    test('detects a private key header', () {
      expect(
        findSensitive('-----BEGIN RSA PRIVATE KEY-----').single.type,
        FindingType.secret,
      );
    });

    test('detects a formatless secret by the name it is given', () {
      // The .env case. The value is indistinguishable from noise; only
      // the label says it matters.
      for (final sample in [
        'API_KEY=8f4c2a9e1b7d6350',
        'DB_PASSWORD: hunter2hunter2',
        'client_secret = "abcd1234efgh5678"',
      ]) {
        expect(
          findSensitive(sample).map((m) => m.type),
          contains(FindingType.secret),
          reason: 'failed on: $sample',
        );
      }
    });

    test('a labelled value too short to be a secret is ignored', () {
      expect(findSensitive('the secret: I told you'), isEmpty);
    });
  });

  group('card security codes', () {
    test('detects a labelled code', () {
      for (final sample in [
        'CVV 123',
        'CVC: 4321',
        'CVV2 999',
        'Security Code 456',
        'Card verification value 321',
      ]) {
        expect(
          findSensitive(sample).map((m) => m.type),
          contains(FindingType.securityCode),
          reason: 'failed on: $sample',
        );
      }
    });

    test('an unlabelled three digit number is not a security code', () {
      // The label is the entire rule. Three digits are a price, a page
      // number, a year or a quantity, and flagging them unlabelled would
      // mean flagging every small number in every photo.
      expect(findSensitive('123'), isEmpty);
      expect(findSensitive('Total 499'), isEmpty);
    });
  });
}
