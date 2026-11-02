import '../models/seedly_project.dart';

enum SeedlyNotificationPermission { granted, denied, unavailable }

/// App-facing notification operations. Platform plugins stay behind this
/// interface so screens and tests do not depend on platform channels.
abstract interface class SeedlyNotificationService {
  Future<void> initialize({void Function(String taskId)? onTaskReminderTap});

  Future<SeedlyNotificationPermission> requestReminderPermission();

  Future<void> scheduleTaskReminder(SeedlyTask task);

  Future<void> cancelTaskReminder(String taskId);

  /// Reconciles all task reminders without touching the watering channel.
  Future<void> syncTaskReminders(Iterable<SeedlyTask> tasks);

  Future<void> cancelAllTaskReminders();

  Future<void> showWateringSessionNotification({
    required String sessionId,
    required String title,
    required String body,
  });

  Future<void> cancelWateringSessionNotification(String sessionId);
}

/// Keeps existing widget tests and unsupported platforms side-effect free.
class NoopSeedlyNotificationService implements SeedlyNotificationService {
  const NoopSeedlyNotificationService();

  @override
  Future<void> initialize({
    void Function(String taskId)? onTaskReminderTap,
  }) async {}

  @override
  Future<SeedlyNotificationPermission> requestReminderPermission() async =>
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
  }) async {}

  @override
  Future<void> cancelWateringSessionNotification(String sessionId) async {}
}
