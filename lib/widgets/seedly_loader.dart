import 'package:flutter/material.dart';

import '../theme/seedly_theme.dart';

/// A three-second branded progress bar based on Figma's Progress Bar component.
class SeedlyLoader extends StatefulWidget {
  const SeedlyLoader({super.key, this.startAfter, this.onComplete});

  /// Defaults to the first frame being rasterized, so progress starts onscreen.
  final Future<void>? startAfter;
  final VoidCallback? onComplete;

  @override
  State<SeedlyLoader> createState() => _SeedlyLoaderState();
}

class _SeedlyLoaderState extends State<SeedlyLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  @override
  void initState() {
    super.initState();
    _progress.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onComplete?.call();
    });
    final ready =
        widget.startAfter ??
        WidgetsBinding.instance.waitUntilFirstFrameRasterized;
    ready.then((_) {
      if (mounted) _progress.forward();
    });
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando',
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _progress,
            builder: (context, _) => SizedBox(
              width: 244,
              child: LinearProgressIndicator(
                value: _progress.value,
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
          Text(
            'CARGANDO',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: SeedlyPalette.neutral[600],
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
