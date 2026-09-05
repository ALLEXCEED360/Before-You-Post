import 'package:flutter/material.dart';

import '../models/privacy_finding.dart';
import '../theme/app_theme.dart';

/// Icon for each kind of finding.
///
/// Lives in the widget layer, not the model: PrivacyFinding is plain data
/// and should not depend on Flutter.
IconData iconForFinding(FindingType type) => switch (type) {
  FindingType.face => Icons.face_outlined,
  FindingType.phoneNumber => Icons.phone_outlined,
  FindingType.email => Icons.alternate_email,
  FindingType.url => Icons.link,
  FindingType.cardNumber => Icons.credit_card,
  FindingType.address => Icons.home_outlined,
  FindingType.qrCode => Icons.qr_code_2,
  FindingType.manual => Icons.crop_square,
};

IconData iconForMethod(RedactionMethod method) => switch (method) {
  RedactionMethod.blur => Icons.blur_on,
  RedactionMethod.pixelate => Icons.grid_view,
  RedactionMethod.blackout => Icons.square_rounded,
};

String labelForMethod(RedactionMethod method) => switch (method) {
  RedactionMethod.blur => 'Blur',
  RedactionMethod.pixelate => 'Pixelate',
  RedactionMethod.blackout => 'Blackout',
};

/// One row in the findings list (outline sections 13, 14 and 18).
///
/// The switch is the human-in-the-loop moment: the app suggests, the
/// person decides. Nothing is hidden without their say-so.
class FindingCard extends StatelessWidget {
  const FindingCard({
    super.key,
    required this.finding,
    required this.onSelectedChanged,
    required this.onMethodChanged,
  });

  final PrivacyFinding finding;
  final ValueChanged<bool> onSelectedChanged;
  final ValueChanged<RedactionMethod> onMethodChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantics = context.semantics;

    final accent = finding.type == FindingType.face
        ? scheme.primary
        : semantics.risk;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onSelectedChanged(!finding.selected),
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
                  AnimatedContainer(
                    duration: AppMotion.fast,
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accent.withValues(
                        alpha: finding.selected ? 0.18 : 0.08,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      iconForFinding(finding.type),
                      size: 20,
                      color: finding.selected
                          ? accent
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          finding.type.label,
                          style: theme.textTheme.titleSmall,
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
                    label: 'Hide ${finding.type.label}',
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
