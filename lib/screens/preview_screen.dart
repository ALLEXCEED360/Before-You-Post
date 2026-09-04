import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/privacy_finding.dart';
import '../services/privacy_engine.dart';
import '../widgets/detection_overlay.dart';

/// Everything one analysis run produces. A Dart record - a lightweight
/// tuple with named fields, so we can return two values without inventing
/// a class for them.
typedef Analysis = ({ui.Image image, PrivacyScan scan});

/// Phases 3-5: decode the image, run every detector, draw the results.
class PreviewScreen extends StatefulWidget {
  const PreviewScreen({super.key, required this.imagePath});

  final String imagePath;

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  final PrivacyEngine _engine = PrivacyEngine();

  late final Future<Analysis> _analysis;

  /// Debug aid, toggled from the app bar.
  bool _showAllText = false;

  @override
  void initState() {
    super.initState();
    _analysis = _analyse();
  }

  @override
  void dispose() {
    // The detectors hold native ML Kit objects. Leaking them leaks memory
    // outside the Dart heap, where the garbage collector cannot help.
    _engine.dispose();
    super.dispose();
  }

  Future<Analysis> _analyse() async {
    final bytes = await File(widget.imagePath).readAsBytes();
    final image = await decodeImageFromList(bytes);
    final scan = await _engine.analyse(widget.imagePath);
    return (image: image, scan: scan);
  }

  @override
  Widget build(BuildContext context) {
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
      body: FutureBuilder<Analysis>(
        future: _analysis,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _Message(
              icon: Icons.error_outline,
              text: 'Could not analyse this image.\n${snapshot.error}',
            );
          }
          if (!snapshot.hasData) {
            return const _Message(
              icon: Icons.hourglass_empty,
              text: 'Analysing image...',
              showSpinner: true,
            );
          }
          return _Result(
            imagePath: widget.imagePath,
            analysis: snapshot.requireData,
            showAllText: _showAllText,
          );
        },
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    required this.imagePath,
    required this.analysis,
    required this.showAllText,
  });

  final String imagePath;
  final Analysis analysis;
  final bool showAllText;

  /// Turns the findings into "1 face, 2 phone numbers".
  String _summary(List<PrivacyFinding> findings) {
    if (findings.isEmpty) return 'No potential risks detected';

    final counts = <FindingType, int>{};
    for (final finding in findings) {
      counts[finding.type] = (counts[finding.type] ?? 0) + 1;
    }

    final parts = counts.entries
        .map((e) => '${e.value} ${e.key.label.toLowerCase()}${e.value == 1 ? "" : "s"}')
        .join(', ');

    return '${findings.length} potential '
        '${findings.length == 1 ? "risk" : "risks"}: $parts';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = analysis.image;
    final scan = analysis.scan;
    final imageSize = Size(image.width.toDouble(), image.height.toDouble());

    return Column(
      children: [
        Expanded(
          child: ColoredBox(
            color: Colors.black,
            child: InteractiveViewer(
              child: Center(
                // AspectRatio is the trick that keeps the maths honest:
                // it sizes this box to the image's exact proportions, so
                // the image fills it edge to edge with no letterboxing.
                // The overlay can then use one scale factor and no offset.
                child: AspectRatio(
                  aspectRatio: imageSize.width / imageSize.height,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(File(imagePath), fit: BoxFit.fill),
                      DetectionOverlay(
                        findings: scan.findings,
                        imageSize: imageSize,
                        debugTextBounds: showAllText
                            ? [for (final line in scan.textLines) line.bounds]
                            : const [],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                _summary(scan.findings),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '${image.width} x ${image.height} px  -  '
                '${scan.textLines.length} text lines read',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    this.showSpinner = false,
  });

  final IconData icon;
  final String text;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showSpinner)
              const CircularProgressIndicator()
            else
              Icon(icon, size: 48),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
