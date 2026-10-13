import 'package:flutter/material.dart';

import '../theme/seedly_theme.dart';

/// Figma "Tag" (Size=Medium, Style=Card): a tappable white pill.
class SeedlyTag extends StatelessWidget {
  const SeedlyTag({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const pill = BorderRadius.all(Radius.circular(999));
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                height: 20 / 14,
                fontWeight: FontWeight.w600,
                color: SeedlyPalette.neutral[850],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
