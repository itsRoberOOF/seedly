import '../models/seedly_project.dart';

enum SeedlyNotificationPermission { granted, denied, unavailable }

/// App-facing notification operations. Platform plugins stay behind this
/// interface so screens and tests do not depend on platform channels.
abstract interface class SeedlyNotificationService {
  /// Configura el plugin una sola vez; las llamadas siguientes solo
  /// reemplazan los handlers de toque. Un toque que abrió la app antes de
  /// tener handler le llega cuando se registra.
  Future<void> initialize({
    void Function(String taskId)? onTaskReminderTap,
    void Function(String sessionId)? onWateringSessionTap,
  });

  Future<SeedlyNotificationPermission> requestReminderPermission();

  /// Pide solo permiso para mostrar notificaciones, sin abrir el ajuste de
  /// alarmas exactas que también abre [requestReminderPermission]: la sesión
  /// de riego se inicia desde la app y termina a tiempo aun sin ellas.
  Future<SeedlyNotificationPermission> requestWateringPermission();

  Future<void> scheduleTaskReminder(SeedlyTask task);

  Future<void> cancelTaskReminder(String taskId);

  /// Reconciles all task reminders without touching the watering channel.
  Future<void> syncTaskReminders(Iterable<SeedlyTask> tasks);

  Future<void> cancelAllTaskReminders();

  /// El aviso fijo y silencioso de una sesión en curso; mostrarlo de nuevo
  /// con el mismo [sessionId] lo actualiza sin sonar. Con [endsAt] se quita
  /// solo a esa hora.
  Future<void> showWateringSessionNotification({
    required String sessionId,
    required String title,
    required String body,
    DateTime? endsAt,
  });

  Future<void> cancelWateringSessionNotification(String sessionId);

  /// Programa el aviso de "sesión terminada" para [at], reemplazando uno
  /// anterior de la misma sesión. Suena aunque la app esté cerrada.
  Future<void> scheduleWateringSessionEnd({
    required String sessionId,
    required DateTime at,
    required String title,
    required String body,
  });

  /// Cancela el aviso de "sesión terminada", pendiente o ya mostrado.
  Future<void> cancelWateringSessionEnd(String sessionId);
}

/// Keeps existing widget tests and unsupported platforms side-effect free.
class NoopSeedlyNotificationService implements SeedlyNotificationService {
  const NoopSeedlyNotificationService();

  @override
  Future<void> initialize({
    void Function(String taskId)? onTaskReminderTap,
    void Function(String sessionId)? onWateringSessionTap,
  }) async {}

  @override
  Future<SeedlyNotificationPermission> requestReminderPermission() async =>
      SeedlyNotificationPermission.unavailable;

  @override
  Future<SeedlyNotificationPermission> requestWateringPermission() async =>
      SeedlyNotificationPermission.unavailable;

  @override
  Future<void> scheduleTaskReminder(SeedlyTask task) async {}

  @override
  Future<void> cancelTaskReminder(String taskId) async {}

  @override
  Future<void> syncTaskReminders(Iterable<SeedlyTask> tasks) async {}

  @override
  Future<void> cancelAllTaskReminders() async {}

  @override
  Future<void> showWateringSessionNotification({
    required String sessionId,
    required String title,
    required String body,
    DateTime? endsAt,
  }) async {}

  @override
  Future<void> cancelWateringSessionNotification(String sessionId) async {}

  @override
  Future<void> scheduleWateringSessionEnd({
    required String sessionId,
    required DateTime at,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> cancelWateringSessionEnd(String sessionId) async {}
}
