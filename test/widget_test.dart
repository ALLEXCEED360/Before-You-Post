// Widget tests build a widget tree in memory - no emulator, no device.
// They run in about a second, which makes them the cheapest safety net
// against accidentally breaking a screen.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:before_you_post/main.dart';
import 'package:image/image.dart' as img;

import 'package:before_you_post/models/privacy_finding.dart';
import 'package:before_you_post/screens/editor_screen.dart';
import 'package:before_you_post/services/privacy_engine.dart';
import 'package:before_you_post/theme/app_theme.dart';
import 'package:before_you_post/widgets/finding_card.dart';
import 'package:before_you_post/screens/intro_screen.dart';
import 'package:before_you_post/theme/theme_controller.dart';

/// Advances past entrance animations.
///
/// Deliberately NOT pumpAndSettle. The intro rings and the home screen's
/// halo repeat forever, so "wait until nothing is animating" never comes
/// true and pumpAndSettle times out. Pumping a fixed duration is the
/// right tool whenever a screen has any continuous animation.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
}

Future<ThemeController> pumpApp(WidgetTester tester) async {
  final controller = ThemeController();
  await tester.pumpWidget(BeforeYouPostApp(themeController: controller));
  await settle(tester);
  return controller;
}

/// Taps through the intro screen onto the home screen.
///
/// tapAt a coordinate, not tap on the prompt text. Plain Text is not a
/// hit-test target - the handler is the full-screen GestureDetector - so
/// tapping the label warns that it "would not hit test". Tapping a point
/// is also a truer test of what the screen promises: tap anywhere.
Future<void> enterApp(WidgetTester tester) async {
  await tester.tapAt(tester.getCenter(find.byType(IntroScreen)));
  await settle(tester);
}

/// A solid white image, so a card has something to draw a thumbnail from.
Future<ui.Image> solidImage(int width, int height) {
  final completer = Completer<ui.Image>();
  final pixels = Uint8List(width * height * 4)
    ..fillRange(0, width * height * 4, 255);
  ui.decodeImageFromPixels(
    pixels,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

void main() {
  setUp(() {
    // shared_preferences talks to a platform channel that does not exist
    // in a test. This installs an in-memory stand-in.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('intro screen invites a tap and leads to the home screen', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Before You Post'), findsOneWidget);
    expect(find.text('Tap anywhere to continue'), findsOneWidget);
    // The home screen is not built yet.
    expect(find.text('Choose photo'), findsNothing);

    await enterApp(tester);

    expect(find.text('Choose photo'), findsOneWidget);
    // pushReplacement, so the intro is gone rather than stacked behind.
    expect(find.text('Tap anywhere to continue'), findsNothing);
  });

  testWidgets('home screen shows the title and both photo actions', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await enterApp(tester);

    expect(find.text('Before You Post'), findsOneWidget);
    expect(find.text('Choose photo'), findsOneWidget);
    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('Photos are analysed on your device'), findsOneWidget);
  });

  testWidgets('theme toggle switches mode and offers the opposite next', (
    WidgetTester tester,
  ) async {
    final controller = await pumpApp(tester);
    await enterApp(tester);

    // Tests start in light mode, so the button offers dark.
    expect(controller.value, ThemeMode.system);
    await tester.tap(find.byTooltip('Switch to dark mode'));
    await settle(tester);

    expect(controller.value, ThemeMode.dark);
    // And now it offers the way back.
    expect(find.byTooltip('Switch to light mode'), findsOneWidget);
  });

  testWidgets('home screen lays out in dark mode without overflowing', (
    WidgetTester tester,
  ) async {
    tester.view.platformDispatcher.platformBrightnessTestValue =
        Brightness.dark;
    addTearDown(
      tester.view.platformDispatcher.clearPlatformBrightnessTestValue,
    );

    await pumpApp(tester);
    await enterApp(tester);

    expect(find.text('Before You Post'), findsOneWidget);
    // An overflow renders as yellow stripes AND throws. Catching it here
    // means a layout regression fails the build instead of shipping.
    expect(tester.takeException(), isNull);
  });

  testWidgets('home screen survives the largest system text size', (
    WidgetTester tester,
  ) async {
    // 2.0x is roughly Android's maximum accessibility font scale. This is
    // where fixed-height layouts break, which is why the home screen
    // scrolls instead of using a rigid Column.
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpApp(tester);
    await enterApp(tester);

    expect(find.text('Choose photo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('redaction methods stay on one line on a narrow screen', (
    WidgetTester tester,
  ) async {
    // A tester's screenshot showed "Pixelate" and "Blackout" each broken
    // across two lines mid-word, on a phone narrower than the one this
    // was built on. Nothing threw - Text wrapping is legal layout - so
    // no existing test caught it, and it shipped.
    //
    // Hence measuring the rendered height rather than looking for an
    // exception. A second line roughly doubles it.
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    // runAsync, not a bare await. testWidgets runs its body inside a
    // fake-async zone, and decodeImageFromPixels completes on the real
    // event loop - which that zone never advances, so awaiting it
    // directly hangs the whole suite forever rather than failing.
    late final ui.Image image;
    await tester.runAsync(() async => image = await solidImage(40, 40));
    addTearDown(image.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          // Roughly the width a card gets inside the review panel on a
          // small phone, once both sets of padding are taken out.
          body: Center(
            child: SizedBox(
              width: 280,
              child: FindingCard(
                finding: PrivacyFinding(
                  id: 'test',
                  type: FindingType.face,
                  bounds: const Rect.fromLTWH(0, 0, 40, 40),
                ),
                image: image,
                number: 1,
                highlighted: false,
                onSelectedChanged: (_) {},
                onMethodChanged: (_) {},
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);

    for (final label in ['Blur', 'Pixelate', 'Blackout']) {
      expect(
        tester.getSize(find.text(label)).height,
        lessThan(30),
        reason: '"$label" wrapped onto a second line',
      );
    }

    // And the segment is tall enough to hold an icon above a word with
    // real space around both. At six pixels of padding a tester read the
    // border as touching the text; ten is what it took. Nothing throws
    // either way - crowding is legal layout, visible only to the eye -
    // so height is the only thing a test can hold on to.
    final segments = tester.getSize(
      find.byType(SegmentedButton<RedactionMethod>),
    );
    expect(
      segments.height,
      greaterThanOrEqualTo(58),
      reason: 'the method segments are too cramped for a stacked label',
    );
  });

  testWidgets('a whole finding card fits in the panel on a short screen', (
    WidgetTester tester,
  ) async {
    // The reported bug: on a shorter phone the review panel showed one
    // card, clipped through its own thumbnail, with no way to tell there
    // was more below. The panel had a fixed 40% of the screen whatever
    // it held, and one card no longer fitted in that.
    //
    // A 360x740 viewport is a small-but-ordinary Android phone.
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late final ui.Image image;
    await tester.runAsync(() async => image = await solidImage(60, 60));
    addTearDown(image.dispose);

    // Image.file wants a real file. Sync IO on purpose - an awaited
    // Future completes on the real event loop, which the fake-async zone
    // testWidgets runs in never advances.
    final dir = Directory.systemTemp.createTempSync('byp_editor');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/photo.png')
      ..writeAsBytesSync(img.encodePng(img.Image(width: 60, height: 60)));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: EditorScreen(
          imagePath: file.path,
          image: image,
          scan: PrivacyScan(
            findings: [
              for (var i = 0; i < 4; i++)
                PrivacyFinding(
                  id: 'f$i',
                  type: FindingType.face,
                  bounds: Rect.fromLTWH(i * 10, 0, 10, 10),
                ),
            ],
            textLines: const [],
          ),
        ),
      ),
    );
    await settle(tester);

    final viewport = tester.getRect(find.byType(Scrollbar));
    final firstCard = tester.getRect(find.byType(FindingCard).first);

    expect(
      firstCard.height,
      greaterThan(0),
      reason: 'the first card was not laid out at all',
    );
    expect(
      firstCard.bottom,
      lessThanOrEqualTo(viewport.bottom + 0.5),
      reason: 'the first card is clipped by the bottom of the panel',
    );
    expect(
      firstCard.top,
      greaterThanOrEqualTo(viewport.top - 0.5),
      reason: 'the first card is clipped by the top of the panel',
    );

    // And the two actions stay reachable whatever the list does.
    expect(find.text('Hide something myself'), findsOneWidget);
    expect(find.textContaining('Protect image'), findsOneWidget);
  });
}
