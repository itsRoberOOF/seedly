import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/models/seedly_project.dart';

void main() {
  test('SeedlyTask preserves its Firestore read fields', () {
    final task = SeedlyTask(
      id: 'task-1',
      projectId: 'project-1',
      title: 'Sembrar',
      done: false,
      order: 2,
      dueDate: DateTime(2026, 11, 2),
      dueMinutes: 9 * 60,
      reminderMinutes: 30,
    );

    expect(task.id, 'task-1');
    expect(task.projectId, 'project-1');
    expect(task.title, 'Sembrar');
    expect(task.done, isFalse);
    expect(task.order, 2);
    expect(task.dueDate, DateTime(2026, 11, 2));
    expect(task.dueMinutes, 9 * 60);
    expect(task.reminderMinutes, 30);
  });
}
