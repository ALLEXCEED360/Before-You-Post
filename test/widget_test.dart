// Widget tests build a widget tree in memory - no emulator, no device.
// They run in about a second, which makes them the cheapest safety net
// against accidentally breaking a screen.

import 'package:flutter_test/flutter_test.dart';

import 'package:before_you_post/main.dart';

void main() {
  testWidgets('home screen shows the title and both photo buttons', (
    WidgetTester tester,
  ) async {
    // Build the app and let it settle into its first frame.
    await tester.pumpWidget(const BeforeYouPostApp());

    // find.text() searches the rendered tree for a Text widget.
    expect(find.text('BEFORE YOU POST'), findsOneWidget);
    expect(find.text('Protect your photos before they go public.'), findsOneWidget);
    expect(find.text('Choose Photo'), findsOneWidget);
    expect(find.text('Take Photo'), findsOneWidget);
  });
}
