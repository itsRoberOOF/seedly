import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/seedly_theme.dart';
import 'seedly_alert.dart';

/// Figma "Header": a back arrow and a centred title. Floating alerts open
/// below the arrow so it can always be tapped.
class SeedlyHeader extends StatelessWidget {
  const SeedlyHeader({super.key, required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              height: 28 / 18,
              fontWeight: FontWeight.w600,
              color: SeedlyPalette.neutral[900],
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            // The 32px arrow keeps its Figma size inside a 48px tap target.
            child: OverflowBox(
              maxWidth: 48,
              maxHeight: 48,
              alignment: Alignment.centerLeft,
              child: SeedlyAlertKeepClear(
                child: IconButton(
                  tooltip: 'Volver',
                  onPressed: onBack,
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    alignment: Alignment.centerLeft,
                  ),
                  icon: SvgPicture.asset(
                    'assets/images/icon_arrow_left.svg',
                    width: 32,
                    height: 32,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
