import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../modals/seedly_confirm_modal.dart';
import '../modals/seedly_duration_modal.dart';
import '../modals/seedly_end_watering_modal.dart';
import '../modals/seedly_focus_task_modal.dart';
import '../models/seedly_drops.dart';
import '../models/seedly_errors.dart';
import '../models/seedly_project.dart';
import '../models/seedly_watering.dart';
import '../repositories/seedly_drops_repository.dart';
import '../repositories/seedly_project_repository.dart';
import '../services/seedly_watering_controller.dart';
import '../theme/seedly_theme.dart';
import '../widgets/seedly_alert.dart';
import '../widgets/seedly_button.dart';
import '../widgets/seedly_header.dart';
import '../widgets/seedly_plant_blob.dart';

/// La pestaña Riego, con las tres pantallas de Figma: "Empezar riego",
/// "Regando" y "Fin de riego". Muestra lo que diga [controller], que vive en
/// la pantalla principal para que la sesión siga aunque se cambie de
/// pestaña.
class SeedlyWateringView extends StatefulWidget {
  const SeedlyWateringView({
    super.key,
    required this.controller,
    required this.projects,
    required this.onHome,
    this.drops,
  });

  final SeedlyWateringController controller;

  /// Las tareas de hoy para "Elegir tarea".
  final SeedlyProjectRepository projects;

  /// La fase de la planta y el total de gotas; sin él, la planta se ve en su
  /// primera fase y no se muestra el total.
  final SeedlyDropsRepository? drops;

  /// La flecha atrás y "Volver al inicio" llevan a Inicio. La sesión sigue
  /// corriendo mientras tanto.
  final VoidCallback onHome;

  /// Cuánto se achica la planta de "Empezar riego", donde ocupa el lugar de
  /// la ilustración de la regadera, para que entren las opciones sin que la
  /// tarjeta de enfoque y el botón de empezar queden fuera de pantalla.
  static const startPlantScale = 0.45;

  /// La planta de "Regando": un 10% más chica que en Inicio para que la
  /// pantalla entre fija, sin scroll.
  static const plantScale = 0.765;

  /// La planta de "Fin de riego", más chica que en "Regando" para que la
  /// tarjeta de gotas y "Volver al inicio" entren sin tanto scroll.
  static const donePlantScale = 0.6;

  @override
  State<SeedlyWateringView> createState() => _SeedlyWateringViewState();
}

class _SeedlyWateringViewState extends State<SeedlyWateringView> {
  static const _noPlant = SeedlyPlantState(phase: 1, totalDrops: 0);

  /// Cada cuánto se redibuja la cuenta regresiva; menos de un segundo para
  /// que ningún segundo se saltee.
  static const _tick = Duration(milliseconds: 250);

  late final Stream<SeedlyPlantState>? _plantState = widget.drops
      ?.watchPlantState();

  var _minutes = SeedlyWatering.defaultMinutes;
  SeedlyTask? _focus;
  Timer? _ticker;

  SeedlyWateringController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _controller.removeListener(_changed);
    // Salir de "Fin de riego" por el menú también la cierra: al volver,
    // Riego empieza de nuevo.
    _controller.dismissResult();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    _syncTicker();
  }

  /// La cuenta solo se redibuja mientras corre.
  void _syncTicker() {
    final session = _controller.session;
    final running =
        _controller.stage == SeedlyWateringStage.watering &&
        session != null &&
        !session.isPaused &&
        !session.isDoneAt(_controller.now());
    if (running) {
      _ticker ??= Timer.periodic(_tick, (_) => _changed());
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Un solo StreamBuilder para las tres pantallas: watchPlantState admite
    // un único listener.
    final stream = _plantState;
    if (stream == null) return _stage(_noPlant);
    return StreamBuilder<SeedlyPlantState>(
      stream: stream,
      builder: (context, snapshot) => _stage(snapshot.data ?? _noPlant),
    );
  }

  Widget _stage(SeedlyPlantState plant) {
    final result = _controller.result;
    final session = _controller.session;
    const padding = EdgeInsets.fromLTRB(24, 16, 24, 24);
    // "Regando" entra entera, así que se queda fija con el header arriba como
    // en Proyectos; "Empezar" y "Fin" sí pueden desplazarse.
    if (_controller.stage == SeedlyWateringStage.watering && session != null) {
      return SafeArea(
        bottom: false,
        child: Padding(padding: padding, child: _watering(session, plant)),
      );
    }
    final stage = switch (_controller.stage) {
      SeedlyWateringStage.ready => _start(plant),
      SeedlyWateringStage.done when result != null => _done(result, plant),
      _ => null,
    };
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(padding: padding, child: stage),
    );
  }

  // "Empezar riego".

  Widget _start(SeedlyPlantState plant) {
    final custom = !SeedlyWatering.presets.contains(_minutes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Sesión de Riego'),
        const SizedBox(height: 16),
        _paragraph(
          'Concéntrate en una tarea mientras tu planta recibe agua',
          align: TextAlign.left,
        ),
        const SizedBox(height: 8),
        Center(
          child: SeedlyPlantBlob(
            phase: plant.phase,
            scale: SeedlyWateringView.startPlantScale,
          ),
        ),
        const SizedBox(height: 16),
        _caps('Duración de la sesión', center: true),
        const SizedBox(height: 16),
        _durations(),
        const SizedBox(height: 8),
        Center(
          child: SeedlyButton(
            label: custom
                ? 'Tiempo personalizado: $_minutes min'
                : 'Tiempo personalizado',
            variant: SeedlyButtonVariant.text,
            size: SeedlyButtonSize.medium,
            leading: SvgPicture.asset(
              'assets/images/icon_clock.svg',
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(
                SeedlyPalette.primary[500]!,
                BlendMode.srcIn,
              ),
            ),
            onPressed: _pickMinutes,
          ),
        ),
        const SizedBox(height: 16),
        _FocusCard(focus: _focus, onChoose: _pickFocus),
        const SizedBox(height: 16),
        SeedlyButton(
          label: 'Comenzar sesión',
          expand: true,
          leading: _whiteIcon('assets/images/icon_raindrop.svg'),
          onPressed: _controller.busy ? null : _begin,
        ),
      ],
    );
  }

  /// Las opciones de Figma: dos, una ancha y dos.
  Widget _durations() {
    Widget option(int minutes) {
      final selected = minutes == _minutes;
      return Semantics(
        selected: selected,
        inMutuallyExclusiveGroup: true,
        child: SeedlyButton(
          label: '$minutes min',
          variant: selected
              ? SeedlyButtonVariant.filled
              : SeedlyButtonVariant.outline,
          size: SeedlyButtonSize.large,
          expand: true,
          onPressed: () => setState(() => _minutes = minutes),
        ),
      );
    }

    final presets = SeedlyWatering.presets;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Row(
          spacing: 12,
          children: [
            Expanded(child: option(presets[0])),
            Expanded(child: option(presets[1])),
          ],
        ),
        option(presets[2]),
        Row(
          spacing: 12,
          children: [
            Expanded(child: option(presets[3])),
            Expanded(child: option(presets[4])),
          ],
        ),
      ],
    );
  }

  Future<void> _pickMinutes() async {
    final minutes = await showSeedlyDurationModal(context, initial: _minutes);
    if (minutes != null && mounted) setState(() => _minutes = minutes);
  }

  Future<void> _pickFocus() async {
    final choice = await showSeedlyFocusTaskModal(
      context,
      projects: widget.projects,
      selectedTaskId: _focus?.id,
    );
    if (choice != null && mounted) setState(() => _focus = choice.task);
  }

  Future<void> _begin() async {
    hideSeedlyAlert();
    try {
      await _controller.start(minutes: _minutes, focus: _focus);
    } on SeedlyDropsException catch (error) {
      if (!mounted) return;
      showSeedlyAlert(
        context,
        style: SeedlyAlertStyle.danger,
        title: 'No se pudo empezar el riego',
        message: error.message,
      );
    }
  }

  // "Regando".

  Widget _watering(SeedlyWateringSession session, SeedlyPlantState plant) {
    final now = _controller.now();
    final done = session.isDoneAt(now);
    final paused = session.isPaused && !done;
    final progress = session.progressAt(now);
    final busy = _controller.busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SeedlyHeader(
          title: 'Regando tu Seedly',
          // La flecha ya no vuelve a Inicio: ofrece terminar la sesión y, al
          // aceptar, se queda en Riego mostrando el fin.
          onBack: _confirmFinish,
        ),
        const SizedBox(height: 24),
        Center(
          child: SeedlyPlantBlob(
            phase: plant.phase,
            watering: !session.isPaused && !done,
            scale: SeedlyWateringView.plantScale,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _countdown(session.remainingAt(now)),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 48,
            height: 58 / 48,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: SeedlyPalette.neutral[850],
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            text: 'Enfoque actual: ',
            children: [
              TextSpan(
                text: session.focusTitle ?? 'Sesión libre',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: SeedlyPalette.primary[500],
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            height: 24 / 16,
            color: SeedlyPalette.neutral[850],
          ),
        ),
        if (paused) ...[
          const SizedBox(height: 4),
          Text(
            'En pausa',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 20 / 14,
              color: SeedlyPalette.neutral[600],
            ),
          ),
        ],
        const SizedBox(height: 40),
        Row(
          children: [
            Expanded(child: _caps('Progreso de la sesión')),
            Text(
              '${(progress * 100).floor()}%',
              style: TextStyle(
                fontSize: 18,
                height: 28 / 18,
                fontWeight: FontWeight.w600,
                color: SeedlyPalette.primary[500],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(SeedlyMetrics.radii['full']!),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            color: SeedlyPalette.primary[500],
            backgroundColor: SeedlyPalette.primary[100],
            semanticsLabel: 'Progreso de la sesión',
          ),
        ),
        const SizedBox(height: 24),
        Row(
          spacing: 16,
          children: [
            Expanded(
              child: SeedlyButton(
                label: 'Terminar',
                variant: SeedlyButtonVariant.outline,
                expand: true,
                onPressed: busy ? null : _confirmFinish,
              ),
            ),
            // Con la cuenta en cero ya no hay nada que pausar.
            if (!done)
              Expanded(
                child: SeedlyButton(
                  label: paused ? 'Reanudar' : 'Pausar',
                  expand: true,
                  leading: _whiteIcon(
                    paused
                        ? 'assets/images/icon_play.svg'
                        : 'assets/images/icon_pause.svg',
                  ),
                  onPressed: busy
                      ? null
                      : paused
                      ? _controller.resume
                      : _controller.pause,
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Pregunta con el modal verde antes de terminar; tanto la flecha "Volver"
  /// como "Terminar" pasan por aquí. Al aceptar se cierra la sesión y Riego se
  /// queda mostrando el fin.
  Future<void> _confirmFinish() async {
    if (_controller.busy) return;
    final end = await showSeedlyEndWateringModal(context);
    if (end && mounted) await _finish();
  }

  Future<void> _finish() async {
    hideSeedlyAlert();
    final SeedlyWateringOutcome? outcome;
    try {
      outcome = await _controller.finish();
    } on SeedlyDropsException catch (error) {
      if (mounted) await _paymentFailed(error);
      return;
    }
    if (!mounted) return;
    switch (outcome) {
      case SeedlyWateringOutcome.tooShort:
        showSeedlyAlert(
          context,
          style: SeedlyAlertStyle.warning,
          title: 'Sesión muy corta',
          message: 'Riega al menos un minuto completo para sumar gotas.',
        );
      case SeedlyWateringOutcome.alreadyPaid:
        showSeedlyAlert(
          context,
          style: SeedlyAlertStyle.info,
          title: 'Sesión ya registrada',
          message: 'Las gotas de esta sesión ya estaban en tu planta.',
        );
      case SeedlyWateringOutcome.paid || null:
        break;
    }
  }

  /// La primera vez avisa y deja reintentar con "Terminar"; si sigue
  /// fallando, ofrece descartar la sesión para poder empezar otra.
  Future<void> _paymentFailed(SeedlyDropsException error) async {
    if (_controller.failedPayments < 2) {
      showSeedlyAlert(
        context,
        style: SeedlyAlertStyle.danger,
        title: 'No se pudo terminar el riego',
        message: error.message,
      );
      return;
    }
    final discard = await showSeedlyConfirmModal(
      context,
      illustration: 'assets/images/icon_raindrop.svg',
      title: '¿Descartar la sesión?',
      message:
          'No pudimos guardar las gotas de esta sesión. Si la descartas, '
          'podrás empezar otra.',
      confirmLabel: 'Descartar',
    );
    if (discard && mounted) await _controller.discard();
  }

  /// "24:59", o "1:05:00" desde una hora. Redondea hacia arriba, así que al
  /// empezar muestra la duración entera.
  static String _countdown(Duration remaining) {
    final seconds = (remaining.inMilliseconds + 999) ~/ 1000;
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return h > 0
        ? '$h:${m.toString().padLeft(2, '0')}:$s'
        : '${m.toString().padLeft(2, '0')}:$s';
  }

  // "Fin de riego".

  Widget _done(SeedlyWateringResult result, SeedlyPlantState plant) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Semantics(
          header: true,
          child: Text(
            '¡Buen trabajo!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 40,
              height: 48 / 40,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: SeedlyPalette.neutral[850],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _paragraph(
          'Gracias a tu esfuerzo y tiempo de enfoque, tu planta ha recibido '
          'agua',
        ),
        const SizedBox(height: 16),
        Center(
          child: SeedlyPlantBlob(
            phase: plant.phase,
            scale: SeedlyWateringView.donePlantScale,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: _DropsCard(
            drops: result.drops,
            total: widget.drops == null ? null : plant.totalDrops,
          ),
        ),
        const SizedBox(height: 40),
        SeedlyButton(
          label: 'Volver al inicio',
          expand: true,
          leading: _whiteIcon('assets/images/icon_arrow_left.svg'),
          onPressed: () {
            _controller.dismissResult();
            widget.onHome();
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // Piezas comunes.

  /// El encabezado de sección, igual que Perfil y Proyectos: Riego es una
  /// pestaña del menú principal, así que no lleva flecha de volver.
  static Widget _sectionTitle(String text) => Semantics(
    header: true,
    child: Text(
      text,
      style: TextStyle(
        fontSize: 32,
        height: 38 / 32,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
        color: SeedlyPalette.neutral[850],
      ),
    ),
  );

  static Widget _paragraph(String text, {TextAlign align = TextAlign.center}) =>
      Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 16,
          height: 24 / 16,
          color: SeedlyPalette.neutral[700],
        ),
      );

  /// Las etiquetas en mayúsculas espaciadas de Figma.
  static Widget _caps(String text, {bool center = false}) => Text(
    text.toUpperCase(),
    textAlign: center ? TextAlign.center : TextAlign.start,
    style: TextStyle(
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 2,
      color: SeedlyPalette.neutral[850],
    ),
  );

  static Widget _whiteIcon(String asset) => SvgPicture.asset(
    asset,
    width: 24,
    height: 24,
    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
  );
}

/// "Enfoque de hoy" de "Empezar riego": la tarjeta de Inicio con el botón
/// "Elegir tarea" al final.
class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.focus, required this.onChoose});

  final SeedlyTask? focus;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final focus = this.focus;
    final radius = BorderRadius.circular(SeedlyMetrics.radii['lg']!);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: SeedlyPalette.neutral[50],
        borderRadius: radius,
        border: Border.all(color: SeedlyPalette.border),
        boxShadow: SeedlyShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            spacing: 12,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: SeedlyPalette.neutral[200],
                  borderRadius: BorderRadius.circular(
                    SeedlyMetrics.radii['md']!,
                  ),
                ),
                child: SvgPicture.asset(
                  focus == null
                      ? 'assets/images/icon_question.svg'
                      : 'assets/images/icon_check.svg',
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(
                    SeedlyPalette.primary[600]!,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              // El texto ocupa todo el ancho libre: antes el botón "Elegir
              // tarea" iba al lado y "ENFOQUE DE HOY" se cortaba a la mitad.
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    Text(
                      'ENFOQUE DE HOY',
                      style: TextStyle(
                        fontSize: 12,
                        height: 16 / 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 2,
                        color: SeedlyPalette.neutral[700],
                      ),
                    ),
                    Text(
                      focus?.title ?? 'Sesión libre',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        height: 24 / 16,
                        color: SeedlyPalette.neutral[850],
                      ),
                    ),
                    Text(
                      focus == null
                          ? 'Enfócate sin una tarea definida o elige una si lo '
                                'prefieres.'
                          : 'Tu sesión irá dedicada a esta tarea.',
                      style: TextStyle(
                        fontSize: 10,
                        height: 14 / 10,
                        color: SeedlyPalette.neutral[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SeedlyButton(
            label: focus == null ? 'Elegir tarea' : 'Cambiar',
            variant: SeedlyButtonVariant.outline,
            size: SeedlyButtonSize.small,
            expand: true,
            onPressed: onChoose,
          ),
        ],
      ),
    );
  }
}

/// La tarjeta de "Fin de riego": la gota, las gotas ganadas y el total.
class _DropsCard extends StatelessWidget {
  const _DropsCard({required this.drops, this.total});

  final int drops;
  final int? total;

  @override
  Widget build(BuildContext context) {
    final total = this.total;
    return Container(
      constraints: const BoxConstraints(minWidth: 200),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: BoxDecoration(
        color: SeedlyPalette.neutral[50],
        borderRadius: BorderRadius.circular(SeedlyMetrics.radii['lg']!),
        border: Border.all(color: SeedlyPalette.border),
        boxShadow: SeedlyShadows.card,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          SvgPicture.asset(
            'assets/images/icon_raindrop.svg',
            width: 48,
            height: 48,
            excludeFromSemantics: true,
          ),
          const SizedBox(height: 4),
          Text(
            '+$drops ${drops == 1 ? 'gota' : 'gotas'}',
            style: TextStyle(
              fontSize: 18,
              height: 28 / 18,
              fontWeight: FontWeight.w600,
              color: SeedlyPalette.info[500],
            ),
          ),
          if (total != null)
            Text(
              'Total: $total',
              style: TextStyle(
                fontSize: 14,
                height: 20 / 14,
                color: SeedlyPalette.neutral[850],
              ),
            ),
        ],
      ),
    );
  }
}
