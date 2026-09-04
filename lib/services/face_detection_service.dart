import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../models/privacy_finding.dart';

/// Wraps ML Kit face detection and converts its results into the app's
/// own PrivacyFinding model.
///
/// The rest of the app must never import ML Kit types. Keeping the
/// translation in one place is what lets each detector be developed and
/// swapped independently (outline section 5).
class FaceDetectionService {
  FaceDetectionService()
    : _detector = FaceDetector(
        options: FaceDetectorOptions(
          // 'accurate' is slower but we are analysing one still image,
          // not a 30fps camera stream, so correctness wins.
          performanceMode: FaceDetectorMode.accurate,
          // Faces smaller than 5% of the image width are still worth
          // flagging - a face in the background is still a face.
          minFaceSize: 0.05,
        ),
      );

  final FaceDetector _detector;

  Future<List<PrivacyFinding>> detect(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final faces = await _detector.processImage(inputImage);

    return [
      for (final (index, face) in faces.indexed)
        PrivacyFinding(
          id: 'face_$index',
          type: FindingType.face,
          // ML Kit gives us a Rect in original image pixels, which is
          // exactly the space PrivacyFinding requires. No conversion.
          bounds: face.boundingBox,
        ),
    ];
  }

  /// ML Kit holds native resources. Always close it.
  Future<void> dispose() => _detector.close();
}
