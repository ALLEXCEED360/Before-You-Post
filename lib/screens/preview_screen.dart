import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/privacy_finding.dart';
import '../services/face_detection_service.dart';
import '../widgets/detection_overlay.dart';

/// Everything one analysis run produces. A Dart record - a lightweight
/// tuple with named fields, so we can return two values without inventing
/// a class for them.
typedef Analysis = ({ui.Image image, List<PrivacyFinding> findings});

/// Phase 3: decode the image, run face detection, draw the results.
class PreviewScreen extends StatefulWidget {
  const PreviewScreen({super.key, required this.imagePath});

  final String imagePath;

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  final FaceDetectionService _faces = FaceDetectionService();

  late final Future<Analysis> _analysis;

  @override
  void initState() {
    super.initState();
    _analysis = _analyse();
  }

  @override
  void dispose() {
    // ML Kit holds a native detector. Leaking it leaks memory outside
    // the Dart heap, which the garbage collector cannot help with.
    _faces.dispose();
    super.dispose();
  }

  Future<Analysis> _analyse() async {
    final bytes = await File(widget.imagePath).readAsBytes();
    final image = await decodeImageFromList(bytes);
    final findings = await _faces.detect(widget.imagePath);
    return (image: image, findings: findings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy check')),
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
          );
        },
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.imagePath, required this.analysis});

  final String imagePath;
  final Analysis analysis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = analysis.image;
    final findings = analysis.findings;
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
                        findings: findings,
                        imageSize: imageSize,
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
                findings.isEmpty
                    ? 'No faces detected'
                    : '${findings.length} potential '
                        '${findings.length == 1 ? "risk" : "risks"} detected',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Original image: ${image.width} x ${image.height} px',
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
