import '../models/privacy_finding.dart';
import 'face_detection_service.dart';
import 'sensitive_text_detector.dart';
import 'text_recognition_service.dart';

/// The result of one analysis run.
class PrivacyScan {
  const PrivacyScan({required this.findings, required this.textLines});

  final List<PrivacyFinding> findings;

  /// Every line OCR read, sensitive or not. Kept only so the debug
  /// overlay can show what the reader actually saw - invaluable when a
  /// phone number is present but goes unflagged.
  final List<OcrLine> textLines;
}

/// The Privacy Engine (outline section 6.3).
///
/// Owns every detector and merges their output into one list of findings.
/// Screens talk to this and never to a detector directly, so adding QR
/// detection later means changing exactly one file.
class PrivacyEngine {
  final FaceDetectionService _faces = FaceDetectionService();
  final TextRecognitionService _text = TextRecognitionService();
  final SensitiveTextDetector _sensitive = const SensitiveTextDetector();

  Future<PrivacyScan> analyse(String imagePath) async {
    // Face detection and OCR are independent, so run them at the same
    // time rather than one after the other. Dart 3 lets a record of
    // futures be awaited together.
    final (faces, lines) = await (
      _faces.detect(imagePath),
      _text.recognise(imagePath),
    ).wait;

    return PrivacyScan(
      findings: [...faces, ..._sensitive.detect(lines)],
      textLines: lines,
    );
  }

  Future<void> dispose() async {
    await _faces.dispose();
    await _text.dispose();
  }
}
