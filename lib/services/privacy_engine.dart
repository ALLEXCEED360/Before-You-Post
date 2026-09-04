import '../models/privacy_finding.dart';
import 'face_detection_service.dart';
import 'qr_detection_service.dart';
import 'sensitive_text_detector.dart';
import 'text_recognition_service.dart';

/// The three detectors, so the analysis screen can report progress for
/// each one individually (outline section 17).
enum DetectorKind {
  faces('Faces'),
  text('Text'),
  codes('QR codes');

  const DetectorKind(this.label);

  final String label;
}

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
/// Screens talk to this and never to a detector directly, which is why
/// adding QR detection changed only this file and added one new service.
class PrivacyEngine {
  final FaceDetectionService _faces = FaceDetectionService();
  final TextRecognitionService _text = TextRecognitionService();
  final QrDetectionService _qr = QrDetectionService();
  final SensitiveTextDetector _sensitive = const SensitiveTextDetector();

  /// [onDetectorDone] fires as each detector finishes, so the UI can tick
  /// them off as they land instead of showing one opaque spinner.
  Future<PrivacyScan> analyse(
    String imagePath, {
    void Function(DetectorKind kind)? onDetectorDone,
  }) async {
    Future<T> track<T>(DetectorKind kind, Future<T> work) {
      return work.then((value) {
        onDetectorDone?.call(kind);
        return value;
      });
    }

    // The three detectors are independent, so run them at the same time
    // rather than one after another. Dart 3 lets a record of futures be
    // awaited together.
    final (faces, lines, codes) = await (
      track(DetectorKind.faces, _faces.detect(imagePath)),
      track(DetectorKind.text, _text.recognise(imagePath)),
      track(DetectorKind.codes, _qr.detect(imagePath)),
    ).wait;

    return PrivacyScan(
      findings: [...faces, ..._sensitive.detect(lines), ...codes],
      textLines: lines,
    );
  }

  Future<void> dispose() async {
    await _faces.dispose();
    await _text.dispose();
    await _qr.dispose();
  }
}
