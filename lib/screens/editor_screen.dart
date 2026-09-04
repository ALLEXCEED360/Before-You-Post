import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/privacy_finding.dart';
import '../services/privacy_engine.dart';
import '../theme/app_theme.dart';
import '../widgets/detection_overlay.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/finding_card.dart';

/// Screen 4 of 5: the editor (outline section 19).
///
/// Receives a finished scan rather than running one, so this screen is
/// only ever about review. Analysis lives on the screen before it.
class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    required this.imagePath,
    required this.image,
    required this.scan,
  });

  final String imagePath;
  final ui.Image image;
  final PrivacyScan scan;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  /// A mutable copy. The scan result itself stays untouched, so we can
  /// always tell what was detected versus what the user chose.
  late List<PrivacyFinding> _findings = List.of(widget.scan.findings);

  bool _showAllText = false;

  int get _hiddenCount => _findings.where((f) => f.selected).length;

  void _setSelected(int index, bool selected) {
    setState(() {
      _findings[index] = _findings[index].copyWith(selected: selected);
    });
  }

  void _setAll(bool selected) {
    setState(() {
      _findings = [
        for (final finding in _findings) finding.copyWith(selected: selected),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final imageSize = Size(
      widget.image.width.toDouble(),
      widget.image.height.toDouble(),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy check'),
        actions: [
          IconButton(
            tooltip: _showAllText
                ? 'Hide everything OCR read'
                : 'Show everything OCR read',
            icon: Icon(
              _showAllText ? Icons.text_fields : Icons.text_fields_outlined,
            ),
            onPressed: () => setState(() => _showAllText = !_showAllText),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: ColoredBox(
              color: context.semantics.canvas,
              child: InteractiveViewer(
                child: Center(
                  // AspectRatio is the trick that keeps the maths honest:
                  // it sizes this box to the image's exact proportions, so
                  // the image fills it edge to edge with no letterboxing.
                  // The overlay then needs one scale factor and no offset.
                  child: AspectRatio(
                    aspectRatio: imageSize.width / imageSize.height,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Hero(
                          tag: 'photo',
                          child: Image.file(
                            File(widget.imagePath),
                            fit: BoxFit.fill,
                          ),
                        ),
                        DetectionOverlay(
                          findings: _findings,
                          imageSize: imageSize,
                          debugTextBounds: _showAllText
                              ? [
                                  for (final line in widget.scan.textLines)
                                    line.bounds,
                                ]
                              : const [],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Flexible(
            flex: 2,
            child: _ReviewPanel(
              findings: _findings,
              hiddenCount: _hiddenCount,
              onSelectedChanged: _setSelected,
              onSetAll: _setAll,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewPanel extends StatelessWidget {
  const _ReviewPanel({
    required this.findings,
    required this.hiddenCount,
    required this.onSelectedChanged,
    required this.onSetAll,
  });

  final List<PrivacyFinding> findings;
  final int hiddenCount;
  final void Function(int index, bool selected) onSelectedChanged;
  final ValueChanged<bool> onSetAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: findings.isEmpty
              ? const _NothingFound()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            // "Potential" is deliberate (outline section
                            // 18). The scan assists; it does not certify.
                            '${findings.length} potential '
                            '${findings.length == 1 ? "risk" : "risks"}',
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              onSetAll(hiddenCount != findings.length),
                          child: Text(
                            hiddenCount == findings.length
                                ? 'Keep all'
                                : 'Hide all',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        itemCount: findings.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) => FadeSlideIn(
                          // Cap the stagger: past a handful of items the
                          // delay stops reading as polish and starts
                          // reading as lag.
                          delay: Duration(
                            milliseconds: 40 * (index.clamp(0, 6)),
                          ),
                          offset: 12,
                          child: FindingCard(
                            finding: findings[index],
                            onSelectedChanged: (value) =>
                                onSelectedChanged(index, value),
                          ),
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      // Redaction is the next phase. A button that
                      // silently does nothing is worse than one that is
                      // visibly not ready yet.
                      onPressed: null,
                      icon: const Icon(Icons.auto_fix_high),
                      label: Text(
                        hiddenCount == 0
                            ? 'Nothing selected to hide'
                            : 'Protect image ($hiddenCount)',
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _NothingFound extends StatelessWidget {
  const _NothingFound();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.verified_outlined,
            size: 40,
            color: context.semantics.safe,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('No potential risks found', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              'Automatic checks are not perfect. Review the image yourself '
              'before sharing it.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
