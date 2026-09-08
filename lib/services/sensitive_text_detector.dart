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
    findings.addAll(_labelledSecurityCodes(lines, findings.length, findings));

    return findings;
  }

  /// Every place a security-code label appears, as boxes.
  ///
  /// Two shapes, because OCR produces both. A whole label on one line is
  /// the easy case. The other is a card that stacks "SECURITY" above
  /// "CODE" in small print, which comes back as two lines - and neither
  /// half is a label by itself, "code" least of all. So the halves only
  /// count when both are present and close together.
  ///
  /// A line carrying digits of its own is skipped: the same-line rule
  /// has already reported that one, and pairing it again would produce
  /// two findings for a single code.
  List<Rect> _securityCodeLabels(List<OcrLine> lines) {
    final labels = <Rect>[];
    final digits = RegExp(r"\d{3,4}");

    for (final line in lines) {
      if (digits.hasMatch(line.text)) continue;
      if (securityCodeLabelPattern.hasMatch(line.text.trim())) {
        labels.add(line.bounds);
      }
    }

    final securityWords = [
      for (final line in lines)
        if (securityWordPattern.hasMatch(line.text.trim())) line,
    ];
    final codeWords = [
      for (final line in lines)
        if (codeWordPattern.hasMatch(line.text.trim())) line,
    ];

    for (final security in securityWords) {
      for (final code in codeWords) {
        final apart = (security.bounds.center - code.bounds.center).distance;
        if (apart > security.bounds.height * 4) continue;
        labels.add(security.bounds.expandToInclude(code.bounds));
      }
    }

    return labels;
  }

  /// Whether a number is positioned as though the label belongs to it.
  ///
  /// Raw distance between centres was not enough. It has no sense of
  /// direction, so it happily paired a label with whatever digits
  /// happened to sit nearest - including part of the card number
  /// diagonally above. A label refers to what is beside it on the same
  /// line, or to what sits directly beneath it; those are the two ways a
  /// card sets this out, and nothing else counts.
  bool _readsAsLabelled(Rect label, Rect value) {
    final height = math.max(label.height, value.height);

    final onSameRow = (label.center.dy - value.center.dy).abs() <= height * 1.2;
    if (onSameRow) {
      final gap = value.left >= label.right
          ? value.left - label.right
          : label.left - value.right;
      return gap <= height * 8;
    }

    final overlapsHorizontally =
        value.left < label.right && label.left < value.right;
    final below = value.top - label.bottom;
    return overlapsHorizontally && below >= 0 && below <= height * 3;
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
    List<PrivacyFinding> alreadyFound,
  ) {
    final labels = _securityCodeLabels(lines);
    if (labels.isEmpty) return const [];

    // Digits already accounted for by a card number are not candidates.
    //
    // Without this the label pairs with a group of the card number
    // itself, which sits closer to it than the real code does on most
    // card layouts - so the app reported the third group of the number
    // as the security code and left the actual code alone.
    final cardRegions = [
      for (final finding in alreadyFound)
        if (finding.type == FindingType.cardNumber) finding.bounds,
    ];

    final values = [
      for (final line in lines)
        if (securityCodeValuePattern.hasMatch(line.text.trim()) &&
            !cardRegions.any((card) => card.overlaps(line.bounds)))
          line,
    ];
    if (values.isEmpty) return const [];

    final found = <PrivacyFinding>[];
    final claimed = <OcrLine>{};

    for (final label in labels) {
      OcrLine? nearest;
      var nearestDistance = double.infinity;

      for (final value in values) {
        if (claimed.contains(value)) continue;
        if (!_readsAsLabelled(label, value.bounds)) continue;

        final distance = (value.bounds.center - label.center).distance;
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
