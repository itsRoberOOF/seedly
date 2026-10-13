import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/seedly_theme.dart';

/// Figma "Card-Icon+Info" (Type=With icon, Size=Large): a tappable card with
/// an icon tile, a title, helper text and a trailing arrow.
class SeedlyOptionCard extends StatelessWidget {
  const SeedlyOptionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  /// 32px SVG asset shown in the icon tile.
  final String icon;
  final String title;
  final String description;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(SeedlyMetrics.radii['lg']!);
    const shadow = BoxShadow(
      color: SeedlyPalette.shadow,
      offset: Offset(0, 2),
      blurRadius: 4,
      spreadRadius: -2,
    );
    return Semantics(
      button: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          // Figma stacks the default shadow twice on this card.
          boxShadow: const [shadow, shadow],
        ),
        child: Material(
          color: SeedlyPalette.neutral[50],
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: const BorderSide(color: SeedlyPalette.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              // Figma's Large card (64px tile, 32px icons, 32px right
              // padding) left too little room for text on phones, so the
              // tile and arrow use the Default card's 48/24px sizes.
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              child: Row(
                spacing: 12,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: SeedlyPalette.neutral[200],
                      borderRadius: BorderRadius.circular(
                        SeedlyMetrics.radii['md']!,
                      ),
                    ),
                    child: SvgPicture.asset(
                      icon,
                      width: 24,
                      height: 24,
                      colorFilter: ColorFilter.mode(
                        SeedlyPalette.primary[600]!,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        // Figma's Large card uses 18/28 and 14/20, which made
                        // the cards too tall on phones; these are one step
                        // down the type scale.
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            height: 24 / 16,
                            fontWeight: FontWeight.w600,
                            color: SeedlyPalette.neutral[850],
                          ),
                        ),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 12,
                            height: 16 / 12,
                            color: SeedlyPalette.neutral[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SvgPicture.asset(
                    'assets/images/card_arrow_right.svg',
                    width: 24,
                    height: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
