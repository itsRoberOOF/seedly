import 'dart:math' as math;
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
          // The 36px button sits in a 48px touch target; the target grows
          // toward the circle's centre first so the button doesn't move.
          Positioned(
            right: math.max(0, editInset - _EditButton.reach),
            bottom: math.max(0, editInset - _EditButton.reach),
            child: _EditButton(
              onPressed: onEdit!,
              inset: math.min(editInset, _EditButton.reach),
            ),
          ),
        ],
      ),
    );
  }
}

/// The 36px edit button inside a 48px touch target (Material's minimum).
class _EditButton extends StatelessWidget {
  const _EditButton({required this.onPressed, required this.inset});

  /// Extra touch area on each side of the 36px button.
  static const reach = 6.0;
  static const _target = 48.0;

  final VoidCallback onPressed;

  /// How far the button sits in from the target's lower right.
  final double inset;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Tooltip(
        message: 'Cambiar imagen',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: SizedBox.square(
            dimension: _target,
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: EdgeInsets.only(right: inset, bottom: inset),
                // The 48px target above is the one assistive tech should see;
                // the inner ink well would add a 32px duplicate.
                child: ExcludeSemantics(
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
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
