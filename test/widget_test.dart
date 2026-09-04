// Widget tests build a widget tree in memory - no emulator, no device.
// They run in about a second, which makes them the cheapest safety net
// against accidentally breaking a screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:before_you_post/main.dart';

/// Advances past the staggered entrance animations.
///
/// Deliberately NOT pumpAndSettle. The shield on the home screen has a
/// halo that repeats forever, so "wait until nothing is animating" never
/// comes true and pumpAndSettle times out. Pumping a fixed duration is
/// the right tool whenever a screen has any continuous animation.
Future<void> settleEntrances(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('home screen shows the title and both photo actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const BeforeYouPostApp());
    await settleEntrances(tester);

    expect(find.text('Before You Post'), findsOneWidget);
    expect(find.text('Choose photo'), findsOneWidget);
    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('Photos are analysed on your device'), findsOneWidget);
  });

  testWidgets('home screen lays out in dark mode without overflowing', (
    WidgetTester tester,
  ) async {
    tester.view.platformDispatcher.platformBrightnessTestValue =
        Brightness.dark;
    addTearDown(
      tester.view.platformDispatcher.clearPlatformBrightnessTestValue,
    );

    await tester.pumpWidget(const BeforeYouPostApp());
    await settleEntrances(tester);

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

    await tester.pumpWidget(const BeforeYouPostApp());
    await settleEntrances(tester);

    expect(find.text('Choose photo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
