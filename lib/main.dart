import 'package:flutter/material.dart';

import 'screens/intro_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  // Required before touching any plugin - shared_preferences included -
  // from main(), because the Flutter engine binding has to exist first.
  WidgetsFlutterBinding.ensureInitialized();

  final controller = ThemeController();
  // Load before runApp so the very first frame is already in the right
  // theme. Loading afterwards would flash the wrong one for a moment.
  await controller.load();

  runApp(BeforeYouPostApp(themeController: controller));
}

/// The application shell: themes + which screen opens first.
class BeforeYouPostApp extends StatelessWidget {
  const BeforeYouPostApp({super.key, required this.themeController});

  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return ThemeScope(
      controller: themeController,
      // The Builder exists so this MaterialApp sits BELOW the ThemeScope
      // and can therefore depend on it. A widget cannot read an inherited
      // widget that it declares itself.
      child: Builder(
        builder: (context) {
          return MaterialApp(
            title: 'Before You Post',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            // ThemeMode.system until the user picks a side, after which
            // their choice wins and is remembered.
            themeMode: ThemeScope.of(context).value,
            home: const IntroScreen(),
          );
        },
      ),
    );
  }
}
