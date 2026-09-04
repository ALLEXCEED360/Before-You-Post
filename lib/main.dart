import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const BeforeYouPostApp());
}

/// The application shell: theme + which screen opens first.
/// Screens themselves live in lib/screens/.
class BeforeYouPostApp extends StatelessWidget {
  const BeforeYouPostApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Before You Post',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const HomeScreen(),
    );
  }
}
