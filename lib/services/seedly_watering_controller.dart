import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/seedly_errors.dart';
import '../models/seedly_project.dart';
import '../models/seedly_watering.dart';
import '../repositories/seedly_drops_repository.dart';
import 'seedly_notification_service.dart';
import 'seedly_watering_store.dart';

/// Cuál de las tres pantallas de Riego de Figma mostrar.
enum SeedlyWateringStage {
  /// Buscando una sesión guardada en este teléfono.
  loading,

  /// "Empezar riego".
  ready,

  /// "Regando", corriendo o en pausa.
  watering,

  /// "Fin de riego".
  done,
}

/// Cómo terminó [SeedlyWateringController.finish].
enum SeedlyWateringOutcome {
  /// Se pagaron las gotas; están en [SeedlyWateringController.result].
  paid,

  /// Se regó menos de un minuto completo: no hay nada que pagar.
  tooShort,

  /// La sesión ya estaba pagada, por ejemplo justo antes de que se cerrara
  /// la app.
  alreadyPaid,
}

/// Lo que pagó una sesión terminada, para "Fin de riego".
class SeedlyWateringResult {
  const SeedlyWateringResult({required this.drops, required this.minutes});

  final int drops;
  final int minutes;

  @override
  bool operator ==(Object other) =>
      other is SeedlyWateringResult &&
      other.drops == drops &&
      other.minutes == minutes;

  @override
  int get hashCode => Object.hash(drops, minutes);
}

/// Maneja la sesión de riego: la inicia con el servidor, lleva la cuenta
/// regresiva, la pausa, paga sus minutos completos y mantiene sus
/// notificaciones al día.
///
/// Vive lo mismo que la pantalla principal con sesión iniciada, así que la
/// cuenta sigue mientras hay otra pestaña abierta. Una sesión a la vez: no
/// empieza otra hasta que la anterior se pague, se descarte o se cierre su
/// pantalla de fin.
class SeedlyWateringController extends ChangeNotifier {
  SeedlyWateringController({
    required this._drops,
    required this._store,
    required this._ownerId,
    this._notifications,
    DateTime Function()? clock,
    bool Function()? inForeground,
  }) : _clock = clock ?? DateTime.now,
       _inForeground = inForeground ?? _appInForeground;

  final SeedlyDropsRepository _drops;
  final SeedlyWateringStore _store;
  final String? _ownerId;
  final SeedlyNotificationService? _notifications;
  final DateTime Function() _clock;
  final bool Function() _inForeground;

  static const _runningTitle = 'Regando tu Seedly';
  static const _pausedTitle = 'Riego en pausa';
  static const _pausedBody = 'Vuelve a Seedly para reanudar tu sesión.';
  static const endTitle = '¡Buen trabajo!';
  static const endBody =
      'Tu sesión de riego terminó. Entra a Seedly para recibir tus gotas.';

  var _stage = SeedlyWateringStage.loading;
  SeedlyWateringSession? _session;
  SeedlyWateringResult? _result;
  var _busy = false;
  var _failedPayments = 0;
  Timer? _timer;
  var _disposed = false;

  SeedlyWateringStage get stage => _stage;

  /// La sesión en curso, durante [SeedlyWateringStage.watering].
  SeedlyWateringSession? get session => _session;

  /// Lo que pagó la última sesión, durante [SeedlyWateringStage.done].
  SeedlyWateringResult? get result => _result;

  /// Hablando con el servidor; los botones esperan.
  bool get busy => _busy;

  /// Veces seguidas que falló el pago de esta sesión.
  int get failedPayments => _failedPayments;

  DateTime now() => _clock();

  /// Retoma la sesión guardada en este teléfono, si hay. Una sesión que
  /// terminó con la app cerrada se paga en el acto.
  Future<void> restore() async {
    if (_stage != SeedlyWateringStage.loading) return;
    final ownerId = _ownerId;
    SeedlyWateringSession? saved;
    if (ownerId != null) {
      try {
        saved = await _store.load(ownerId);
      } on Object {
        // No hay nada legible que retomar; se empieza de cero.
      }
    }
    if (_disposed) return;
    _session = saved;
    _stage = saved == null
        ? SeedlyWateringStage.ready
        : SeedlyWateringStage.watering;
    _notify();
    if (saved == null) return;
    if (saved.isDoneAt(_clock())) {
      try {
        await finish();
      } on SeedlyDropsException {
        // Queda en "Regando", donde "Terminar" lo vuelve a intentar.
      }
    } else {
      _arm();
      await _showNotices(saved);
    }
  }

  /// Inicia una cuenta regresiva de [minutes], con [focus] como enfoque o
  /// libre. Lanza [SeedlyDropsException] si el servidor no puede iniciarla.
  Future<void> start({required int minutes, SeedlyTask? focus}) async {
    if (_busy || _stage != SeedlyWateringStage.ready) return;
    if (minutes < SeedlyWatering.minMinutes ||
        minutes > SeedlyWatering.maxMinutes) {
      throw ArgumentError.value(minutes, 'minutes');
    }
    final ownerId = _ownerId;
    if (ownerId == null) {
      throw const SeedlyDropsException(SeedlyDropsError.sessionExpired);
    }
    _busy = true;
    _notify();
    try {
      // Antes de la cuenta, para que el diálogo del sistema no le reste
      // tiempo. La sesión funciona igual sin notificaciones.
      await _quietly(() => _notifications?.requestWateringPermission());
      final id = await _drops.startWateringSession();
      if (_disposed) return;
      // Se cuenta desde acá, después de que el servidor selló el inicio:
      // los minutos pagados nunca pueden superar a los del servidor.
      final session = SeedlyWateringSession(
        id: id,
        ownerId: ownerId,
        minutes: minutes,
        startedAt: _clock(),
        focusTaskId: focus?.id,
        focusTitle: focus?.title,
      );
      _session = session;
      _stage = SeedlyWateringStage.watering;
      _failedPayments = 0;
      _arm();
      await _save(session);
      await _showNotices(session);
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<void> pause() async {
    final session = _session;
    final now = _clock();
    if (_busy || session == null || session.isPaused) return;
    if (session.isDoneAt(now)) return;
    final paused = session.pause(now);
    _session = paused;
    _timer?.cancel();
    _notify();
    await _save(paused);
    await _showNotices(paused);
  }

  Future<void> resume() async {
    final session = _session;
    if (_busy || session == null || !session.isPaused) return;
    final resumed = session.resume(_clock());
    _session = resumed;
    _arm();
    _notify();
    await _save(resumed);
    await _showNotices(resumed);
  }

  /// Detiene la sesión y paga sus minutos completos: "Terminar", o la cuenta
  /// llegando a cero. Devuelve null si no hay nada que terminar.
  ///
  /// Si el pago falla, lanza [SeedlyDropsException] y la sesión queda en
  /// pausa donde terminó: no se pierde ningún minuto y volver a llamarlo lo
  /// intenta otra vez.
  Future<SeedlyWateringOutcome?> finish() async {
    final session = _session;
    if (_busy || session == null) return null;
    _timer?.cancel();
    final now = _clock();
    final completed = session.isDoneAt(now);
    final frozen = session.pause(now);
    final minutes = frozen.paidMinutesAt(now);
    _session = frozen;
    _busy = true;
    _notify();
    try {
      await _save(frozen);
      if (minutes < SeedlyWatering.minMinutes) {
        await _close(frozen, keepEndNotice: false);
        _stage = SeedlyWateringStage.ready;
        return SeedlyWateringOutcome.tooShort;
      }
      final int paid;
      try {
        paid = await _drops.payWateringSession(frozen.id, minutes);
      } on SeedlyDropsException {
        _failedPayments++;
        await _showNotices(frozen);
        rethrow;
      }
      // Fuera de la app, el aviso de "sesión terminada" es como la persona
      // se entera; dentro, ya lo dice la pantalla.
      await _close(frozen, keepEndNotice: completed && !_inForeground());
      if (paid == 0) {
        _stage = SeedlyWateringStage.ready;
        return SeedlyWateringOutcome.alreadyPaid;
      }
      _result = SeedlyWateringResult(drops: paid, minutes: minutes);
      _stage = SeedlyWateringStage.done;
      return SeedlyWateringOutcome.paid;
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// Descarta la sesión sin pagarla, cuando el pago sigue fallando.
  Future<void> discard() async {
    final session = _session;
    if (_busy || session == null) return;
    await _close(session, keepEndNotice: false);
    _stage = SeedlyWateringStage.ready;
    _notify();
  }

  /// Deja "Fin de riego" para empezar otra sesión.
  void dismissResult() {
    if (_stage != SeedlyWateringStage.done) return;
    _result = null;
    _stage = SeedlyWateringStage.ready;
    _notify();
  }

  /// Al cerrar sesión: se van las notificaciones, pero la sesión guardada
  /// queda para la próxima vez que esta persona entre.
  Future<void> suspend() async {
    _timer?.cancel();
    final session = _session;
    final notifications = _notifications;
    if (session == null || notifications == null) return;
    await _quietly(
      () => notifications.cancelWateringSessionNotification(session.id),
    );
    await _quietly(() => notifications.cancelWateringSessionEnd(session.id));
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }

  /// Termina la sesión cuando su cuenta llega a cero.
  void _arm() {
    _timer?.cancel();
    final endsAt = _session?.endsAt;
    if (endsAt == null) return;
    final wait = endsAt.difference(_clock());
    _timer = Timer(wait.isNegative ? Duration.zero : wait, _timeUp);
  }

  void _timeUp() {
    final session = _session;
    if (_disposed || session == null || session.isPaused) return;
    // El reloj cambió desde que se programó el timer: se espera lo que falta.
    if (!session.isDoneAt(_clock())) return _arm();
    // Si falla, la sesión queda en "Regando", donde "Terminar" reintenta.
    unawaited(finish().then((_) {}, onError: (Object _) {}));
  }

  Future<void> _close(
    SeedlyWateringSession session, {
    required bool keepEndNotice,
  }) async {
    _timer?.cancel();
    _session = null;
    _failedPayments = 0;
    await _quietly(() => _store.clear(session.ownerId));
    final notifications = _notifications;
    if (notifications == null) return;
    await _quietly(
      () => notifications.cancelWateringSessionNotification(session.id),
    );
    if (!keepEndNotice) {
      await _quietly(() => notifications.cancelWateringSessionEnd(session.id));
    }
  }

  /// Sin la copia guardada la sesión sigue igual; solo no se puede retomar
  /// si se cierra la app.
  Future<void> _save(SeedlyWateringSession session) =>
      _quietly(() => _store.save(session));

  /// El aviso fijo mientras la sesión corre o está en pausa, y el de "sesión
  /// terminada" programado para su final.
  Future<void> _showNotices(SeedlyWateringSession session) async {
    final notifications = _notifications;
    if (notifications == null) return;
    if (session.isDoneAt(_clock())) {
      await _quietly(
        () => notifications.cancelWateringSessionNotification(session.id),
      );
      return;
    }
    final endsAt = session.endsAt;
    await _quietly(
      () => notifications.showWateringSessionNotification(
        sessionId: session.id,
        title: endsAt == null ? _pausedTitle : _runningTitle,
        // Con sesión corriendo el tiempo restante lo lleva la cuenta regresiva
        // viva del aviso (ver [endsAt] en la capa de notificaciones), así que
        // el cuerpo solo nombra el enfoque.
        body: endsAt == null ? _pausedBody : session.focusTitle ?? 'Sesión libre',
        endsAt: endsAt,
      ),
    );
    await _quietly(
      () => endsAt == null
          ? notifications.cancelWateringSessionEnd(session.id)
          : notifications.scheduleWateringSessionEnd(
              sessionId: session.id,
              at: endsAt,
              title: endTitle,
              body: endBody,
            ),
    );
  }

  /// Las notificaciones y la copia guardada son extras: si fallan, la sesión
  /// no se detiene.
  static Future<void> _quietly(Future<void>? Function() action) async {
    try {
      await action();
    } on Object {
      // Nada que hacer: la sesión sigue sin ellas.
    }
  }

  static bool _appInForeground() =>
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}
