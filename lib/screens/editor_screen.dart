import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/privacy_finding.dart';
import '../services/privacy_engine.dart';
import '../services/redaction_service.dart';
import '../theme/app_theme.dart';
import '../widgets/detection_overlay.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/finding_card.dart';
import 'result_screen.dart';

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
  final RedactionService _redaction = RedactionService();

  /// A mutable copy. The scan result itself stays untouched, so we can
  /// always tell what was detected versus what the user chose.
  late List<PrivacyFinding> _findings = List.of(widget.scan.findings);

  /// One key per finding, so tapping a box on the image can scroll that
  /// finding's card into view.
  late final Map<String, GlobalKey> _cardKeys = {
    for (final finding in _findings) finding.id: GlobalKey(),
  };

  bool _showAllText = false;
  bool _protecting = false;

  /// Where the finger went down on the photo, so a pan can be told from
  /// a tap. See the Listener in build() for why this is tracked by hand.
  Offset? _pointerDownAt;

  /// Which finding the user is currently pointing at, in either
  /// direction. Not a selection - just "this one".
  String? _highlightedId;

  int get _hiddenCount => _findings.where((f) => f.selected).length;

  void _setSelected(int index, bool selected) {
    setState(() {
      _findings[index] = _findings[index].copyWith(selected: selected);
      _highlightedId = _findings[index].id;
    });
  }

  void _setMethod(int index, RedactionMethod method) {
    setState(() {
      _findings[index] = _findings[index].copyWith(redaction: method);
      _highlightedId = _findings[index].id;
    });
  }

  void _setAll(bool selected) {
    setState(() {
      _findings = [
        for (final finding in _findings) finding.copyWith(selected: selected),
      ];
    });
  }

  void _highlight(String id, {required bool scrollToCard}) {
    setState(() => _highlightedId = id);

    if (!scrollToCard) return;

    final context = _cardKeys[id]?.currentContext;
    if (context == null) return;

    Scrollable.ensureVisible(
      context,
      duration: AppMotion.medium,
      curve: AppMotion.enter,
      alignment: 0.2,
    );
  }

  /// Turns a tap on the photo into the finding underneath it.
  ///
  /// Boxes overlap - a phone number can sit inside a larger detected
  /// block - so the SMALLEST region containing the point wins. Picking
  /// the first match would make small findings unreachable.
  void _handleImageTap(Offset pointInImage) {
    PrivacyFinding? best;

    for (final finding in _findings) {
      if (!finding.bounds.contains(pointInImage)) continue;
      final area = finding.bounds.width * finding.bounds.height;
      if (best == null || area < best.bounds.width * best.bounds.height) {
        best = finding;
      }
    }

    if (best == null) {
      // Tapping empty space clears the pointer rather than doing nothing.
      setState(() => _highlightedId = null);
      return;
    }

    _highlight(best.id, scrollToCard: true);
  }

  Future<void> _protect() async {
    if (_protecting) return;
    setState(() => _protecting = true);

    try {
      // Rendered from the ORIGINAL image plus the current instruction
      // list, never from a previous result (outline section 14).
      final bytes = await _redaction.redact(
        imagePath: widget.imagePath,
        // The pixels already on screen. Redacting the same buffer the
        // detectors measured is what keeps the boxes and the redaction in
        // one coordinate space, whatever the file format was.
        image: widget.image,
        findings: _findings,
      );

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ResultScreen(imageBytes: bytes, hiddenCount: _hiddenCount),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not protect this image: $error')),
      );
    } finally {
      if (mounted) setState(() => _protecting = false);
    }
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
          // A developer tool, not a feature. It answers "did OCR fail to
          // read this, or did the rules fail to classify it?" - two bugs
          // that look identical from the outside and need opposite fixes.
          //
          // Gated to debug builds: a user tapping it would just get
          // unexplained white boxes over their photo. kDebugMode is a
          // compile-time constant, so this disappears entirely from a
          // release build rather than merely being hidden.
          if (kDebugMode)
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
                    child: LayoutBuilder(
                      // A Listener, not a GestureDetector. InteractiveViewer
                      // wraps this subtree and its scale recogniser claims
                      // the pointer, so a child tap recogniser never fires -
                      // taps on the photo silently did nothing. Listener
                      // receives raw pointer events and never competes in
                      // the gesture arena, so both zooming and tapping work.
                      builder: (context, constraints) => Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (event) =>
                            _pointerDownAt = event.localPosition,
                        onPointerUp: (event) {
                          final down = _pointerDownAt;
                          _pointerDownAt = null;
                          if (down == null) return;

                          // Anything that moved was a pan or a pinch, not
                          // a tap on a face.
                          if ((event.localPosition - down).distance > 12) {
                            return;
                          }

                          // The inverse of what the overlay does when it
                          // draws: screen pixels back to image pixels,
                          // using the same single scale factor.
                          final local = event.localPosition;
                          _handleImageTap(
                            Offset(
                              local.dx * imageSize.width / constraints.maxWidth,
                              local.dy *
                                  imageSize.height /
                                  constraints.maxHeight,
                            ),
                          );
                        },
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
                              highlightedId: _highlightedId,
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
            ),
          ),
          Flexible(
            flex: 2,
            child: _ReviewPanel(
              findings: _findings,
              image: widget.image,
              cardKeys: _cardKeys,
              highlightedId: _highlightedId,
              hiddenCount: _hiddenCount,
              protecting: _protecting,
              onSelectedChanged: _setSelected,
              onMethodChanged: _setMethod,
              onSetAll: _setAll,
              onTapFinding: (id) => _highlight(id, scrollToCard: false),
              onProtect: _protect,
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
    required this.image,
    required this.cardKeys,
    required this.highlightedId,
    required this.hiddenCount,
    required this.protecting,
    required this.onSelectedChanged,
    required this.onMethodChanged,
    required this.onSetAll,
    required this.onTapFinding,
    required this.onProtect,
  });

  final List<PrivacyFinding> findings;
  final ui.Image image;
  final Map<String, GlobalKey> cardKeys;
  final String? highlightedId;
  final int hiddenCount;
  final bool protecting;
  final void Function(int index, bool selected) onSelectedChanged;
  final void Function(int index, RedactionMethod method) onMethodChanged;
  final ValueChanged<bool> onSetAll;
  final ValueChanged<String> onTapFinding;
  final VoidCallback onProtect;

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
                    Text(
                      'Tap the photo to find an item in this list.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Expanded(
                      // SingleChildScrollView + Column, not ListView.
                      //
                      // Scrollable.ensureVisible needs the target card's
                      // GlobalKey to have a context, which means the card
                      // must actually be built. ListView is lazy - even
                      // ListView(children: [...]) only creates elements
                      // for the visible range - so tapping face 8 of 20
                      // found no context and silently did not scroll.
                      // This builds every card. Findings number in the
                      // tens, so that is cheap.
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final (index, finding)
                                in findings.indexed) ...[
                              if (index > 0)
                                const SizedBox(height: AppSpacing.sm),
                              FadeSlideIn(
                                key: ValueKey('anim_${finding.id}'),
                                // Cap the stagger: past a handful of items
                                // the delay stops reading as polish and
                                // starts reading as lag.
                                delay: Duration(
                                  milliseconds: 40 * (index.clamp(0, 6)),
                                ),
                                offset: 12,
                                child: FindingCard(
                                  key: cardKeys[finding.id],
                                  finding: finding,
                                  image: image,
                                  number: index + 1,
                                  highlighted: finding.id == highlightedId,
                                  onSelectedChanged: (value) =>
                                      onSelectedChanged(index, value),
                                  onMethodChanged: (method) =>
                                      onMethodChanged(index, method),
                                  onTap: () => onTapFinding(finding.id),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      // Disabled with nothing selected: a button that
                      // produces an identical copy is not an action.
                      onPressed: hiddenCount == 0 || protecting
                          ? null
                          : onProtect,
                      icon: protecting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_fix_high),
                      label: Text(switch ((protecting, hiddenCount)) {
                        (true, _) => 'Protecting...',
                        (false, 0) => 'Nothing selected to hide',
                        (false, final count) => 'Protect image ($count)',
                      }),
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
