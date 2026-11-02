import 'package:flutter/material.dart';

import '../theme/seedly_theme.dart';

/// A veil over the whole screen while something that must not be interrupted
/// is under way, such as signing out: it takes every touch and shows a
/// spinner with [label]. Put it last in a [Stack] over the screen, menu
/// included.
class SeedlyBusyOverlay extends StatelessWidget {
  const SeedlyBusyOverlay({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      liveRegion: true,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Absorbs taps and drags, so nothing behind can be scrolled.
            ModalBarrier(
              dismissible: false,
              color: SeedlyPalette.neutral[100]!.withValues(alpha: 0.85),
            ),
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: SeedlyPalette.neutral[50],
                  borderRadius: BorderRadius.circular(
                    SeedlyMetrics.radii['lg']!,
                  ),
                  border: const Border.fromBorderSide(
                    BorderSide(color: SeedlyPalette.border),
                  ),
                  boxShadow: SeedlyShadows.card,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 16,
                    children: [
                      SizedBox.square(
                        dimension: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          strokeCap: StrokeCap.round,
                          color: SeedlyPalette.primary[500],
                          backgroundColor: SeedlyPalette.primary[150],
                        ),
                      ),
                      ExcludeSemantics(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 16,
                            height: 24 / 16,
                            fontWeight: FontWeight.w600,
                            color: SeedlyPalette.neutral[850],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
