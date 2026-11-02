import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/seedly_theme.dart';

/// An empty list's place holder, the size of a [SeedlyInfoCard]: a dashed
/// card with a "+" tile, a title and, if given, a line above ([superior]) and
/// one below ([helper]) inviting the person to fill it.
/// With [done] the tile turns green with a tick, for a list finished rather
/// than never started.
///
/// With an [onTap] the whole card is a button and ends in an arrow.
///
/// Not from Figma yet: it follows Card-Icon+Info (Default) with a dashed
/// outline and no shadow.
class SeedlyEmptyCard extends StatelessWidget {
  const SeedlyEmptyCard({
    super.key,
    required this.title,
    this.superior,
    this.helper,
    this.done = false,
    this.onTap,
  });

  final String title;

  /// Small capitals above the title, like [SeedlyInfoCard]'s.
  final String? superior;
  final String? helper;
  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(SeedlyMetrics.radii['lg']!);
    return Semantics(
      button: onTap != null,
      child: CustomPaint(
        foregroundPainter: _DashedBorderPainter(
          color: SeedlyPalette.neutral[500]!,
          radius: radius.topLeft.x,
        ),
        child: Material(
          color: SeedlyPalette.neutral[150],
          shape: RoundedRectangleBorder(borderRadius: radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 12, onTap == null ? 24 : 16, 12),
              child: Row(
                spacing: 12,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: done
                          ? SeedlyPalette.primary[500]
                          : SeedlyPalette.primary[50],
                      borderRadius: BorderRadius.circular(
                        SeedlyMetrics.radii['md']!,
                      ),
                    ),
                    child: done
                        ? SvgPicture.asset(
                            'assets/images/icon_check.svg',
                            width: 24,
                            height: 24,
                          )
                        : SvgPicture.asset(
                            'assets/images/icon_plus.svg',
                            width: 24,
                            height: 24,
                            colorFilter: ColorFilter.mode(
                              SeedlyPalette.primary[600]!,
                              BlendMode.srcIn,
                            ),
                          ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 4,
                      children: [
                        if (superior != null)
                          Text(
                            superior!.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              height: 16 / 12,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 2,
                              color: SeedlyPalette.neutral[700],
                            ),
                          ),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            height: 24 / 16,
                            color: SeedlyPalette.neutral[850],
                          ),
                        ),
                        if (helper != null)
                          Text(
                            helper!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            // Darker than the filled cards' helper: this card
                            // sits on the page's grey, not on white.
                            style: TextStyle(
                              fontSize: 10,
                              height: 14 / 10,
                              color: SeedlyPalette.neutral[700],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (onTap != null)
                    SvgPicture.asset(
                      'assets/images/card_arrow_right.svg',
                      width: 24,
                      height: 24,
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

/// A rounded rectangle's outline drawn in dashes, which Flutter has no
/// border for.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const _width = 1.5;
  static const _dash = 6.0;
  static const _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(_width / 2),
      Radius.circular(radius - _width / 2),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _width
      ..color = color;
    for (final metric in (Path()..addRRect(outline)).computeMetrics()) {
      for (var at = 0.0; at < metric.length; at += _dash + _gap) {
        canvas.drawPath(
          metric.extractPath(at, math.min(at + _dash, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
