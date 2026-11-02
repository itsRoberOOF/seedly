import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/models/seedly_project.dart';
import 'package:seedly/services/seedly_task_reminders.dart';

SeedlyTask task({
  bool done = false,
  DateTime? dueDate,
  bool includeDueDate = true,
  int? dueMinutes = 9 * 60,
  int? reminderMinutes = 30,
}) => SeedlyTask(
  id: 'task-1',
  projectId: 'project-1',
  title: 'Sembrar',
  done: done,
  order: 0,
  dueDate: includeDueDate ? dueDate ?? DateTime(2026, 11, 2) : null,
  dueMinutes: dueMinutes,
  reminderMinutes: reminderMinutes,
);

void main() {
  final now = DateTime(2026, 11, 2, 8);

  test('calculates the local reminder instant from deadline and offset', () {
    expect(
      SeedlyTaskReminder.at(task(), now: now),
      DateTime(2026, 11, 2, 8, 30),
    );
  });

  test('ignores tasks that cannot produce a reminder', () {
    expect(
      SeedlyTaskReminder.at(task(includeDueDate: false), now: now),
      isNull,
    );
    expect(SeedlyTaskReminder.at(task(dueMinutes: null), now: now), isNull);
    expect(
      SeedlyTaskReminder.at(task(reminderMinutes: null), now: now),
      isNull,
    );
    expect(SeedlyTaskReminder.at(task(done: true), now: now), isNull);
  });

  test('does not schedule reminders at or after the deadline instant', () {
    expect(
      SeedlyTaskReminder.at(task(dueMinutes: 8 * 60 + 30), now: now),
      isNull,
    );
    expect(
      SeedlyTaskReminder.at(task(dueMinutes: 8 * 60 + 31), now: now),
      DateTime(2026, 11, 2, 8, 1),
    );
  });

  test('accepts only the supported reminder offsets', () {
    final beforeAnyReminder = DateTime(2026, 11, 2, 7);
    for (final minutes in [10, 30, 60]) {
      expect(
        SeedlyTaskReminder.at(
          task(reminderMinutes: minutes),
          now: beforeAnyReminder,
        ),
        isNotNull,
      );
    }
    expect(SeedlyTaskReminder.at(task(reminderMinutes: 15), now: now), isNull);
  });
}
