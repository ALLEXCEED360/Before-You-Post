import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/privacy_finding.dart';
import '../theme/app_theme.dart';
import 'finding_style.dart';
import 'region_thumbnail.dart';

/// One row in the findings list (outline sections 13, 14 and 18).
///
/// The switch is the human-in-the-loop moment: the app suggests, the
/// person decides. Nothing is hidden without their say-so.
class FindingCard extends StatelessWidget {
  const FindingCard({
    super.key,
    required this.finding,
    required this.image,
    required this.number,
    required this.highlighted,
    required this.onSelectedChanged,
    required this.onMethodChanged,
    required this.onTap,
  });

  final PrivacyFinding finding;

  /// The decoded photo, so the card can show the actual region.
  final ui.Image image;

  /// Matches the badge drawn on the image. This is what makes five
  /// identical "Face" rows tellable apart.
  final int number;

  final bool highlighted;

  final ValueChanged<bool> onSelectedChanged;
  final ValueChanged<RedactionMethod> onMethodChanged;

  /// Tapping the card points at this finding on the image.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantics = context.semantics;

    final accent = colorForFinding(finding.type, scheme, semantics.risk);

    return Card(
      clipBehavior: Clip.antiAlias,
      // A visible outline on the highlighted card, so the link between
      // list and image reads in both directions.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: highlighted
            ? BorderSide(color: accent, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _NumberedThumbnail(
                    image: image,
                    bounds: finding.bounds,
                    number: number,
                    color: accent,
                    dimmed: !finding.selected,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              iconForFinding(finding.type),
                              size: 15,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                finding.type.label,
                                style: theme.textTheme.titleSmall,
                              ),
                            ),
                          ],
                        ),
                        if (finding.detail != null)
                          Text(
                            finding.detail!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // Inside a Semantics wrapper so a screen reader
                  // announces which finding this switch belongs to,
                  // rather than several identical unlabelled switches.
                  Semantics(
                    label: 'Hide ${finding.type.label} $number',
                    child: Switch(
                      value: finding.selected,
                      onChanged: onSelectedChanged,
                    ),
                  ),
                ],
              ),
              // The method picker only exists while this finding is being
              // hidden - showing it for a kept finding would offer a
              // choice that does nothing. AnimatedSize makes the card
              // grow and shrink smoothly instead of snapping.
              AnimatedSize(
                duration: AppMotion.medium,
                curve: AppMotion.enter,
                alignment: Alignment.topCenter,
                child: finding.selected
                    ? Padding(
                        padding: const EdgeInsets.only(
                          top: AppSpacing.sm,
                          bottom: AppSpacing.xs,
                        ),
                        child: _MethodPicker(
                          value: finding.redaction,
                          onChanged: onMethodChanged,
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The region itself, with the number that matches the image badge.
class _NumberedThumbnail extends StatelessWidget {
  const _NumberedThumbnail({
    required this.image,
    required this.bounds,
    required this.number,
    required this.color,
    required this.dimmed,
  });

  final ui.Image image;
  final Rect bounds;
  final int number;
  final Color color;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        children: [
          AnimatedOpacity(
            duration: AppMotion.fast,
            opacity: dimmed ? 0.45 : 1,
            child: RegionThumbnail(image: image, bounds: bounds, size: 46),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: onFindingColor(color).withValues(alpha: 0.9),
                  width: 1.5,
                ),
              ),
              child: Text(
                '$number',
                style: TextStyle(
                  color: onFindingColor(color),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodPicker extends StatelessWidget {
  const _MethodPicker({required this.value, required this.onChanged});

  final RedactionMethod value;
  final ValueChanged<RedactionMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<RedactionMethod>(
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: [
        for (final method in RedactionMethod.values)
          ButtonSegment<RedactionMethod>(
            value: method,
            icon: Icon(iconForMethod(method), size: 18),
            // Icon-only segments need an accessible name, or a screen
            // reader announces three anonymous buttons.
            tooltip: labelForMethod(method),
            label: Text(labelForMethod(method)),
          ),
      ],
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}
