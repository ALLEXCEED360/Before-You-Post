import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const BeforeYouPostApp());
}

/// The application shell: themes + which screen opens first.
class BeforeYouPostApp extends StatelessWidget {
  const BeforeYouPostApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Before You Post',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // Follow the phone's setting. Both themes are built from the same
      // tokens, so neither is an afterthought.
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
