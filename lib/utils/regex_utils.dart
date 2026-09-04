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

final RegExp addressPattern = RegExp(
  r"\b\d{1,6}\s+(?:[A-Za-z0-9.\x27\-]+\s+){0,4}"
  r"(?:Street|St|Road|Rd|Avenue|Ave|Boulevard|Blvd|Drive|Dr|Lane|Ln|"
  r"Court|Ct|Way|Place|Pl)\b\.?",
  caseSensitive: false,
);

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

  return _collect(FindingType.address, addressPattern, text);
}

List<SensitiveMatch> _collect(FindingType type, RegExp pattern, String text) {
  return [
    for (final match in pattern.allMatches(text))
      SensitiveMatch(type, match.group(0)!),
  ];
}
