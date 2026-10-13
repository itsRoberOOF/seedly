import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/seedly_theme.dart';

/// Figma "Avatar" (Size=XXXXL, Type=Icon): a 120px round icon with an
/// optional edit button on its lower right.
class SeedlyAvatar extends StatelessWidget {
  const SeedlyAvatar({super.key, required this.icon, this.photo, this.onEdit});

  /// SVG asset drawn in the avatar's centre.
  final String icon;

  /// An image that fills the circle instead of [icon].
  final Uint8List? photo;

  /// Shows the edit button when set.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: 120,
      height: 120,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: SeedlyPalette.neutral[50],
        shape: BoxShape.circle,
        boxShadow: SeedlyShadows.card,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: SeedlyPalette.primary[50],
          shape: BoxShape.circle,
        ),
        child: photo != null
            ? ClipOval(
                child: Image.memory(
                  photo!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  gaplessPlayback: true,
                  semanticLabel: 'Imagen del proyecto',
                ),
              )
            : Center(
                child: SvgPicture.asset(
                  icon,
                  width: 64,
                  height: 64,
                  colorFilter: ColorFilter.mode(
                    SeedlyPalette.primary[600]!,
                    BlendMode.srcIn,
                  ),
                ),
              ),
      ),
    );
    if (onEdit == null) return avatar;
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: _EditButton(onPressed: onEdit!),
          ),
        ],
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Cambiar imagen',
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: SeedlyPalette.neutral[50],
          shape: BoxShape.circle,
          boxShadow: SeedlyShadows.floating,
        ),
        child: Material(
          color: SeedlyPalette.primary[500],
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: SvgPicture.asset(
                'assets/images/icon_edit_pencil.svg',
                width: 20,
                height: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
