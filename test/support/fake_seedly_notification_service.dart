import 'package:seedly/models/seedly_project.dart';
import 'package:seedly/services/seedly_notification_service.dart';

class FakeSeedlyNotificationService implements SeedlyNotificationService {
  SeedlyNotificationPermission permission =
      SeedlyNotificationPermission.granted;
  int initializeCalls = 0;
  int permissionRequests = 0;
  int cancelAllCalls = 0;
  void Function(String taskId)? onTaskReminderTap;

  final scheduled = <String, SeedlyTask>{};
  final cancelledTaskIds = <String>[];
  final wateringShown = <String>[];
  final wateringCancelled = <String>[];

  @override
  Future<void> initialize({
    void Function(String taskId)? onTaskReminderTap,
  }) async {
    initializeCalls++;
    this.onTaskReminderTap = onTaskReminderTap;
  }

  @override
  Future<SeedlyNotificationPermission> requestReminderPermission() async {
    permissionRequests++;
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
  }) async {
    wateringShown.add(sessionId);
  }

  @override
  Future<void> cancelWateringSessionNotification(String sessionId) async {
    wateringCancelled.add(sessionId);
  }
}
