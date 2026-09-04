import 'dart:io';

import 'package:flutter/material.dart';

import '../services/privacy_engine.dart';
import '../theme/app_theme.dart';
import '../widgets/fade_slide_in.dart';
import 'editor_screen.dart';

/// Screen 2 of 5: the analysis screen (outline section 17).
///
/// The point of this screen is honesty about progress. One opaque spinner
/// tells the user nothing; ticking off each detector as it lands shows
/// that work is actually happening and roughly how much is left.
class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key, required this.imagePath});

  final String imagePath;

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final PrivacyEngine _engine = PrivacyEngine();

  final Set<DetectorKind> _done = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    // Closes the native ML Kit detectors. Safe here: by the time this
    // screen is replaced we already hold the finished results.
    _engine.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final image = await decodeImageFromList(bytes);

      final scan = await _engine.analyse(
        widget.imagePath,
        onDetectorDone: (kind) {
          if (mounted) setState(() => _done.add(kind));
        },
      );

      if (!mounted) return;

      // Let the final tick land before moving on, otherwise the last
      // detector appears to never finish.
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      // pushReplacement, not push: the user should never land back on a
      // progress screen when they press back from the editor.
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => EditorScreen(
            imagePath: widget.imagePath,
            image: image,
            scan: scan,
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: _error != null
              ? _AnalysisError(message: _error!)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),
                    Center(
                      child: Hero(
                        tag: 'photo',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.file(
                            File(widget.imagePath),
                            width: 160,
                            height: 160,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Analysing image',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Everything runs on this device.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(
                          begin: 0,
                          end: _done.length / DetectorKind.values.length,
                        ),
                        duration: AppMotion.medium,
                        curve: AppMotion.enter,
                        builder: (context, value, _) =>
                            LinearProgressIndicator(value: value, minHeight: 6),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    for (final (index, kind) in DetectorKind.values.indexed)
                      FadeSlideIn(
                        delay: Duration(milliseconds: 80 * index),
                        child: _DetectorRow(
                          label: kind.label,
                          done: _done.contains(kind),
                        ),
                      ),
                    const Spacer(),
                    const Spacer(),
                  ],
                ),
        ),
      ),
    );
  }
}

/// One line of the checklist: spinner while running, tick when finished.
class _DetectorRow extends StatelessWidget {
  const _DetectorRow({required this.label, required this.done});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safe = context.semantics.safe;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: AnimatedSwitcher(
              duration: AppMotion.medium,
              // Scale the tick in so the state change is felt, not just
              // seen. Swapping icons with no transition reads as a glitch.
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: done
                  ? Icon(
                      Icons.check_circle,
                      key: const ValueKey('done'),
                      color: safe,
                      size: 24,
                    )
                  : const SizedBox(
                      key: ValueKey('busy'),
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: done
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalysisError extends StatelessWidget {
  const _AnalysisError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: context.semantics.risk),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Could not analyse this image',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Go back'),
          ),
        ],
      ),
    );
  }
}
