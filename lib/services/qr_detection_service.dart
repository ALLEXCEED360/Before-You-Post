import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

import '../models/privacy_finding.dart';

/// Phase 6: QR and barcode detection (outline section 10).
///
/// Scans every supported format, not just QR. A shipping barcode or a
/// membership card barcode is just as identifying as a QR code, and
/// restricting the format list would buy speed we do not need on a
/// single still image.
class QrDetectionService {
  final BarcodeScanner _scanner = BarcodeScanner();

  Future<List<PrivacyFinding>> detect(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    final barcodes = await _scanner.processImage(input);

    return [
      for (final (index, barcode) in barcodes.indexed)
        // ML Kit returns Rect.zero when it decoded a code but could not
        // locate it. A zero-size box is not redactable, so skip it.
        if (!barcode.boundingBox.isEmpty)
          PrivacyFinding(
            id: 'qr_$index',
            type: FindingType.qrCode,
            bounds: barcode.boundingBox,
            // What the code actually encodes. Shown to the user so they
            // can judge the risk themselves - a QR pointing at a public
            // website is very different from one holding wifi credentials.
            detail: _describe(barcode),
          ),
    ];
  }

  String _describe(Barcode barcode) {
    final value = barcode.displayValue;
    final kind = barcode.type.name;
    if (value == null || value.isEmpty) return kind;
    // Long payloads make the findings list unreadable.
    final trimmed = value.length > 60 ? '${value.substring(0, 60)}...' : value;
    return '$kind: $trimmed';
  }

  Future<void> dispose() => _scanner.close();
}
