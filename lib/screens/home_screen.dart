import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';
import '../widgets/fade_slide_in.dart';
import 'analysis_screen.dart';

/// Screen 1 of 5: the landing screen (outline section 16).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();

  bool _picking = false;

  Future<void> _pickImage(ImageSource source) async {
    if (_picking) return;
    setState(() => _picking = true);

    try {
      final XFile? file = await _picker.pickImage(source: source);
      if (file == null) return;

      // After an await, this widget may no longer be on screen.
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AnalysisScreen(imagePath: file.path)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open that image: $error')),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantics = context.semantics;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: semantics.heroGradient,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xl,
            ),
            // A scroll view rather than a fixed Column: on a small phone
            // with the largest system font, this content genuinely does
            // not fit, and overflow stripes are not an acceptable answer.
            //
            // Note there are no Spacer widgets here. Spacer is an
            // Expanded, and Expanded needs a bounded height to expand
            // into - a scroll view offers infinite height, so the two
            // cannot be combined. Centring plus explicit gaps is the
            // pattern that works in a scrollable.
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                // Fill the viewport when the content is short, so the
                // centring has room to work; scroll when it is tall.
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const FadeSlideIn(child: Center(child: _ShieldBadge())),
                      const SizedBox(height: AppSpacing.xl),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 90),
                        child: Text(
                          'Before You Post',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.displaySmall,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 150),
                        child: Text(
                          'Check a photo for faces, personal details and QR '
                          'codes before it goes public.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 230),
                        child: _ActionCard(
                          icon: Icons.photo_library_outlined,
                          title: 'Choose photo',
                          subtitle: 'Pick an image from your gallery',
                          enabled: !_picking,
                          onTap: () => _pickImage(ImageSource.gallery),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 290),
                        child: _ActionCard(
                          icon: Icons.photo_camera_outlined,
                          title: 'Take photo',
                          subtitle: 'Capture something new',
                          enabled: !_picking,
                          onTap: () => _pickImage(ImageSource.camera),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 350),
                        child: _OnDeviceNote(color: semantics.safe),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The shield, with a slow halo behind it.
///
/// This is the one continuously animated element in the app. Everything
/// else moves only in response to something the user did.
class _ShieldBadge extends StatefulWidget {
  const _ShieldBadge();

  @override
  State<_ShieldBadge> createState() => _ShieldBadgeState();
}

class _ShieldBadgeState extends State<_ShieldBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // A halo that breathes forever is exactly the kind of motion that
    // reduce-motion exists to switch off.
    if (!reducedMotion(context)) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // RepaintBoundary keeps this animation from repainting the whole
    // screen on every frame.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_controller.value);
          return Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primaryContainer.withValues(alpha: 0.35),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.10 + 0.10 * t),
                  blurRadius: 32 + 16 * t,
                  spreadRadius: 2 + 6 * t,
                ),
              ],
            ),
            child: Icon(Icons.shield_outlined, size: 60, color: scheme.primary),
          );
        },
      ),
    );
  }
}

/// A large, tappable card. Bigger and friendlier than a plain button,
/// and it has room to say what the action actually does.
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.enabled,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AnimatedOpacity(
      duration: AppMotion.fast,
      opacity: enabled ? 1 : 0.5,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // A null callback disables the ripple as well as the tap, so a
          // disabled card cannot look tappable.
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: scheme.onPrimaryContainer),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: scheme.onSurfaceVariant,
                  // Decorative: the card already has a visible label.
                  semanticLabel: null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The honesty line (outline section 22).
///
/// Worded as what the app does - analysis happens on the device - rather
/// than an absolute promise that no data can ever leave it. The stronger
/// claim would need every dependency audited first.
class _OnDeviceNote extends StatelessWidget {
  const _OnDeviceNote({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline, size: 16, color: color),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            'Photos are analysed on your device',
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
