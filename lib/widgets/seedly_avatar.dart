import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/seedly_theme.dart';

/// Figma "Avatar" (Size=XXXXL, Type=Icon): a 120px round icon with an
/// optional edit button on its lower right. The profile's is 140px.
class SeedlyAvatar extends StatelessWidget {
  const SeedlyAvatar({
    super.key,
    required this.icon,
    this.photo,
    this.onEdit,
    this.size = 120,
    this.editInset = 0,
  });

  /// SVG asset drawn in the avatar's centre.
  final String icon;

  /// An image that fills the circle instead of [icon].
  final Uint8List? photo;

  /// Shows the edit button when set.
  final VoidCallback? onEdit;

  /// Diameter of the circle.
  final double size;

  /// How far the edit button sits in from the circle's lower right.
  final double editInset;

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: size,
      height: size,
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
                  width: size * 64 / 120,
                  height: size * 64 / 120,
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
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: editInset,
            bottom: editInset,
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
