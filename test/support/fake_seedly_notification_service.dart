import 'package:seedly/models/seedly_project.dart';
import 'package:seedly/services/seedly_notification_service.dart';

/// El aviso fijo de una sesión de riego, tal como se mostró por última vez.
typedef FakeWateringNotice = ({String title, String body, DateTime? endsAt});

/// El aviso de "sesión terminada", tal como se programó por última vez.
typedef FakeWateringEnd = ({DateTime at, String title, String body});

class FakeSeedlyNotificationService implements SeedlyNotificationService {
  SeedlyNotificationPermission permission =
      SeedlyNotificationPermission.granted;
  int initializeCalls = 0;
  int permissionRequests = 0;
  int wateringPermissionRequests = 0;
  int cancelAllCalls = 0;
  void Function(String taskId)? onTaskReminderTap;
  void Function(String sessionId)? onWateringSessionTap;

  /// Si está presente, todos los métodos de riego lo lanzan.
  Object? wateringError;

  final scheduled = <String, SeedlyTask>{};
  final cancelledTaskIds = <String>[];
  final wateringShown = <String>[];
  final wateringCancelled = <String>[];

  /// Avisos fijos en pantalla, por id de sesión.
  final wateringNotices = <String, FakeWateringNotice>{};

  /// Avisos de "sesión terminada" pendientes o mostrados, por id de sesión.
  final wateringEnds = <String, FakeWateringEnd>{};
  final wateringEndsCancelled = <String>[];

  @override
  Future<void> initialize({
    void Function(String taskId)? onTaskReminderTap,
    void Function(String sessionId)? onWateringSessionTap,
  }) async {
    initializeCalls++;
    this.onTaskReminderTap = onTaskReminderTap;
    this.onWateringSessionTap = onWateringSessionTap;
  }

  @override
  Future<SeedlyNotificationPermission> requestReminderPermission() async {
    permissionRequests++;
    return permission;
  }

  @override
  Future<SeedlyNotificationPermission> requestWateringPermission() async {
    wateringPermissionRequests++;
    _checkWatering();
    return permission;
  }

  @override
  Future<void> scheduleTaskReminder(SeedlyTask task) async {
    scheduled[task.id] = task;
  }

  @override
  Future<void> cancelTaskReminder(String taskId) async {
    cancelledTaskIds.add(taskId);
    scheduled.remove(taskId);
  }

  @override
  Future<void> syncTaskReminders(Iterable<SeedlyTask> tasks) async {
    scheduled
      ..clear()
      ..addEntries(tasks.map((task) => MapEntry(task.id, task)));
  }

  @override
  Future<void> cancelAllTaskReminders() async {
    cancelAllCalls++;
    scheduled.clear();
  }

  @override
  Future<void> showWateringSessionNotification({
    required String sessionId,
    required String title,
    required String body,
    DateTime? endsAt,
  }) async {
    _checkWatering();
    wateringShown.add(sessionId);
    wateringNotices[sessionId] = (title: title, body: body, endsAt: endsAt);
  }

  @override
  Future<void> cancelWateringSessionNotification(String sessionId) async {
    _checkWatering();
    wateringCancelled.add(sessionId);
    wateringNotices.remove(sessionId);
  }

  @override
  Future<void> scheduleWateringSessionEnd({
    required String sessionId,
    required DateTime at,
    required String title,
    required String body,
  }) async {
    _checkWatering();
    wateringEnds[sessionId] = (at: at, title: title, body: body);
  }

  @override
  Future<void> cancelWateringSessionEnd(String sessionId) async {
    _checkWatering();
    wateringEndsCancelled.add(sessionId);
    wateringEnds.remove(sessionId);
  }

  void _checkWatering() {
    if (wateringError case final error?) throw error;
  }
}
