import 'package:flutter/material.dart';

import '../theme/seedly_theme.dart';

/// Figma's Progress Bar component as a loading indicator: the bar follows
/// [progress] and the caption always reads "Cargando".
class SeedlyLoader extends StatelessWidget {
  const SeedlyLoader({super.key, required this.progress});

  /// How far along, from 0 to 1.
  final double progress;

  @override
  Widget build(BuildContext context) {
    final value = progress.clamp(0.0, 1.0);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: 'Cargando',
      value: '${(value * 100).round()}%',
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The bar glides to each new value instead of jumping.
          TweenAnimationBuilder<double>(
            tween: Tween(end: value),
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            builder: (context, shown, _) => SizedBox(
              width: 244,
              child: LinearProgressIndicator(
                value: shown,
                minHeight: 8,
                borderRadius: BorderRadius.circular(
                  SeedlyMetrics.radii['full']!,
                ),
                backgroundColor: SeedlyPalette.primary[150],
                color: SeedlyPalette.primary[500],
              ),
            ),
          ),
          const SizedBox(height: 8),
          ExcludeSemantics(
            child: Text(
              'CARGANDO',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: SeedlyPalette.neutral[600],
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
