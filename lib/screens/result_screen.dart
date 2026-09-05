import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/fade_slide_in.dart';

/// Screen 5 of 5: the result (outline section 20).
///
/// Shows the protected copy. The original file on disk is untouched -
/// these bytes are a new image held in memory, and nothing is written
/// anywhere until the user asks for it (outline section 32).
class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.imageBytes,
    required this.hiddenCount,
  });

  final Uint8List imageBytes;
  final int hiddenCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantics = context.semantics;

    return Scaffold(
      appBar: AppBar(title: const Text('Protected image')),
      body: Column(
        children: [
          Expanded(
            child: ColoredBox(
              color: semantics.canvas,
              child: SizedBox(
                width: double.infinity,
                child: InteractiveViewer(
                  child: Image.memory(imageBytes, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
          Material(
            color: theme.colorScheme.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FadeSlideIn(
                      child: Row(
                        children: [
                          Icon(Icons.verified_outlined, color: semantics.safe),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              hiddenCount == 1
                                  ? '1 area hidden'
                                  : '$hiddenCount areas hidden',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      // Never claim the image is safe. The app hid what
                      // the user selected, nothing more (section 13).
                      'Your original photo is unchanged. Check the result '
                      'before sharing it.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            // Saving and sharing are the next phase.
                            onPressed: null,
                            icon: const Icon(Icons.download_outlined),
                            label: const Text('Save'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: null,
                            icon: const Icon(Icons.ios_share),
                            label: const Text('Share'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FilledButton.icon(
                      // popUntil isFirst returns to the home screen,
                      // discarding the analysis and editor routes so the
                      // back button cannot walk into a stale scan.
                      onPressed: () =>
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Analyse another'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
