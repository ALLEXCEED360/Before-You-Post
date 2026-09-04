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

/// One row in the findings list (outline sections 13 and 18).
///
/// The switch is the human-in-the-loop moment: the app suggests, the
/// person decides. Nothing is hidden without their say-so.
class FindingCard extends StatelessWidget {
  const FindingCard({
    super.key,
    required this.finding,
    required this.onSelectedChanged,
  });

  final PrivacyFinding finding;
  final ValueChanged<bool> onSelectedChanged;

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
          child: Row(
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
                  color: finding.selected ? accent : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(finding.type.label, style: theme.textTheme.titleSmall),
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
              // The switch is inside a Semantics wrapper so a screen
              // reader announces which finding it belongs to, rather than
              // five identical unlabelled switches.
              Semantics(
                label: 'Hide ${finding.type.label}',
                child: Switch(
                  value: finding.selected,
                  onChanged: onSelectedChanged,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
