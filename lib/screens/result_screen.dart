import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_theme.dart';
import '../widgets/fade_slide_in.dart';

/// Screen 5 of 5: the result (outline section 20).
///
/// Shows the protected copy. The original file on disk is untouched -
/// these bytes are a new image held in memory, and nothing is written
/// anywhere until the user asks for it (outline section 32).
class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.imageBytes,
    required this.hiddenCount,
  });

  final Uint8List imageBytes;
  final int hiddenCount;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  /// One flag for both actions: saving and sharing are quick, and letting
  /// the user start both at once would write the same image twice.
  bool _busy = false;

  bool get _isPng {
    final bytes = widget.imageBytes;
    return bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;
  }

  /// The redaction engine keeps PNG as PNG and everything else as JPEG,
  /// so the extension is read back off the bytes rather than tracked.
  String get _extension => _isPng ? 'png' : 'jpg';

  String get _fileName =>
      'before_you_post_${DateTime.now().millisecondsSinceEpoch}';

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      // Android 10+ needs no permission for this; on older versions gal
      // asks. Checking first avoids a pointless prompt on modern phones.
      if (!await Gal.hasAccess()) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          _say('Permission denied, so the image was not saved.');
          return;
        }
      }

      await Gal.putImageBytes(widget.imageBytes, name: _fileName);
      _say('Saved to your gallery.');
    } catch (error) {
      _say('Could not save the image: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      // The share sheet hands another app a file, so the bytes have to
      // land on disk first. This goes to the app's own temporary
      // directory, not the gallery: sharing should not silently also save.
      final directory = await Directory.systemTemp.createTemp('byp_share');
      final file = File('${directory.path}/$_fileName.$_extension');
      await file.writeAsBytes(widget.imageBytes, flush: true);

      if (!mounted) return;

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], subject: 'Protected image'),
      );
    } catch (error) {
      _say('Could not share the image: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
                  child: Image.memory(widget.imageBytes, fit: BoxFit.contain),
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
                              widget.hiddenCount == 1
                                  ? '1 area hidden'
                                  : '${widget.hiddenCount} areas hidden',
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
                            onPressed: _busy ? null : _save,
                            icon: const Icon(Icons.download_outlined),
                            label: const Text('Save'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : _share,
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
                      onPressed: _busy
                          ? null
                          : () =>
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
