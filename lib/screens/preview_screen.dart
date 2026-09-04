import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A temporary screen that proves the image loaded correctly.
///
/// This becomes the Editor Screen (outline section 19) once detectors exist.
/// For now its job is Phase 2 of the roadmap: load an image, display it,
/// and know its true pixel dimensions.
class PreviewScreen extends StatefulWidget {
  const PreviewScreen({super.key, required this.imagePath});

  final String imagePath;

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  /// Started once in initState, not in build. A Future created inside build
  /// would restart on every rebuild - a classic FutureBuilder mistake.
  late final Future<ui.Image> _decoded;

  @override
  void initState() {
    super.initState();
    _decoded = _decodeImage();
  }

  Future<ui.Image> _decodeImage() async {
    final bytes = await File(widget.imagePath).readAsBytes();
    return decodeImageFromList(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Image preview')),
      body: Column(
        children: [
          // Expanded tells the Column "give this child all the leftover
          // vertical space", so the footer below always stays visible.
          Expanded(
            child: ColoredBox(
              color: Colors.black,
              child: SizedBox(
                width: double.infinity,
                child: InteractiveViewer(
                  child: Image.file(
                    File(widget.imagePath),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FutureBuilder<ui.Image>(
              future: _decoded,
              builder: (context, snapshot) {
                final String label;
                if (snapshot.hasError) {
                  label = 'Could not read image dimensions';
                } else if (!snapshot.hasData) {
                  label = 'Reading image...';
                } else {
                  final image = snapshot.data!;
                  label = 'Original image: ${image.width} x ${image.height} px';
                }
                return Text(label, style: theme.textTheme.bodyMedium);
              },
            ),
          ),
        ],
      ),
    );
  }
}
