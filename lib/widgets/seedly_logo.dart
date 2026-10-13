import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/seedly_theme.dart';

/// The two logo components from Seedly's Figma design system.
class SeedlyLogo extends StatelessWidget {
  const SeedlyLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 164,
          height: 164,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: SeedlyPalette.neutral[50],
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Color(0x30000000),
                blurRadius: 5,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: SvgPicture.asset(
            'assets/images/seedly_logo_icon.svg',
            width: 108,
            height: 108,
            semanticsLabel: 'Icono de Seedly',
          ),
        ),
        const SizedBox(height: 13),
        Text(
          'Seedly',
          style: SeedlyTheme.logoTextStyle.copyWith(fontSize: 88, height: 1),
        ),
      ],
    );
  }
}
