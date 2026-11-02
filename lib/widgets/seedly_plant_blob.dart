import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'seedly_plant.dart';

/// Figma "Planta": the cactus mascot standing on the grey Blob-6, a 300×331
/// frame with the mascot 14px below its top. [scale] shrinks the whole frame,
/// keeping its proportions.
class SeedlyPlantBlob extends StatelessWidget {
  const SeedlyPlantBlob({
    super.key,
    required this.phase,
    this.watering = false,
    this.scale = 1,
  }) : assert(scale > 0, 'The frame needs a positive scale');

  final int phase;
  final bool watering;

  /// 1 is Figma's size.
  final double scale;

  static const width = 300.0;
  static const height = 331.0;

  /// How far down the mascot starts, and how tall it is, in the frame.
  static const mascotTop = 14.0;
  static const mascotHeight = 303.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width * scale,
      height: height * scale,
      child: Stack(
        children: [
          SvgPicture.asset(
            'assets/images/home_plant_blob.svg',
            width: width * scale,
            height: height * scale,
            excludeFromSemantics: true,
          ),
          Positioned(
            top: mascotTop * scale,
            left: 0,
            right: 0,
            height: mascotHeight * scale,
            child: Center(
              child: SeedlyPlant(phase: phase, watering: watering),
            ),
          ),
        ],
      ),
    );
  }
}
