import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/seedly_theme.dart';

/// Figma "Progress Circle" (Size=Tiny): a 36px ring that fills clockwise from
/// the top, with the percentage in its middle.
class SeedlyProgressCircle extends StatelessWidget {
  const SeedlyProgressCircle({super.key, required this.progress});

  /// How far along, from 0 to 1; values outside are clamped.
  final double progress;

  static const size = 36.0;
  static const _stroke = 2.0;

  @override
  Widget build(BuildContext context) {
    final value = progress.clamp(0.0, 1.0);
    final percent = '${(value * 100).round()}%';
    return Semantics(
      label: 'Avance $percent',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _RingPainter(value),
          child: Center(
            child: Text(
              percent,
              style: TextStyle(
                fontSize: 10,
                height: 14 / 10,
                fontWeight: FontWeight.w500,
                color: SeedlyPalette.neutral[850],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(SeedlyProgressCircle._stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = SeedlyProgressCircle._stroke
      ..strokeCap = StrokeCap.round
      ..color = SeedlyPalette.neutral[400]!;
    canvas.drawOval(rect, paint);
    if (progress <= 0) return;
    paint.color = SeedlyPalette.primary[500]!;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
