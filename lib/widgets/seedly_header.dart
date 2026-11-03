import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/seedly_theme.dart';
import 'seedly_alert.dart';

/// The icon button on the right of a [SeedlyHeader], such as the pencil or
/// the trash can.
class SeedlyHeaderAction {
  const SeedlyHeaderAction({
    required this.asset,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  /// SVG asset, drawn at 32px.
  final String asset;
  final String tooltip;
  final VoidCallback onPressed;

  /// Recolours the icon, for assets drawn in another colour.
  final Color? color;
}

/// Figma "Header": a back arrow, a centred title and, optionally, an
/// [action] on the right. Floating alerts open below the arrow so it can
/// always be tapped.
class SeedlyHeader extends StatelessWidget {
  const SeedlyHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.action,
  });

  final String title;
  final VoidCallback onBack;
  final SeedlyHeaderAction? action;

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
          if (action case final action?)
            Align(
              alignment: Alignment.centerRight,
              child: OverflowBox(
                maxWidth: 48,
                maxHeight: 48,
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: action.tooltip,
                  onPressed: action.onPressed,
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    alignment: Alignment.centerRight,
                  ),
                  icon: SvgPicture.asset(
                    action.asset,
                    width: 32,
                    height: 32,
                    colorFilter: action.color == null
                        ? null
                        : ColorFilter.mode(action.color!, BlendMode.srcIn),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
