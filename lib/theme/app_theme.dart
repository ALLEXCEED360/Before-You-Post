import 'package:flutter/material.dart';

/// Design tokens and themes for Before You Post.
///
/// Direction: "shield dark, connected green". Deep navy surfaces read as
/// calm and credible, a green accent means safe/protected, and red means
/// risk. A privacy tool has to feel trustworthy before it feels clever,
/// so the motion here is quick and purposeful rather than showy.

/// Spacing rhythm. Everything is a multiple of 4 so vertical spacing
/// stays consistent across screens.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Motion tokens. Shared durations beat per-widget magic numbers: they
/// keep the whole app feeling like one product, and they are the single
/// place to slow everything down if it ever feels frantic.
abstract final class AppMotion {
  /// Press feedback and colour changes.
  static const Duration fast = Duration(milliseconds: 150);

  /// The default for most transitions.
  static const Duration medium = Duration(milliseconds: 260);

  /// Screen-level entrances.
  static const Duration slow = Duration(milliseconds: 420);

  /// Decelerate on arrival.
  static const Curve enter = Curves.easeOutCubic;

  /// Accelerate on departure - exits should feel faster than entrances.
  static const Curve exit = Curves.easeInCubic;

  /// A little overshoot, for one hero element per screen at most.
  static const Curve emphasised = Curves.easeOutBack;
}

/// True when the user has asked the system to reduce motion.
///
/// Respecting this is an accessibility requirement, not a nicety:
/// large moving elements can trigger nausea for people with vestibular
/// disorders. Every animation in this app checks it.
bool reducedMotion(BuildContext context) =>
    MediaQuery.of(context).disableAnimations;

/// Colours Material 3 has no role for.
@immutable
class AppSemantics extends ThemeExtension<AppSemantics> {
  const AppSemantics({
    required this.safe,
    required this.onSafe,
    required this.risk,
    required this.onRisk,
    required this.canvas,
    required this.heroGradient,
  });

  /// "Nothing to worry about" - protected, complete, on-device.
  final Color safe;
  final Color onSafe;

  /// "Look at this" - a detected privacy risk.
  final Color risk;
  final Color onRisk;

  /// The backdrop behind a photo. Always near-black so the image itself
  /// is the brightest thing on screen, in both themes.
  final Color canvas;

  /// Background wash for the home screen.
  final List<Color> heroGradient;

  @override
  AppSemantics copyWith({
    Color? safe,
    Color? onSafe,
    Color? risk,
    Color? onRisk,
    Color? canvas,
    List<Color>? heroGradient,
  }) {
    return AppSemantics(
      safe: safe ?? this.safe,
      onSafe: onSafe ?? this.onSafe,
      risk: risk ?? this.risk,
      onRisk: onRisk ?? this.onRisk,
      canvas: canvas ?? this.canvas,
      heroGradient: heroGradient ?? this.heroGradient,
    );
  }

  @override
  AppSemantics lerp(covariant AppSemantics? other, double t) {
    if (other == null) return this;
    return AppSemantics(
      safe: Color.lerp(safe, other.safe, t)!,
      onSafe: Color.lerp(onSafe, other.onSafe, t)!,
      risk: Color.lerp(risk, other.risk, t)!,
      onRisk: Color.lerp(onRisk, other.onRisk, t)!,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      heroGradient: [
        for (var i = 0; i < heroGradient.length; i++)
          Color.lerp(heroGradient[i], other.heroGradient[i], t)!,
      ],
    );
  }
}

/// Convenience so screens can write `context.semantics.risk`.
extension SemanticsAccess on BuildContext {
  AppSemantics get semantics => Theme.of(this).extension<AppSemantics>()!;
}

abstract final class AppTheme {
  /// Deep navy. Everything else is derived from it by Material 3, which
  /// guarantees each colour has a readable partner.
  static const Color _seed = Color(0xFF1E3A5F);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );

    final semantics = AppSemantics(
      // Green shifts lighter in dark mode and darker in light mode so it
      // clears 4.5:1 against its own background in both themes.
      safe: isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
      onSafe: isDark ? const Color(0xFF06251A) : Colors.white,
      risk: isDark ? const Color(0xFFF87171) : const Color(0xFFC62828),
      onRisk: isDark ? const Color(0xFF2A0A0A) : Colors.white,
      canvas: const Color(0xFF0B1120),
      heroGradient: isDark
          ? const [Color(0xFF111C2E), Color(0xFF0B1120)]
          : const [Color(0xFFEFF4F9), Color(0xFFF8FAFC)],
    );

    final base = ThemeData(colorScheme: scheme, useMaterial3: true);

    return base.copyWith(
      // Never pure white: a flat #FFFFFF page makes cards impossible to
      // separate from the background without heavy borders.
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF0B1120)
          : const Color(0xFFF6F8FB),
      extensions: [semantics],
      textTheme: _textTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // 56dp tall clears Android's 48dp minimum touch target with room
          // to spare, and reads as a confident primary action.
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Tightened headline tracking and a slightly heavier body weight.
  /// Small changes, but they are most of what separates a default
  /// Material app from one that looks designed.
  static TextTheme _textTheme(TextTheme base) {
    return base.copyWith(
      displaySmall: base.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.5),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
    );
  }
}
