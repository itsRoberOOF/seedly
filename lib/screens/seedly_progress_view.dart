import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/seedly_drops.dart';
import '../models/seedly_errors.dart';
import '../repositories/seedly_drops_repository.dart';
import '../theme/seedly_theme.dart';
import '../widgets/seedly_alert.dart';
import '../widgets/seedly_button.dart';
import '../widgets/seedly_header.dart';
import '../widgets/seedly_plant.dart';

/// The four Figma "Mi progreso" states, driven by the signed-in user's drops.
class SeedlyProgressView extends StatefulWidget {
  const SeedlyProgressView({
    super.key,
    required this.drops,
    this.onBack,
    this.onWater,
  });

  final SeedlyDropsRepository drops;
  final VoidCallback? onBack;
  final VoidCallback? onWater;

  @override
  State<SeedlyProgressView> createState() => _SeedlyProgressViewState();
}

class _SeedlyProgressViewState extends State<SeedlyProgressView> {
  double get _layoutScale =>
      math.min(1.0, MediaQuery.sizeOf(context).width / 440);

  late Stream<SeedlyPlantState> _plantStream;
  SeedlyPlantState? _lastPlant;
  Timer? _initialLoadTimer;
  bool _initialLoadTimedOut = false;
  bool _growing = false;
  int? _grownToPhase;

  @override
  void initState() {
    super.initState();
    _plantStream = _watchPlant();
    _startInitialLoadTimer();
  }

  void _startInitialLoadTimer() {
    _initialLoadTimer?.cancel();
    _initialLoadTimer = Timer(const Duration(seconds: 12), () {
      if (mounted && _lastPlant == null) {
        setState(() => _initialLoadTimedOut = true);
      }
    });
  }

  @override
  void dispose() {
    _initialLoadTimer?.cancel();
    super.dispose();
  }

  Stream<SeedlyPlantState> _watchPlant() {
    try {
      return widget.drops.watchPlantState();
    } on Object catch (error) {
      return Stream<SeedlyPlantState>.error(error);
    }
  }

  void _retry() {
    setState(() {
      _initialLoadTimedOut = false;
      _plantStream = _watchPlant();
    });
    _startInitialLoadTimer();
  }

  void _back() {
    hideSeedlyAlert();
    if (widget.onBack case final back?) {
      back();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _water() {
    widget.onWater?.call();
  }

  Future<void> _grow(SeedlyPlantState plant) async {
    if (_growing || _grownToPhase != null || !plant.canGrow) return;
    setState(() => _growing = true);
    try {
      await widget.drops.growPlant();
      if (!mounted) return;
      // A successful write can finish before the phase snapshot arrives.
      setState(() {
        _grownToPhase = plant.phase + 1;
        _growing = false;
      });
    } on SeedlyDropsException catch (error) {
      if (!mounted) return;
      setState(() => _growing = false);
      showSeedlyAlert(
        context,
        style: SeedlyAlertStyle.danger,
        title: 'No se pudo hacer crecer tu planta',
        message: error.message,
      );
    } on Object {
      if (!mounted) return;
      setState(() => _growing = false);
      showSeedlyAlert(
        context,
        style: SeedlyAlertStyle.danger,
        title: 'No se pudo hacer crecer tu planta',
        message: 'Inténtalo de nuevo en un momento.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SeedlyPalette.neutral[100],
      body: StreamBuilder<SeedlyPlantState>(
        stream: _plantStream,
        builder: (context, snapshot) {
          if (snapshot.hasData || snapshot.hasError) {
            _initialLoadTimer?.cancel();
          }
          if (snapshot.hasData) _lastPlant = snapshot.data;
          final plant = _lastPlant;
          if (plant == null) {
            return _initialState(snapshot.hasError || _initialLoadTimedOut);
          }
          final grew = _grownToPhase != null && plant.phase >= _grownToPhase!;
          final showError = snapshot.hasError;
          return _layout(
            plant.phase == SeedlyDrops.maxPhase && !grew
                ? _maximum(plant)
                : grew
                ? _growthSuccess(plant)
                : _progress(plant),
            readError: showError,
          );
        },
      ),
    );
  }

  Widget _initialState(bool failed) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        children: [
          SeedlyHeader(title: 'Mi progreso', onBack: _back),
          Expanded(
            child: Center(
              child: !failed
                  ? const CircularProgressIndicator(
                      semanticsLabel: 'Cargando progreso',
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'No se pudo cargar tu progreso.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        SeedlyButton(label: 'Reintentar', onPressed: _retry),
                      ],
                    ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _layout(List<Widget> children, {required bool readError}) {
    // Measured above the SafeArea, where the status bar is still the real
    // inset, so the header lands at the same height as Detalle de proyecto and
    // Riego. Inside the SafeArea the inset reads 0 and the header sinks.
    final top = math.max(24.0, 48 - MediaQuery.paddingOf(context).top);
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = _layoutScale;
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    32 * scale,
                    top,
                    32 * scale,
                    16 * scale,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (readError)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Sin conexión. Se muestra el último progreso.',
                                ),
                              ),
                              TextButton(
                                onPressed: _retry,
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        ),
                      ...children,
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _progress(SeedlyPlantState plant) {
    final goal = plant.nextGoal!;
    final remaining = math.max(goal - plant.totalDrops, 0);
    final waitingForPhase = _grownToPhase != null;
    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SeedlyHeader(title: 'Mi progreso', onBack: _back),
          SizedBox(height: 48 * _layoutScale),
          _dropProgress(plant, goal, remaining),
        ],
      ),
      _PlantSlot(plant.phase),
      Column(
        children: [
          if (plant.canGrow)
            SeedlyButton(
              label: _growing
                  ? 'Haciendo crecer tu planta…'
                  : waitingForPhase
                  ? 'Actualizando planta…'
                  : 'Haz crecer tu planta',
              expand: true,
              leading: SvgPicture.asset('assets/images/progress_leaf.svg'),
              onPressed: _growing || waitingForPhase
                  ? null
                  : () => _grow(plant),
            )
          else
            SeedlyButton(
              label: 'Sigue regando y lo lograrás',
              variant: SeedlyButtonVariant.outline,
              expand: true,
              shrinkLabelToFit: true,
              leading: SvgPicture.asset(
                'assets/images/progress_drop_outline.svg',
              ),
              onPressed: _water,
            ),
          SizedBox(height: 48 * _layoutScale),
          const _ProgressDecoration(),
        ],
      ),
    ];
  }

  Widget _dropProgress(SeedlyPlantState plant, int goal, int remaining) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TUS GOTAS',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset('assets/images/progress_drop.svg'),
                      const SizedBox(width: 4),
                      Text(
                        '${_number(plant.totalDrops)} / ${_number(goal)}',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(SeedlyMetrics.radii['sm']!),
            child: LinearProgressIndicator(
              value: (plant.totalDrops / goal).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: SeedlyPalette.primary[150],
              color: SeedlyPalette.primary[500],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            plant.canGrow
                ? '¡Lo lograste! Tu planta está lista para crecer'
                : 'Te faltan $remaining gotas para la siguiente fase',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: plant.canGrow
                  ? SeedlyPalette.primary[600]
                  : SeedlyPalette.neutral[700],
              fontWeight: plant.canGrow ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ],
      );

  List<Widget> _growthSuccess(SeedlyPlantState plant) => [
    Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48 * _layoutScale,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '¡Tu planta creció!',
              maxLines: 1,
              softWrap: false,
              style: Theme.of(context).textTheme.displayMedium,
            ),
          ),
        ),
        SizedBox(height: 10 * _layoutScale),
        Text(
          'Gracias a tu constancia, tu planta avanzó a su siguiente fase',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontSize: math.max(14, 18 * _layoutScale),
            height: 28 / 18,
            fontWeight: FontWeight.w500,
            color: SeedlyPalette.neutral[700],
          ),
        ),
      ],
    ),
    _PlantSlot(plant.phase, scale: 0.85),
    Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // A touch of breathing room so the card isn't cramped under the plant.
        SizedBox(height: 24 * _layoutScale),
        _dropsCard(
          value: plant.nextGoal ?? plant.totalDrops,
          label: plant.nextGoal == null
              ? 'Gotas acumuladas'
              : 'Tu próxima meta',
        ),
        SizedBox(height: 48 * _layoutScale),
        SeedlyButton(
          label: 'Volver al inicio',
          expand: true,
          leading: SvgPicture.asset('assets/images/progress_back_white.svg'),
          onPressed: _back,
        ),
        SizedBox(height: 48 * _layoutScale),
        const _ProgressDecoration(),
      ],
    ),
  ];

  List<Widget> _maximum(SeedlyPlantState plant) => [
    Column(
      children: [
        SeedlyHeader(title: 'Mi progreso', onBack: _back),
        SizedBox(height: 40 * _layoutScale),
        Text(
          '¡Nivel máximo!',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displaySmall
              ?.copyWith(fontSize: 32 * _layoutScale, height: 48 / 32),
        ),
        SizedBox(height: 10 * _layoutScale),
        Text(
          'Tu planta alcanzó su máximo esplendor. Sigue regando para mantenerla feliz.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontSize: math.max(14, 16 * _layoutScale),
            fontWeight: FontWeight.w500,
            height: 28 / 16,
            color: SeedlyPalette.neutral[700],
          ),
        ),
      ],
    ),
    _PlantSlot(plant.phase),
    Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dropsCard(value: plant.totalDrops, label: 'Gotas acumuladas'),
        SizedBox(height: 24 * _layoutScale),
        SeedlyButton(
          label: 'Seguir regando',
          expand: true,
          leading: SvgPicture.asset('assets/images/progress_drop_white.svg'),
          onPressed: _water,
        ),
        SizedBox(height: 48 * _layoutScale),
        const _ProgressDecoration(),
      ],
    ),
  ];

  Widget _dropsCard({required int value, required String label}) {
    final narrow = MediaQuery.sizeOf(context).width < 364;
    return Container(
      decoration: BoxDecoration(
        color: SeedlyPalette.neutral[50],
        border: Border.all(color: SeedlyPalette.border),
        borderRadius: BorderRadius.circular(SeedlyMetrics.radii['lg']!),
        boxShadow: SeedlyShadows.card,
      ),
      padding: EdgeInsets.symmetric(horizontal: narrow ? 24 : 64, vertical: 12),
      child: Column(
        children: [
          SvgPicture.asset('assets/images/progress_drop_large.svg'),
          const SizedBox(height: 4),
          Text(
            _number(value),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: SeedlyPalette.info[500],
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  static String _number(int value) => value.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
}

class _PlantSlot extends StatelessWidget {
  const _PlantSlot(this.phase, {this.scale = 1.0});
  final int phase;

  /// Shrinks the whole slot (blob + plant); the growth screen uses < 1.
  final double scale;

  @override
  Widget build(BuildContext context) {
    final layoutScale = math.min(1.0, MediaQuery.sizeOf(context).width / 440);
    final width =
        math.max(
          1.0,
          math.min(
            300 * layoutScale,
            MediaQuery.sizeOf(context).width - 64 * layoutScale,
          ),
        ) *
        scale;
    final plantScale = width / 300;
    return SizedBox(
      width: width,
      height: 330.775 * plantScale,
      child: Stack(
        children: [
          Positioned.fill(
            child: SvgPicture.asset('assets/images/progress_blob.svg'),
          ),
          Positioned(
            top: 14 * plantScale,
            left: 0,
            right: 0,
            height: 303 * plantScale,
            child: Center(child: SeedlyPlant(phase: phase)),
          ),
        ],
      ),
    );
  }
}

class _ProgressDecoration extends StatelessWidget {
  const _ProgressDecoration();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final number in [1, 2, 3]) ...[
        if (number > 1) const SizedBox(width: 24),
        SvgPicture.asset('assets/images/progress_decoration_$number.svg'),
      ],
    ],
  );
}
