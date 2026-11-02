import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/seedly_theme.dart';
import 'seedly_avatar.dart';
import 'seedly_tag.dart';

/// Figma "Inicio" header: the person's avatar and greeting on the left, the
/// drops they have collected on the right.
class SeedlyHomeHeader extends StatelessWidget {
  const SeedlyHomeHeader({
    super.key,
    required this.initials,
    required this.drops,
    this.name,
    this.photo,
    this.onDropsTap,
  });

  /// First name for "Hola, Rober"; without one the greeting stands alone.
  final String? name;
  final String initials;
  final Uint8List? photo;

  /// Every drop collected, shown in the tag.
  final int drops;
  final VoidCallback? onDropsTap;

  static const height = 56.0;

  @override
  Widget build(BuildContext context) {
    final name = this.name;
    return SizedBox(
      height: height,
      child: Row(
        spacing: 12,
        children: [
          SeedlyAvatar(
            icon: 'assets/images/menu_profile.svg',
            initials: initials,
            photo: photo,
            photoLabel: 'Tu foto de perfil',
            size: height,
            padding: 4,
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name == null || name.isEmpty ? 'Hola' : 'Hola, $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    height: 28 / 18,
                    fontWeight: FontWeight.w700,
                    color: SeedlyPalette.neutral[900],
                  ),
                ),
                Text(
                  'Bienvenido de nuevo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    color: SeedlyPalette.neutral[900],
                  ),
                ),
              ],
            ),
          ),
          SeedlyTag(
            label: '$drops',
            semanticLabel: drops == 1 ? '1 gota' : '$drops gotas',
            size: SeedlyTagSize.small,
            icon: 'assets/images/icon_raindrop.svg',
            onTap: onDropsTap,
          ),
        ],
      ),
    );
  }
}
