import 'dart:math' as math;
import 'dart:ui';

import '../models/privacy_finding.dart';
import '../utils/regex_utils.dart';
import 'text_recognition_service.dart';

/// Phase 5: turns recognised text into privacy findings.
///
/// Pure logic - no ML Kit, no Flutter. That is what makes it unit
/// testable without a device, and it is why the rules live here rather
/// than inside the OCR service.
class SensitiveTextDetector {
  const SensitiveTextDetector();

  List<PrivacyFinding> detect(List<OcrLine> lines) {
    final findings = <PrivacyFinding>[];
    var index = 0;

    for (final line in lines) {
      for (final match in findSensitive(line.text)) {
        findings.add(
          PrivacyFinding(
            id: 'text_${index++}',
            type: match.type,
            bounds: _boundsForMatch(line, match.text),
            detail: _detailFor(match),
          ),
        );
      }
    }

    findings.addAll(_joinSplitCardNumbers(lines, findings.length));
    findings.addAll(_labelledSecurityCodes(lines, findings.length));

    return findings;
  }

  /// A security code whose label OCR put on a different line.
  ///
  /// On a card the label and the digits are set apart, so ML Kit
  /// routinely returns "CVV" and "123" as two lines - and the same-line
  /// rule cannot see either half. Pairing them by position is the only
  /// way to reach them.
  ///
  /// The label is load bearing and there is no substitute for it. Three
  /// digits have no structure: they are a price, a page number, a year,
  /// a quantity. Nothing distinguishes a security code from any of those
  /// except the word printed beside it, which is why an unlabelled code
  /// is out of reach rather than merely difficult.
  List<PrivacyFinding> _labelledSecurityCodes(
    List<OcrLine> lines,
    int startIndex,
  ) {
    final labels = [
      for (final line in lines)
        if (securityCodeLabelPattern.hasMatch(line.text.trim())) line,
    ];
    if (labels.isEmpty) return const [];

    final values = [
      for (final line in lines)
        if (securityCodeValuePattern.hasMatch(line.text.trim())) line,
    ];
    if (values.isEmpty) return const [];

    final found = <PrivacyFinding>[];
    final claimed = <OcrLine>{};

    for (final label in labels) {
      OcrLine? nearest;
      var nearestDistance = double.infinity;

      for (final value in values) {
        if (claimed.contains(value)) continue;

        final distance = (value.bounds.center - label.bounds.center).distance;
        // Within a few line-heights. A label and its code are printed
        // together; anything further away is a different number that
        // happens to be three digits long.
        if (distance > label.bounds.height * 6) continue;

        if (distance < nearestDistance) {
          nearest = value;
          nearestDistance = distance;
        }
      }

      if (nearest == null) continue;
      claimed.add(nearest);

      found.add(
        PrivacyFinding(
          id: 'cvv_${startIndex + found.length}',
          type: FindingType.securityCode,
          // The digits, not the label. Hiding the word "CVV" protects
          // nothing.
          bounds: nearest.bounds,
          detail: nearest.text.trim(),
        ),
      );
    }

    return found;
  }

  /// Card numbers printed across several OCR lines.
  ///
  /// A card is the one thing routinely printed with gaps wide enough
  /// that ML Kit stops calling it one line. The four groups of an
  /// embossed number are far enough apart to come back as four separate
  /// lines of four digits each, and every per-line rule then sees
  /// "1111" - not a card number by any measure, and not a phone number
  /// either. The card silently goes unflagged.
  ///
  /// So the groups are rejoined here: digit runs sharing a row, close
  /// enough together, concatenated left to right and tested with Luhn.
  ///
  /// Luhn is what makes this safe. Joining arbitrary numbers that happen
  /// to share a row would otherwise invent card numbers out of prices,
  /// dates and table columns; requiring the checksum means a false join
  /// passes about one time in ten rather than always.
  List<PrivacyFinding> _joinSplitCardNumbers(
    List<OcrLine> lines,
    int startIndex,
  ) {
    // Digits, spaces and dashes only - no letters, no other punctuation.
    //
    // Deliberately not "exactly one group of four". ML Kit's line
    // grouping is proximity-based and inconsistent about where it
    // breaks: the same card can come back as four groups, or as two
    // halves of eight digits, or as three and one. Accepting any run of
    // digits covers all of those.
    final groupPattern = RegExp(r"^[\d\s-]+$");

    final candidates = [
      for (final line in lines)
        if (groupPattern.hasMatch(line.text.trim()) &&
            // Thirteen digits or more is a whole card number, which the
            // per-line rules already handle. Excluding it here is what
            // stops the same card being reported twice.
            digitsOnly(line.text).length >= 3 &&
            digitsOnly(line.text).length < 13)
          line,
    ];
    // One group on its own can never reach thirteen digits.
    if (candidates.length < 2) return const [];

    candidates.sort((a, b) {
      final byRow = a.bounds.center.dy.compareTo(b.bounds.center.dy);
      return byRow != 0 ? byRow : a.bounds.left.compareTo(b.bounds.left);
    });

    // Gather into rows. Two groups are on the same row when their
    // vertical centres are closer together than the text is tall.
    final rows = <List<OcrLine>>[];
    for (final line in candidates) {
      final row = rows.isEmpty ? null : rows.last;
      if (row != null) {
        final previous = row.last;
        final tolerance =
            math.max(previous.bounds.height, line.bounds.height) * 0.6;
        if ((line.bounds.center.dy - previous.bounds.center.dy).abs() <=
            tolerance) {
          row.add(line);
          continue;
        }
      }
      rows.add([line]);
    }

    final found = <PrivacyFinding>[];

    for (final row in rows) {
      row.sort((a, b) => a.bounds.left.compareTo(b.bounds.left));

      var i = 0;
      while (i < row.length) {
        final digits = StringBuffer();
        var bounds = row[i].bounds;
        var matchedAt = -1;

        for (var j = i; j < row.length; j++) {
          if (j > i) {
            final gap = row[j].bounds.left - row[j - 1].bounds.right;
            final height = math.max(
              row[j].bounds.height,
              row[j - 1].bounds.height,
            );
            // The groups of one number sit close together. A gap several
            // times the digit height means these are two different
            // numbers that happen to share a line.
            if (gap > height * 3) break;
          }

          digits.write(digitsOnly(row[j].text));
          bounds = bounds.expandToInclude(row[j].bounds);

          if (digits.length > 19) break;
          if (digits.length >= 13 && passesLuhn(digits.toString())) {
            matchedAt = j;
            break;
          }
        }

        if (matchedAt < 0) {
          i++;
          continue;
        }

        found.add(
          PrivacyFinding(
            id: 'card_join_${startIndex + found.length}',
            type: FindingType.cardNumber,
            bounds: bounds,
            detail: [
              for (final line in row.sublist(i, matchedAt + 1))
                line.text.trim(),
            ].join(' '),
          ),
        );
        i = matchedAt + 1;
      }
    }

    return found;
  }

  /// What the card shows beside the finding.
  ///
  /// The matched text, except for a credential - printing an API key in
  /// the review list would defeat the point of finding it. Enough of the
  /// prefix survives to tell two secrets apart, which is all the user
  /// needs in order to decide.
  String _detailFor(SensitiveMatch match) {
    if (match.type != FindingType.secret) return match.text;
    final visible = match.text.length <= 8
        ? match.text
        : match.text.substring(0, 8);
    return '$visible...';
  }

  /// Narrows a match down to the words it actually covers.
  ///
  /// If we cannot confidently identify them we fall back to the whole
  /// line. That errs towards hiding MORE than necessary, which is the
  /// safe direction to be wrong in for a privacy tool.
  Rect _boundsForMatch(OcrLine line, String matchText) {
    final needle = _normalise(matchText);
    Rect? union;

    for (final token in line.tokens) {
      final candidate = _normalise(token.text);
      // Single characters match almost anything, so ignore them.
      if (candidate.length < 2) continue;
      if (!needle.contains(candidate)) continue;

      union = union == null
          ? token.bounds
          : union.expandToInclude(token.bounds);
    }

    return union ?? line.bounds;
  }

  String _normalise(String value) =>
      value.replaceAll(RegExp(r"[\s()\-.]"), "").toLowerCase();
}
