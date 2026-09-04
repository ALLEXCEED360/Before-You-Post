import 'dart:ui';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// One word-sized chunk of recognised text, with its own box.
class OcrToken {
  const OcrToken({required this.text, required this.bounds});

  final String text;
  final Rect bounds;
}

/// One line of recognised text (outline section 8).
class OcrLine {
  const OcrLine({
    required this.text,
    required this.bounds,
    required this.tokens,
  });

  final String text;

  /// In original image pixels, like every other bounds in this app.
  final Rect bounds;

  /// The individual words, so a match can be redacted tightly instead of
  /// blacking out the whole line.
  final List<OcrToken> tokens;
}

/// Phase 4: OCR only. This class knows how to READ text and where it sits.
/// It deliberately has no opinion about whether that text is private -
/// that is the sensitive-text detector's job.
class TextRecognitionService {
  final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  Future<List<OcrLine>> recognise(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    final result = await _recognizer.processImage(input);

    // ML Kit nests results as blocks > lines > elements. Lines are the
    // right granularity: a phone number normally sits on exactly one.
    return [
      for (final block in result.blocks)
        for (final line in block.lines)
          OcrLine(
            text: line.text,
            bounds: line.boundingBox,
            tokens: [
              for (final element in line.elements)
                OcrToken(text: element.text, bounds: element.boundingBox),
            ],
          ),
    ];
  }

  Future<void> dispose() => _recognizer.close();
}
