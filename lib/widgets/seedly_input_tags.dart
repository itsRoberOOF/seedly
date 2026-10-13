import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/seedly_theme.dart';

/// A quick choice inside [SeedlyInputTags].
class SeedlyInputTag {
  const SeedlyInputTag({
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool selected;
}

/// Figma "Input Tags": an input-like card whose top row opens a picker
/// ([onTap]) and whose bottom row offers quick choices as small tags. The
/// selected tag fills green.
class SeedlyInputTags extends StatelessWidget {
  const SeedlyInputTags({
    super.key,
    required this.label,
    required this.placeholder,
    required this.icon,
    required this.tags,
    this.value,
    this.onTap,
    this.enabled = true,
  });

  final String label;
  final String placeholder;

  /// Shown instead of [placeholder] once something is chosen.
  final String? value;

  /// SVG asset on the right of the top row.
  final String icon;
  final List<SeedlyInputTag> tags;
  final VoidCallback? onTap;

  /// Greys the field out and ignores taps, e.g. until a prerequisite is set.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(SeedlyMetrics.radii['lg']!);
    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: enabled ? SeedlyShadows.card : null,
      ),
      child: Material(
        color: enabled ? SeedlyPalette.neutral[50] : SeedlyPalette.neutral[150],
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: SeedlyPalette.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: onTap != null && enabled,
              label: '$label, ${value ?? placeholder}',
              excludeSemantics: true,
              child: InkWell(
                onTap: enabled ? onTap : null,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 10),
                  child: Row(
                    spacing: 10,
                    children: [
                      Expanded(
                        child: Text(
                          value ?? placeholder,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            height: 24 / 16,
                            color: value == null || !enabled
                                ? SeedlyPalette.neutral[600]
                                : SeedlyPalette.neutral[850],
                          ),
                        ),
                      ),
                      Opacity(
                        opacity: enabled ? 1 : 0.4,
                        child: SvgPicture.asset(icon, width: 24, height: 24),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Row(
                spacing: 8,
                children: [
                  for (final tag in tags) _SmallTag(tag: tag, enabled: enabled),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            height: 24 / 16,
            fontWeight: FontWeight.w500,
            color: SeedlyPalette.neutral[850],
          ),
        ),
        card,
      ],
    );
  }
}

/// Figma "Tag" (Size=Small, Style=Brand-soft).
class _SmallTag extends StatelessWidget {
  const _SmallTag({required this.tag, required this.enabled});

  final SeedlyInputTag tag;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    const pill = BorderRadius.all(Radius.circular(999));
    final selected = tag.selected && enabled;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: !enabled
            ? SeedlyPalette.neutral[200]
            : selected
            ? SeedlyPalette.primary[500]
            : SeedlyPalette.primary[50],
        borderRadius: pill,
        child: InkWell(
          borderRadius: pill,
          onTap: enabled ? tag.onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              tag.label,
              style: TextStyle(
                fontSize: 12,
                height: 16 / 12,
                fontWeight: FontWeight.w600,
                color: !enabled
                    ? SeedlyPalette.neutral[600]
                    : selected
                    ? SeedlyPalette.neutral[50]
                    : SeedlyPalette.neutral[850],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
