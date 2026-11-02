import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/seedly_theme.dart';

/// Figma's Tag sizes: Medium reads at 14px, Small at 12px.
enum SeedlyTagSize { small, medium }

/// Figma "Tag" (Style=Card): a tappable white pill, optionally with an icon
/// before the label.
class SeedlyTag extends StatelessWidget {
  const SeedlyTag({
    super.key,
    required this.label,
    required this.onTap,
    this.size = SeedlyTagSize.medium,
    this.icon,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onTap;
  final SeedlyTagSize size;

  /// Figma's "Icon" property: a 20px SVG asset, drawn in its own colours.
  final String? icon;

  /// What a screen reader says in place of [label], like "350 gotas".
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    const pill = BorderRadius.all(Radius.circular(999));
    final (padding, fontSize, lineHeight) = switch (size) {
      SeedlyTagSize.small => (
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        12.0,
        16.0,
      ),
      SeedlyTagSize.medium => (
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        14.0,
        20.0,
      ),
    };
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: pill,
        boxShadow: SeedlyShadows.tag,
      ),
      child: Material(
        color: SeedlyPalette.neutral[50],
        shape: RoundedRectangleBorder(
          borderRadius: pill,
          side: BorderSide(color: SeedlyPalette.neutral[200]!),
        ),
        child: InkWell(
          borderRadius: pill,
          onTap: onTap,
          child: Padding(
            padding: padding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                if (icon != null)
                  SvgPicture.asset(icon!, width: 20, height: 20),
                Text(
                  label,
                  semanticsLabel: semanticLabel,
                  style: TextStyle(
                    fontSize: fontSize,
                    height: lineHeight / fontSize,
                    fontWeight: FontWeight.w600,
                    color: SeedlyPalette.neutral[850],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
