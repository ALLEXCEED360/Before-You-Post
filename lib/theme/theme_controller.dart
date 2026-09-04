import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the app's light/dark choice and remembers it between launches.
///
/// A ValueNotifier is Flutter's built-in "one changeable value that
/// widgets can listen to". No state-management package needed for
/// something this small - reach for one when the state actually gets
/// complicated, not before.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.system);

  static const String _key = 'theme_mode';

  /// Reads the saved choice. Called once before runApp so the first frame
  /// already has the right theme - loading it afterwards would make the
  /// app visibly flash from one theme to the other.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);

    value = switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      // Anything else - including no saved value at all - follows the
      // phone. Deferring to the system is the right default.
      _ => ThemeMode.system,
    };
  }

  Future<void> _save(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  /// Flips to the opposite of what is currently on screen.
  ///
  /// [currentBrightness] is what the app is actually rendering right now,
  /// which matters while the mode is still `system`: without it, the
  /// first tap would be a coin flip rather than "give me the other one".
  void toggle(Brightness currentBrightness) {
    final next = currentBrightness == Brightness.dark
        ? ThemeMode.light
        : ThemeMode.dark;

    value = next;
    // Fire and forget: the UI has already changed, and a failed write
    // only means the choice is not remembered next launch.
    _save(next);
  }
}

/// Makes the controller reachable from any widget below it.
///
/// InheritedNotifier does two jobs at once: it passes the controller down
/// the tree, and it rebuilds every widget that read it whenever the
/// controller's value changes.
class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'No ThemeScope found above this widget');
    return scope!.notifier!;
  }
}
