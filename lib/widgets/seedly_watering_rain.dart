import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/seedly_theme.dart';

/// Drops falling on the pot during a watering session. Each one falls with
/// its own delay and splashes on the soil. Meant for a repeating [animation]:
/// the delays cover the whole cycle and time wraps around, so the rain never
/// pauses between laps.
class SeedlyWateringRain extends StatelessWidget {
  const SeedlyWateringRain({super.key, required this.animation});

  /// One lap of the rain.
  static const duration = Duration(milliseconds: 1600);

  static const dropAsset = 'assets/images/project_agua.svg';

  /// Where the soil is, as a fraction of the height: the pot rim sits at
  /// y≈278 of the plant SVGs' 500.
  static const soilLine = 278 / 500;

  /// (horizontal position, delay 0–1, size). Fixed so the rain looks even.
  static const _drops = [
    (0.30, 0.00, 20.0),
    (0.62, 0.06, 24.0),
    (0.45, 0.14, 18.0),
    (0.74, 0.20, 20.0),
    (0.24, 0.26, 22.0),
    (0.54, 0.32, 20.0),
    (0.38, 0.40, 24.0),
    (0.68, 0.46, 18.0),
  ];

  /// Share of the lap each drop takes to fall and splash.
  static const _fallSpan = 0.5;

  /// Share of each drop's life spent falling; the rest is the splash.
  static const _fallEnd = 0.85;

  /// Where drops start, above the box.
  static const _startY = -40.0;

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        if (!animation.isAnimating || t == 0) return const SizedBox.shrink();
        return LayoutBuilder(
          builder: (context, constraints) {
            final soilY = constraints.maxHeight * soilLine;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                for (final (x, delay, size) in _drops)
                  ?_drop(t, x * constraints.maxWidth, delay, size, soilY),
              ],
            );
          },
        );
      },
    );
  }

  Widget? _drop(double t, double x, double delay, double size, double soilY) {
    // The delays (0–0.46) are stretched over the whole lap.
    final local = (((t - delay * 2) % 1.0) / _fallSpan).clamp(0.0, 1.0);
    if (local == 0 || local == 1) return null;
    final drop = SvgPicture.asset(
      dropAsset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(SeedlyPalette.info[500]!, BlendMode.srcIn),
    );
    if (local < _fallEnd) {
      // Falls faster and faster, like gravity.
      final f = Curves.easeIn.transform(local / _fallEnd);
      return Positioned(
        left: x - size / 2,
        top: _startY + (soilY - _startY - size) * f,
        child: Opacity(opacity: (local * 6).clamp(0.0, 1.0), child: drop),
      );
    }
    // Splash: the drop flattens and fades on the soil.
    final s = (local - _fallEnd) / (1 - _fallEnd);
    return Positioned(
      left: x - size / 2,
      top: soilY - size,
      child: Opacity(
        opacity: 1 - s,
        child: Transform(
          alignment: Alignment.bottomCenter,
          transform: Matrix4.diagonal3Values(1 + 0.6 * s, 1 - 0.6 * s, 1),
          child: drop,
        ),
      ),
    );
  }
}
