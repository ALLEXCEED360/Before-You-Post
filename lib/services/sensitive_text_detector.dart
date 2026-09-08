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

    return findings;
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
