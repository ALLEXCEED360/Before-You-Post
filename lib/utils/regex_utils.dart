import '../models/privacy_finding.dart';

/// Rule-based sensitive-text detection (outline section 9).
///
/// Deliberately deterministic. Regex is easy to read, easy to unit test,
/// and easy to explain when it gets something wrong. An NLP model is a
/// later version, not a starting point.

class SensitiveMatch {
  const SensitiveMatch(this.type, this.text);

  final FindingType type;
  final String text;
}

final RegExp emailPattern = RegExp(
  r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}",
);

final RegExp urlPattern = RegExp(
  r"(?:https?://|www\.)[^\s]{2,}",
  caseSensitive: false,
);

/// Candidates only. A digit run of the right length is NOT a card number
/// until it passes Luhn - that check is what keeps false positives down.
final RegExp cardCandidatePattern = RegExp(r"\b(?:\d[ -]?){13,19}\b");

final RegExp phonePattern = RegExp(
  r"(?:\+?1[\s.\-]?)?\(?\d{3}\)?[\s.\-]?\d{3}[\s.\-]?\d{4}",
);

/// Street-style addresses: a number, then up to four words, then a
/// thoroughfare word.
///
/// The separator accepts commas as well as spaces. Without that, the very
/// common "House 12, Road 5" shape broke at the comma and was missed
/// entirely - the pattern only ever saw addresses written the American
/// way, which is how it was originally written and tested.
final RegExp addressPattern = RegExp(
  r"\b\d{1,6}(?:[/-][A-Za-z0-9]{1,3})?[\s,]+(?:[A-Za-z0-9.\x27\-]+[\s,]+){0,4}"
  r"(?:Street|St|Road|Rd|Avenue|Ave|Boulevard|Blvd|Drive|Dr|Lane|Ln|"
  r"Court|Ct|Way|Place|Pl|Marg|Nagar|Sarani|Colony|Bazaar|Bazar|"
  r"Chowk|Gali|Sector|Block)\b\.?",
  caseSensitive: false,
);

/// The other common shape: the keyword FIRST, then the number - "House
/// 12", "Flat 3B", "Plot 45", "Block C".
///
/// [addressPattern] structurally cannot see these, because it requires
/// the number to lead. Between them they cover both conventions.
///
/// Two guards keep this off ordinary prose, and both are here because
/// it fired on ordinary prose without them:
///
///  * The lookahead after the keyword. A trailing word boundary is not
///    enough, because "Unit" also ends a word inside "units" - which
///    made "Total 77002 units" an address.
///  * The letterless branch is accepted only at the end of a line or
///    before a comma, which is where a real "Block C" sits. Without
///    that restriction, "Plot a graph" is a premise.
final RegExp premisePattern = RegExp(
  r"\b(?:House|Holding|Flat|Apartment|Apt|Plot|Block|Sector|Suite|Unit)"
  r"(?![A-Za-z])\s*(?:No\.?|#)?\s*"
  r"(?:\d{1,5}[A-Za-z]?\b|[A-Za-z](?=\s*(?:,|$)))",
  caseSensitive: false,
);

/// Postcodes, but only in shapes distinctive enough to be worth matching.
///
/// A bare five-digit number is not a postcode, it is any number, so the
/// American form is only accepted with a state code in front of it. The
/// British form is distinctive on its own.
///
/// Case sensitive on purpose: postcodes are printed in capitals, and
/// requiring that discards a large amount of ordinary prose that would
/// otherwise fit the shape.
final RegExp postcodePattern = RegExp(
  r"\b(?:[A-Z]{2}\s+\d{5}(?:-\d{4})?"
  r"|[A-Z]{1,2}\d[A-Z\d]?\s*\d[A-Z]{2})\b",
);

/// Vehicle number plates.
///
/// Four shapes, chosen because each is structurally distinctive. A looser
/// "some letters then some digits" rule would flag half the text in any
/// screenshot - reference numbers, order codes, seat rows and model names
/// all have that shape.
///
/// Capitals only, for the same reason as [postcodePattern]: plates are
/// stamped in capitals, and requiring it costs nothing and removes a lot.
final RegExp platePattern = RegExp(
  // South Asian: MH 12 AB 1234
  r"\b[A-Z]{2}[\s-]?\d{1,2}[\s-]?[A-Z]{1,3}[\s-]?\d{3,4}\b"
  // British current: AB12 CDE
  r"|\b[A-Z]{2}\d{2}\s?[A-Z]{3}\b"
  // North American: ABC 1234, and the Californian 7ABC123
  r"|\b[A-Z]{3}[\s-]?\d{3,4}\b"
  r"|\b\d[A-Z]{3}\d{3}\b",
);

/// How much of an OCR line a plate match has to account for.
///
/// This is what makes the plate patterns usable rather than a nuisance. A
/// number plate is photographed as its own object, so OCR hands it back
/// as a short standalone line. "ABC 1234" buried in a paragraph is far
/// more likely to be an order reference than a car, so it is ignored.
const double _plateLineDominance = 0.6;

String digitsOnly(String value) => value.replaceAll(RegExp(r"[^0-9]"), "");

/// The Luhn checksum (outline section 9).
///
/// Every real card number satisfies it, and a random digit run only passes
/// about one time in ten. That single check turns "any 16 digits" - which
/// would flag order numbers, timestamps and IDs - into something usable.
bool passesLuhn(String value) {
  final digits = digitsOnly(value);
  if (digits.length < 13 || digits.length > 19) return false;

  var sum = 0;
  var shouldDouble = false;

  for (var i = digits.length - 1; i >= 0; i--) {
    var digit = digits.codeUnitAt(i) - 0x30;
    if (shouldDouble) {
      digit *= 2;
      if (digit > 9) digit -= 9;
    }
    sum += digit;
    shouldDouble = !shouldDouble;
  }

  return sum % 10 == 0;
}

/// Classifies one line of OCR text.
///
/// Types are checked most-specific first and the first type that matches
/// wins. That ordering is load bearing: a 16-digit card number also
/// satisfies the phone pattern, so cards must be tested first.
///
/// Known limitation: a line holding both an email and a phone number
/// reports only the email. Acceptable for v1 - the user can still draw a
/// manual box (outline section 21).
List<SensitiveMatch> findSensitive(String text) {
  final emails = _collect(FindingType.email, emailPattern, text);
  if (emails.isNotEmpty) return emails;

  final urls = _collect(FindingType.url, urlPattern, text);
  if (urls.isNotEmpty) return urls;

  final cards = [
    for (final match in cardCandidatePattern.allMatches(text))
      if (passesLuhn(match.group(0)!))
        SensitiveMatch(FindingType.cardNumber, match.group(0)!),
  ];
  if (cards.isNotEmpty) return cards;

  final phones = _collect(FindingType.phoneNumber, phonePattern, text);
  if (phones.isNotEmpty) return phones;

  final plates = [
    for (final match in platePattern.allMatches(text))
      if (_dominatesLine(match.group(0)!, text))
        SensitiveMatch(FindingType.licensePlate, match.group(0)!),
  ];
  if (plates.isNotEmpty) return plates;

  return _collectAddresses(text);
}

bool _dominatesLine(String match, String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) return false;
  return match.length / trimmed.length >= _plateLineDominance;
}

/// Runs all three address patterns and merges the results.
///
/// They overlap by design - "House 12, Road 5" matches both the premise
/// and the street rule - so a match that another, longer match already
/// covers is dropped. Without this the user gets two boxes over almost
/// the same words, which reads as a bug rather than as thoroughness.
List<SensitiveMatch> _collectAddresses(String text) {
  final found = <({int start, int end, String text})>[];

  for (final pattern in [addressPattern, premisePattern, postcodePattern]) {
    for (final match in pattern.allMatches(text)) {
      found.add((start: match.start, end: match.end, text: match.group(0)!));
    }
  }

  // Longest first, so the more complete address is the one that survives.
  found.sort((a, b) => (b.end - b.start).compareTo(a.end - a.start));

  final kept = <({int start, int end, String text})>[];
  for (final candidate in found) {
    final overlapsOneAlreadyKept = kept.any(
      (k) => candidate.start < k.end && k.start < candidate.end,
    );
    if (!overlapsOneAlreadyKept) kept.add(candidate);
  }

  kept.sort((a, b) => a.start.compareTo(b.start));
  return [for (final k in kept) SensitiveMatch(FindingType.address, k.text)];
}

List<SensitiveMatch> _collect(FindingType type, RegExp pattern, String text) {
  return [
    for (final match in pattern.allMatches(text))
      SensitiveMatch(type, match.group(0)!),
  ];
}
