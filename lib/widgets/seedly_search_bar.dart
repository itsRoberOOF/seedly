import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/seedly_theme.dart';

/// Figma "Search Bar": a white pill with a magnifier and a placeholder.
class SeedlySearchBar extends StatelessWidget {
  const SeedlySearchBar({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w500,
      color: SeedlyPalette.neutral[850],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SeedlyPalette.neutral[50],
        borderRadius: BorderRadius.circular(SeedlyMetrics.radii['full']!),
        boxShadow: SeedlyShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          spacing: 12,
          children: [
            SvgPicture.asset(
              'assets/images/icon_search.svg',
              width: 24,
              height: 24,
            ),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                style: style,
                textInputAction: TextInputAction.search,
                cursorColor: SeedlyPalette.primary[500],
                // The theme gives inputs a border and fill; this one is bare.
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: style.copyWith(color: SeedlyPalette.neutral[600]),
                  isDense: true,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
