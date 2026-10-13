import 'package:flutter/material.dart';

import '../theme/seedly_theme.dart';

/// Decorative leaf and seedling outlines used by the loading screen.
class SeedlyBotanicalBackground extends StatelessWidget {
  const SeedlyBotanicalBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BotanicalPainter());
  }
}

class _BotanicalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // The source composition is 350 × 764; edges intentionally clip the art.
    canvas.save();
    canvas.scale(size.width / 350, size.height / 764);
    final line = Paint()
      ..color = SeedlyPalette.neutral[500]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    _drawPot(canvas, line, const Offset(12, 79), 1.1);
    _drawLeaf(canvas, line, const Offset(255, 23), 0.9);
    _drawPot(canvas, line, const Offset(303, 235), 0.92);
    _drawLeaf(canvas, line, const Offset(-57, 446), 1.22);
    _drawPot(canvas, line, const Offset(240, 600), 1.0);
    _drawLeaf(canvas, line, const Offset(22, 664), 0.96);
    canvas.restore();
  }

  void _drawPot(Canvas canvas, Paint line, Offset origin, double scale) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scale);

    final sprout = Path()
      ..moveTo(50, 31)
      ..cubicTo(31, 31, 17, 22, 17, 4)
      ..cubicTo(37, 3, 47, 10, 50, 31)
      ..cubicTo(53, 10, 63, 3, 83, 4)
      ..cubicTo(83, 22, 69, 31, 50, 31);
    canvas.drawPath(sprout, line);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(9, 48, 82, 20),
        const Radius.circular(5),
      ),
      line,
    );
    final pot = Path()
      ..moveTo(18, 68)
      ..lineTo(31, 111)
      ..lineTo(69, 111)
      ..lineTo(82, 68);
    canvas.drawPath(pot, line);
    canvas.restore();
  }

  void _drawLeaf(Canvas canvas, Paint line, Offset origin, double scale) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scale);
    final outline = Path()
      ..moveTo(0, 78)
      ..cubicTo(-3, 38, 7, 3, 78, 1)
      ..cubicTo(82, 39, 59, 78, 0, 78);
    canvas.drawPath(outline, line);
    canvas.drawLine(const Offset(0, 78), const Offset(31, 47), line);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BotanicalPainter oldDelegate) => false;
}
