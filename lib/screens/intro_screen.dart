import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/fade_slide_in.dart';
import 'home_screen.dart';

/// The opening screen. Tap anywhere to continue.
///
/// The looping rings are not decoration for its own sake - an outward
/// scan pulse is what this app actually does, so the motion says
/// something about the product rather than just moving.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with TickerProviderStateMixin {
  /// Plays once, on arrival.
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  /// The scan rings, running continuously.
  late final AnimationController _rings = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  /// The breathing "tap anywhere" prompt.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  bool _started = false;
  bool _leaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    if (reducedMotion(context)) {
      // Show the finished composition and stop. The screen still works:
      // it is the tap that matters, not the animation.
      _entrance.value = 1;
      _pulse.value = 1;
      return;
    }

    _entrance.forward();
    _rings.repeat();
    _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _entrance.dispose();
    _rings.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _continue() {
    // Without this guard an impatient double tap pushes two home screens.
    if (_leaving) return;
    _leaving = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 520),
        pageBuilder: (_, _, _) => const HomeScreen(),
        transitionsBuilder: (context, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: AppMotion.enter,
          );
          // Fade plus a slight scale-up reads as moving forward into the
          // app, rather than a slide sideways between peer screens.
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantics = context.semantics;

    return Scaffold(
      body: GestureDetector(
        // opaque means the whole area is tappable, including the empty
        // space between elements - which is what "tap anywhere" promises.
        behavior: HitTestBehavior.opaque,
        onTap: _continue,
        child: Semantics(
          button: true,
          label: 'Enter Before You Post',
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: semantics.heroGradient,
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                // Expanded + a scrollable centre block, rather than a
                // Column of Spacers or a Stack.
                //
                // Spacers overflowed by 66px at the largest system text
                // size, because the mark has a fixed height and a Spacer
                // cannot give back space it never had. A Stack fixed the
                // overflow but let the tagline grow until it sat on top
                // of the prompt. This version gives the centre block
                // whatever room is left and lets it scroll, so the two
                // can never collide at any text size.
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _ScanMark(entrance: _entrance, rings: _rings),
                              const SizedBox(height: AppSpacing.lg),
                              FadeSlideIn(
                                delay: const Duration(milliseconds: 420),
                                child: Text(
                                  'Before You Post',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.displaySmall,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              FadeSlideIn(
                                delay: const Duration(milliseconds: 520),
                                child: Text(
                                  'Know what you are sharing.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 750),
                      child: _TapPrompt(pulse: _pulse),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The shield, with rings pulsing outward from it.
class _ScanMark extends StatelessWidget {
  const _ScanMark({required this.entrance, required this.rings});

  final AnimationController entrance;
  final AnimationController rings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Two separate animations sharing one box, isolated from the rest of
    // the screen so their repaints stay local.
    return RepaintBoundary(
      child: SizedBox(
        height: 240,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Three rings, evenly offset in time so one is always leaving
            // as another is born.
            for (var i = 0; i < 3; i++)
              AnimatedBuilder(
                animation: rings,
                builder: (context, _) {
                  final phase = (rings.value + i / 3) % 1.0;
                  return Transform.scale(
                    scale: 1 + phase * 1.9,
                    child: Opacity(
                      // Fade out as it expands, so the ring dissolves
                      // rather than being clipped away.
                      opacity: (1 - phase) * 0.35,
                      child: Container(
                        width: 132,
                        height: 132,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: scheme.primary, width: 1.5),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ScaleTransition(
              scale: CurvedAnimation(
                parent: entrance,
                // A touch of overshoot on the one hero element.
                curve: AppMotion.emphasised,
              ),
              child: FadeTransition(
                opacity: entrance,
                child: Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primaryContainer,
                  ),
                  child: Icon(
                    Icons.shield_outlined,
                    size: 60,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TapPrompt extends StatelessWidget {
  const _TapPrompt({required this.pulse});

  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, child) =>
            Opacity(opacity: 0.45 + 0.55 * pulse.value, child: child),
        child: Column(
          children: [
            Icon(
              Icons.keyboard_arrow_up,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            Text(
              'Tap anywhere to continue',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
