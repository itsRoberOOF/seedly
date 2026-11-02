import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/seedly_theme.dart';
import 'seedly_progress_circle.dart';

/// Figma "Card-Icon+Info" (Size=Default): an icon tile beside a title, with
/// optional text above and below it.
///
/// The trailing end follows Figma's Type: nothing for Default, an arrow for
/// With icon ([showArrow]), a ring for With progress ([progress]). A card
/// fills the width it is given; Figma's scroll cards are 260px wide.
class SeedlyInfoCard extends StatelessWidget {
  const SeedlyInfoCard({
    super.key,
    required this.icon,
    required this.title,
    this.superior,
    this.helper,
    this.progress,
    this.showArrow = false,
    this.onTap,
  }) : assert(
         progress == null || !showArrow,
         'A card ends in an arrow or a progress ring, not both.',
       );

  /// 24px SVG asset shown in the icon tile.
  final String icon;
  final String title;

  /// Figma's "Superior text": small caps above the title.
  final String? superior;

  /// Figma's "Helper text": small grey text under the title.
  final String? helper;

  /// Fills Figma's progress ring, from 0 to 1.
  final double? progress;
  final bool showArrow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(SeedlyMetrics.radii['lg']!);
    final trailing = progress != null
        ? SeedlyProgressCircle(progress: progress!)
        : showArrow
        ? SvgPicture.asset(
            'assets/images/card_arrow_right.svg',
            width: 24,
            height: 24,
          )
        : null;
    return Semantics(
      button: onTap != null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: SeedlyShadows.card,
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
              // Figma gives a card with nothing at its end 24px on the right.
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                trailing == null ? 24 : 16,
                12,
              ),
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
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 4,
                      children: [
                        if (superior != null)
                          Text(
                            superior!.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              height: 16 / 12,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 2,
                              color: SeedlyPalette.neutral[700],
                            ),
                          ),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            height: 24 / 16,
                            color: SeedlyPalette.neutral[850],
                          ),
                        ),
                        if (helper != null)
                          Text(
                            helper!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              height: 14 / 10,
                              color: SeedlyPalette.neutral[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
