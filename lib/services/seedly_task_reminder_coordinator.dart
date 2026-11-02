import 'dart:async';

import '../models/seedly_project.dart';
import 'seedly_notification_service.dart';
import 'seedly_task_reminders.dart';

/// Keeps local task notifications aligned with the complete future-task feed.
///
/// The coordinator filters eligibility before handing tasks to the platform
/// service. The service owns the platform-specific cancellation and
/// rescheduling details, so a Firestore error never causes destructive work.
class SeedlyTaskReminderCoordinator {
  SeedlyTaskReminderCoordinator({
    required this._tasks,
    required this._notifications,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Stream<List<SeedlyTask>> _tasks;
  final SeedlyNotificationService _notifications;
  final DateTime Function() _now;
  StreamSubscription<List<SeedlyTask>>? _subscription;
  bool _disposed = false;

  /// Starts listening once; repeated calls are safe for screen rebuilds.
  Future<void> start() async {
    if (_subscription != null || _disposed) return;
    _subscription = _tasks.listen(
      _reconcile,
      onError: (_, _) {
        // Keep existing platform schedules until Firestore emits a complete
        // replacement snapshot. A transient error must not cancel reminders.
      },
    );
  }

  Future<void> _reconcile(List<SeedlyTask> tasks) async {
    if (_disposed) return;
    final now = _now();
    final eligible = tasks.where(
      (task) => SeedlyTaskReminder.at(task, now: now) != null,
    );
    try {
      await _notifications.syncTaskReminders(eligible);
    } on Object {
      // Platform failures should not terminate the Firestore subscription.
    }
  }

  /// Stops listening without changing notifications owned by another screen.
  Future<void> dispose() async {
    _disposed = true;
    await _subscription?.cancel();
    _subscription = null;
  }
}
