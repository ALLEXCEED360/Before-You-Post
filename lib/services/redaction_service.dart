import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

import '../models/privacy_finding.dart';

/// One region to hide. Deliberately plain data: this crosses an isolate
/// boundary, so it must contain nothing tied to the UI or to Flutter.
class RedactionInstruction {
  const RedactionInstruction({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.method,
  });

  /// In ORIGINAL image pixels, like every bounds in this app.
  final int left;
  final int top;
  final int width;
  final int height;

  final RedactionMethod method;
}

/// The Redaction Engine (outline section 6.4).
///
/// Renders a protected copy from the ORIGINAL image plus a list of
/// instructions - never by editing a previous result. That is outline
/// section 14, and it is what makes undo free and avoids the generation
/// loss described in section 35: every decode/edit/re-encode cycle of a
/// JPEG degrades it, so we do exactly one.
///
/// The original file is never modified.
///
/// IMPORTANT: this engine works from the pixels FLUTTER already decoded,
/// not from the file. It used to decode the file itself with
/// package:image, which broke in two separate ways:
///
///  * AVIF and HEIC files decoded to null. Android's platform decoder
///    handles them, so the app could display and analyse a photo it then
///    refused to protect - and modern phone cameras produce these.
///  * Palette (indexed-colour) PNGs decoded fine but ignored every pixel
///    write, because a pixel there holds an index rather than a colour.
///    Redaction reported success and changed nothing.
///
/// Taking the already-decoded pixels fixes both by construction, and has
/// a third benefit: the buffer we edit is byte-for-byte the one the
/// detectors measured, so the two can never disagree about EXIF rotation.
class RedactionService {
  /// Produces the protected image bytes.
  ///
  /// [image] is the decoded image the editor is already displaying.
  /// [imagePath] is used only to return the original untouched when
  /// nothing is selected, and to decide the output format.
  ///
  /// Only findings the user left selected are hidden; the rest are
  /// ignored entirely (outline section 13).
  Future<Uint8List> redact({
    required String imagePath,
    required ui.Image image,
    required List<PrivacyFinding> findings,
  }) async {
    final instructions = [
      for (final finding in findings)
        if (finding.selected)
          RedactionInstruction(
            left: finding.bounds.left.round(),
            top: finding.bounds.top.round(),
            width: finding.bounds.width.round(),
            height: finding.bounds.height.round(),
            method: finding.redaction,
          ),
    ];

    // Nothing to do: hand back the original untouched rather than
    // re-encoding it into a needlessly different file.
    if (instructions.isEmpty) return File(imagePath).readAsBytes();

    final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (raw == null) {
      throw const FormatException('Could not read the image pixels');
    }

    final pixels = raw.buffer.asUint8List();
    final width = image.width;
    final height = image.height;
    final asPng = await _looksLikePng(imagePath);

    // Pixel work on the UI thread would drop frames. Isolate.run copies
    // its arguments to a worker, runs there, and copies the result back.
    return Isolate.run(
      () => renderRedacted(
        rgba: pixels,
        width: width,
        height: height,
        asPng: asPng,
        instructions: instructions,
      ),
    );
  }

  /// Reads only the first bytes, not the whole file.
  Future<bool> _looksLikePng(String path) async {
    final handle = await File(path).open();
    try {
      final header = await handle.read(4);
      return header.length == 4 &&
          header[0] == 0x89 &&
          header[1] == 0x50 &&
          header[2] == 0x4E &&
          header[3] == 0x47;
    } finally {
      await handle.close();
    }
  }
}

/// The pure transform: raw pixels in, encoded bytes out.
///
/// Deliberately separate from the class above, which does the file IO and
/// isolate plumbing. Keeping the pixel logic free of both is what lets it
/// be tested directly, synchronously, with no device and no temp files.
///
/// Top-level on purpose: this runs inside an isolate, so nothing here may
/// touch Flutter, the widget tree, or any object that cannot be copied.
Uint8List renderRedacted({
  required Uint8List rgba,
  required int width,
  required int height,
  required bool asPng,
  required List<RedactionInstruction> instructions,
}) {
  // Straight RGBA, so there is no container format to misinterpret and no
  // palette to defeat us.
  final image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: rgba.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );

  for (final instruction in instructions) {
    _apply(image, instruction);
  }

  // Encode once, at the end. Keep PNG as PNG - screenshots are usually
  // PNG, and re-encoding crisp text as JPEG makes it visibly mushy.
  // Everything else, including AVIF and HEIC input, becomes JPEG.
  return asPng
      ? Uint8List.fromList(img.encodePng(image))
      : Uint8List.fromList(img.encodeJpg(image, quality: 92));
}

void _apply(img.Image image, RedactionInstruction instruction) {
  // Detectors occasionally return boxes that extend past the edge of the
  // image. Cropping outside the buffer would throw, so clamp first.
  final left = instruction.left.clamp(0, image.width - 1);
  final top = instruction.top.clamp(0, image.height - 1);
  var width = instruction.width;
  var height = instruction.height;

  // Grow the region slightly. A box drawn exactly around a glyph can
  // leave a readable sliver of it behind; over-hiding is cosmetic,
  // under-hiding is a privacy failure.
  final padding = (math.min(width, height) * 0.06).round().clamp(2, 12);
  final paddedLeft = (left - padding).clamp(0, image.width - 1);
  final paddedTop = (top - padding).clamp(0, image.height - 1);
  width = (width + padding * 2).clamp(1, image.width - paddedLeft);
  height = (height + padding * 2).clamp(1, image.height - paddedTop);

  if (width < 1 || height < 1) return;

  switch (instruction.method) {
    case RedactionMethod.blackout:
      img.fillRect(
        image,
        x1: paddedLeft,
        y1: paddedTop,
        x2: paddedLeft + width - 1,
        y2: paddedTop + height - 1,
        color: img.ColorRgb8(0, 0, 0),
      );

    case RedactionMethod.blur:
      final region = img.copyCrop(
        image,
        x: paddedLeft,
        y: paddedTop,
        width: width,
        height: height,
      );
      // Radius relative to the region, so a small face and a large one
      // end up equally unrecognisable.
      //
      // This is deliberately aggressive. A gentler radius left phone
      // numbers readable on a real screenshot: to destroy a glyph the
      // blur has to be comparable to the stroke width, and text regions
      // are short, so a fraction of an already-small height is not
      // enough. Verified visually, not guessed.
      final radius = math.max(8, (math.min(width, height) / 3).round());

      // Blur costs width * height * radius, and BOTH grow with the image.
      // On a phone selfie a face box can be 1500px across, giving a
      // radius near 500 - billions of operations, which in practice
      // hangs. Blackout and pixelate cost only area, which is why they
      // survived the same photo and blur did not.
      //
      // So blur a downscaled copy and scale it back up. The result is
      // meant to be an unreadable smear, so the resolution thrown away
      // was never going to be visible - and the downscale destroys fine
      // detail too, which for this purpose is a bonus.
      const maxWorkingSide = 256;
      final shortest = math.min(width, height);

      final img.Image blurred;
      if (shortest > maxWorkingSide) {
        final scale = maxWorkingSide / shortest;
        final small = img.copyResize(
          region,
          width: math.max(1, (width * scale).round()),
          height: math.max(1, (height * scale).round()),
          interpolation: img.Interpolation.average,
        );
        final smallBlur = img.gaussianBlur(
          small,
          radius: math.max(4, (radius * scale).round()),
        );
        blurred = img.copyResize(
          smallBlur,
          width: width,
          height: height,
          interpolation: img.Interpolation.linear,
        );
      } else {
        blurred = img.gaussianBlur(region, radius: radius);
      }

      img.compositeImage(image, blurred, dstX: paddedLeft, dstY: paddedTop);

    case RedactionMethod.pixelate:
      final region = img.copyCrop(
        image,
        x: paddedLeft,
        y: paddedTop,
        width: width,
        height: height,
      );
      // Roughly ten blocks across the shorter side, whatever the
      // resolution. A fixed block size in pixels looks completely
      // different on a 1MP screenshot and a 12MP photo.
      final factor = math.max(2, (math.min(width, height) / 10).round());
      final small = img.copyResize(
        region,
        width: math.max(1, width ~/ factor),
        height: math.max(1, height ~/ factor),
        interpolation: img.Interpolation.average,
      );
      final blocks = img.copyResize(
        small,
        width: width,
        height: height,
        // Nearest neighbour is what produces hard-edged blocks; anything
        // smoother would just be a bad blur.
        interpolation: img.Interpolation.nearest,
      );
      img.compositeImage(image, blocks, dstX: paddedLeft, dstY: paddedTop);
  }
}
