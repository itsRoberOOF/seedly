import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/models/seedly_project.dart';
import 'package:seedly/services/seedly_task_reminder_coordinator.dart';

import 'support/fake_seedly_notification_service.dart';

void main() {
  final now = DateTime(2026, 11, 2, 8);

  SeedlyTask task(String id, {bool done = false, int reminderMinutes = 30}) =>
      SeedlyTask(
        id: id,
        projectId: 'project',
        title: id,
        done: done,
        order: 0,
        dueDate: DateTime(2026, 11, 2),
        dueMinutes: 9 * 60,
        reminderMinutes: reminderMinutes,
      );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test(
    'reconciles eligible tasks and removes stale or ineligible ones',
    () async {
      final tasks = StreamController<List<SeedlyTask>>();
      final notifications = FakeSeedlyNotificationService();
      final coordinator = SeedlyTaskReminderCoordinator(
        tasks: tasks.stream,
        notifications: notifications,
        now: () => now,
      );
      await coordinator.start();

      tasks.add([task('keep'), task('done', done: true)]);
      await settle();
      expect(notifications.scheduled.keys, ['keep']);

      tasks.add([task('keep', reminderMinutes: 10), task('new')]);
      await settle();
      expect(notifications.scheduled.keys, ['keep', 'new']);
      expect(notifications.scheduled['keep']!.reminderMinutes, 10);

      tasks.add([task('new')]);
      await settle();
      expect(notifications.scheduled.keys, ['new']);

      await coordinator.dispose();
      await tasks.close();
    },
  );

  test(
    'stream errors preserve existing schedules and do not cancel all',
    () async {
      final tasks = StreamController<List<SeedlyTask>>();
      final notifications = FakeSeedlyNotificationService();
      final coordinator = SeedlyTaskReminderCoordinator(
        tasks: tasks.stream,
        notifications: notifications,
        now: () => now,
      );
      await coordinator.start();

      tasks.add([task('keep')]);
      await settle();
      tasks.addError(StateError('temporary Firestore error'));
      await settle();

      expect(notifications.scheduled.keys, ['keep']);
      expect(notifications.cancelAllCalls, 0);

      await coordinator.dispose();
      await tasks.close();
    },
  );

  test('dispose stops reconciliation', () async {
    final tasks = StreamController<List<SeedlyTask>>();
    final notifications = FakeSeedlyNotificationService();
    final coordinator = SeedlyTaskReminderCoordinator(
      tasks: tasks.stream,
      notifications: notifications,
      now: () => now,
    );
    await coordinator.start();
    await coordinator.dispose();

    tasks.add([task('ignored')]);
    await settle();

    expect(notifications.scheduled, isEmpty);
    await tasks.close();
  });
}
