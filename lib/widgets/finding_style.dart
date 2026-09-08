import 'package:flutter/material.dart';

import '../models/privacy_finding.dart';

/// How a finding looks: its icon and its colour.
///
/// One place, deliberately. The overlay and the card each used to decide
/// this for themselves, and they disagreed - a QR code drew purple on the
/// photo and red on its card, which quietly undermines the whole point of
/// the numbering, since the number and colour are what tell the user the
/// box and the row are the same thing.
///
/// Lives in the widget layer, not the model: PrivacyFinding is plain data
/// and should not depend on Flutter.

IconData iconForFinding(FindingType type) => switch (type) {
  FindingType.face => Icons.face_outlined,
  FindingType.phoneNumber => Icons.phone_outlined,
  FindingType.email => Icons.alternate_email,
  FindingType.url => Icons.link,
  FindingType.cardNumber => Icons.credit_card,
  FindingType.address => Icons.home_outlined,
  FindingType.licensePlate => Icons.directions_car_outlined,
  FindingType.qrCode => Icons.qr_code_2,
  FindingType.manual => Icons.crop_square,
};

/// [risk] comes from the theme extension, which the painter cannot read
/// itself, so it is passed in.
Color colorForFinding(FindingType type, ColorScheme scheme, Color risk) =>
    switch (type) {
      FindingType.face => scheme.primary,
      FindingType.qrCode => scheme.tertiary,
      FindingType.manual => scheme.secondary,
      // Every text-derived risk shares the alarm colour.
      _ => risk,
    };

IconData iconForMethod(RedactionMethod method) => switch (method) {
  RedactionMethod.blur => Icons.blur_on,
  RedactionMethod.pixelate => Icons.grid_view,
  RedactionMethod.blackout => Icons.square_rounded,
};

String labelForMethod(RedactionMethod method) => switch (method) {
  RedactionMethod.blur => 'Blur',
  RedactionMethod.pixelate => 'Pixelate',
  RedactionMethod.blackout => 'Blackout',
};

/// Readable ink for text drawn ON a finding's colour.
///
/// The badge fill changes with the finding type, and some of those - the
/// tertiary used for QR codes - are light. White numerals on a pale badge
/// sitting on a white QR code were effectively invisible, which defeats
/// the point of numbering them at all.
Color onFindingColor(Color background) =>
    background.computeLuminance() > 0.55 ? Colors.black : Colors.white;
