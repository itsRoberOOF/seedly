import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/seedly_theme.dart';

/// Figma "Card-icon" (Size=Giant, Style=Card) with its label below: a 64px
/// white tile holding a 32px icon. [selected] outlines it in brand green.
class SeedlyIconTile extends StatelessWidget {
  const SeedlyIconTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final String icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(SeedlyMetrics.radii['lg']!);
    final accent = SeedlyPalette.primary[500]!;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: SeedlyPalette.neutral[50],
                borderRadius: radius,
                border: Border.all(
                  color: selected ? accent : SeedlyPalette.border,
                  width: selected ? 1.5 : 1,
                ),
                boxShadow: SeedlyShadows.card,
              ),
              child: SvgPicture.asset(
                icon,
                width: 32,
                height: 32,
                colorFilter: ColorFilter.mode(
                  selected ? accent : SeedlyPalette.neutral[850]!,
                  BlendMode.srcIn,
                ),
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                height: 24 / 16,
                color: selected ? accent : SeedlyPalette.neutral[900],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
