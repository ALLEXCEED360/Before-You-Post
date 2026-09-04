import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Fades and lifts its child into place, optionally after a delay.
///
/// Giving each element on a screen a slightly larger delay produces a
/// staggered entrance - the single cheapest way to make an interface feel
/// deliberate rather than dumped on screen.
///
/// Honours the system reduce-motion setting by rendering the final state
/// immediately, which is the correct behaviour: skip the motion, never
/// the content.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 24,
    this.duration = AppMotion.slow,
  });

  final Widget child;
  final Duration delay;

  /// How far below its final position the child starts, in logical pixels.
  final double offset;

  final Duration duration;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  late final Animation<double> _curved = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.enter,
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    if (reducedMotion(context)) {
      // Jump straight to the finished state.
      _controller.value = 1;
      return;
    }

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        // The screen may have been popped during the delay.
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curved,
      // The child is built once and reused every frame rather than
      // rebuilt 60 times a second.
      child: widget.child,
      builder: (context, child) {
        return Opacity(
          opacity: _curved.value,
          child: Transform.translate(
            offset: Offset(0, (1 - _curved.value) * widget.offset),
            child: child,
          ),
        );
      },
    );
  }
}
