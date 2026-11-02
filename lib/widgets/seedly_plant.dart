import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'seedly_watering_rain.dart';

/// How the plant looks at each phase of `SeedlyPlantState.phase` (1 to 4).
enum SeedlyPlantPhase {
  seed('Semilla'),
  sprout('Brote'),
  young('Joven'),
  adult('Adulta');

  const SeedlyPlantPhase(this.label);

  final String label;

  /// The phase as the drops system counts it, from 1.
  int get number => index + 1;

  String get asset => 'assets/images/plant_phase_$number.svg';

  /// The look for [phase], kept within the first and last one.
  static SeedlyPlantPhase of(int phase) =>
      values[(phase - 1).clamp(0, values.length - 1)];
}

/// One frame of the plant's idle "lively" loop.
typedef SeedlyPlantPose = ({
  double scaleX,
  double scaleY,
  double rotation,
  double dy,
});

/// The keyframes of the CSS loop the plant SVGs were designed with, at 0%,
/// 25%, 50%, 75% and 100%: it sways ±1.4° and stretches up most at the middle.
/// [SeedlyPlantPose.dy] is in SVG units (the art is 500 tall).
const _keyframes = <SeedlyPlantPose>[
  (scaleX: 1, scaleY: 1, rotation: 0, dy: 0),
  (scaleX: 1.018, scaleY: 1.026, rotation: 1.4 * _degree, dy: -3),
  (scaleX: 1.01, scaleY: 1.038, rotation: 0, dy: -5),
  (scaleX: 1.018, scaleY: 1.026, rotation: -1.4 * _degree, dy: -3),
  (scaleX: 1, scaleY: 1, rotation: 0, dy: 0),
];

const _degree = math.pi / 180;

/// The pose at [t] (0 to 1) of the loop: CSS eases each step between
/// keyframes with ease-in-out, which is [Curves.easeInOut].
SeedlyPlantPose seedlyPlantPose(double t) {
  final steps = _keyframes.length - 1;
  final at = (t % 1.0) * steps;
  final step = at.floor().clamp(0, steps - 1);
  final eased = Curves.easeInOut.transform(at - step);
  final (from, to) = (_keyframes[step], _keyframes[step + 1]);
  double lerp(double a, double b) => lerpDouble(a, b, eased)!;
  return (
    scaleX: lerp(from.scaleX, to.scaleX),
    scaleY: lerp(from.scaleY, to.scaleY),
    rotation: lerp(from.rotation, to.rotation),
    dy: lerp(from.dy, to.dy),
  );
}

/// The cactus mascot at [phase], swaying gently in a loop; with [watering],
/// drops fall on its pot. A new phase grows in from the pot. With reduce
/// motion on, it stands still and no rain falls. It keeps the art's 292×500
/// shape, so size it by its height or width.
class SeedlyPlant extends StatefulWidget {
  const SeedlyPlant({super.key, required this.phase, this.watering = false});

  /// 1 to 4, as `SeedlyPlantState.phase`; other values show the nearest.
  final int phase;
  final bool watering;

  /// Length of one sway, as in the CSS loop.
  static const swayDuration = Duration(seconds: 4);

  /// How long a new phase takes to grow in.
  static const growDuration = Duration(milliseconds: 500);

  static const _artSize = Size(292, 500);

  /// Where the plant pivots: the bottom of the pot, (146, 490) in the art.
  static const _pivot = Alignment(0, 490 / 500 * 2 - 1);

  @override
  State<SeedlyPlant> createState() => _SeedlyPlantState();
}

class _SeedlyPlantState extends State<SeedlyPlant>
    with TickerProviderStateMixin {
  late final _sway = AnimationController(
    vsync: this,
    duration: SeedlyPlant.swayDuration,
  );
  late final _rain = AnimationController(
    vsync: this,
    duration: SeedlyWateringRain.duration,
  );
  var _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(SeedlyPlant oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  /// Runs only what is on screen: the sway unless motion is reduced, and the
  /// rain while watering.
  void _sync() {
    if (_still) {
      _sway.value = 0;
    } else if (!_sway.isAnimating) {
      _sway.repeat();
    }
    if (widget.watering && !_still) {
      if (!_rain.isAnimating) _rain.repeat();
    } else {
      _rain.value = 0;
    }
  }

  @override
  void dispose() {
    _sway.dispose();
    _rain.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phase = SeedlyPlantPhase.of(widget.phase);
    return Semantics(
      image: true,
      label:
          'Planta en fase ${phase.number}: ${phase.label}'
          '${widget.watering ? ', regándose' : ''}',
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: AspectRatio(
            aspectRatio:
                SeedlyPlant._artSize.width / SeedlyPlant._artSize.height,
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: AnimatedSwitcher(
                      duration: _still
                          ? Duration.zero
                          : SeedlyPlant.growDuration,
                      switchInCurve: Curves.easeOutBack,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween(
                            begin: 0.85,
                            end: 1.0,
                          ).animate(animation),
                          alignment: Alignment.bottomCenter,
                          child: child,
                        ),
                      ),
                      child: _Swaying(
                        key: ValueKey(phase),
                        animation: _sway,
                        // SVG units to this box's pixels.
                        unit:
                            constraints.maxHeight / SeedlyPlant._artSize.height,
                        child: SvgPicture.asset(phase.asset),
                      ),
                    ),
                  ),
                  if (widget.watering && !_still)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: SeedlyWateringRain(animation: _rain),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Applies [seedlyPlantPose] to [child] around the bottom of the pot, in the
/// CSS order: scale, then rotate, then move up.
class _Swaying extends StatelessWidget {
  const _Swaying({
    super.key,
    required this.animation,
    required this.unit,
    required this.child,
  });

  final Animation<double> animation;
  final double unit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final pose = seedlyPlantPose(animation.value);
        return Transform(
          alignment: SeedlyPlant._pivot,
          transform: Matrix4.identity()
            ..scaleByDouble(pose.scaleX, pose.scaleY, 1, 1)
            ..rotateZ(pose.rotation)
            ..translateByDouble(0, pose.dy * unit, 0, 1),
          child: child,
        );
      },
      child: child,
    );
  }
}
