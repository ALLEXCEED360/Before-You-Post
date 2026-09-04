import 'package:flutter/material.dart';

/// The entry point of every Dart program.
/// runApp() takes a widget and makes it the root of the widget tree.
void main() {
  runApp(const BeforeYouPostApp());
}

/// The root of the application.
/// Stateless because nothing here ever changes while the app runs.
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

/// Screen 1 of 5: the landing screen (outline section 16).
/// Deliberately minimal - the app should explain itself immediately.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Grab the theme once instead of calling Theme.of(context) five times.
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 72,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'BEFORE YOU POST',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Protect your photos before they go public.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Choose Photo'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Take Photo'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
