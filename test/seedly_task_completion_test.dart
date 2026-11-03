import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/models/seedly_errors.dart';
import 'package:seedly/models/seedly_project.dart';
import 'package:seedly/services/seedly_task_completion.dart';

import 'support/fake_seedly_drops_repository.dart';
import 'support/fake_seedly_project_repository.dart';

SeedlyTask task({bool done = false}) => SeedlyTask(
  id: 't1',
  projectId: 'p1',
  title: 'Sembrar',
  done: done,
  order: 0,
);

void main() {
  late FakeSeedlyProjectRepository projects;
  late FakeSeedlyDropsRepository drops;
  late SeedlyTaskCompletion completion;

  setUp(() {
    projects = FakeSeedlyProjectRepository();
    drops = FakeSeedlyDropsRepository();
    completion = SeedlyTaskCompletion(projects: projects, drops: drops);
  });

  test('ticking saves the task and pays the task and project drops', () async {
    await completion.setDone(task(), true);
    expect(projects.doneChanges, [('t1', true)]);
    expect(drops.paid.keys, containsAll(['task_t1', 'project_p1']));
  });

  test('unticking saves the task and takes its drops back', () async {
    await completion.setDone(task(), true);
    await completion.setDone(task(done: true), false);
    expect(projects.doneChanges, [('t1', true), ('t1', false)]);
    expect(drops.paid.keys, isNot(contains('task_t1')));
  });

  test('moving a task relocates it and settles the destination project', () async {
    await completion.move(task(), 'p2', const NewSeedlyTask('Sembrar'));
    expect(projects.movedTasks, [('t1', 'p2', const NewSeedlyTask('Sembrar'))]);
    expect(drops.paid.keys, contains('project_p2'));
  });

  test('a drops failure never undoes the move', () async {
    drops.error = const SeedlyDropsException(SeedlyDropsError.saveFailed);
    await completion.move(task(), 'p2', const NewSeedlyTask('Sembrar'));
    expect(projects.movedTasks, [('t1', 'p2', const NewSeedlyTask('Sembrar'))]);
  });

  test('a move task failure is thrown and pays nothing', () async {
    projects.error = const SeedlyProjectException(SeedlyProjectError.saveFailed);
    await expectLater(
      completion.move(task(), 'p2', const NewSeedlyTask('Sembrar')),
      throwsA(isA<SeedlyProjectException>()),
    );
    expect(drops.paid, isEmpty);
  });

  test('deleting a done task takes its drops back', () async {
    await completion.setDone(task(), true);
    await completion.delete(task(done: true));
    expect(projects.deletedTasks, ['t1']);
    expect(drops.paid.keys, isNot(contains('task_t1')));
  });

  test('deleting a pending task leaves the drops alone', () async {
    drops.paid['task_other'] = 3;
    await completion.delete(task());
    expect(projects.deletedTasks, ['t1']);
    expect(drops.paid, {'task_other': 3});
  });

  test('a drops failure never undoes the task', () async {
    drops.error = const SeedlyDropsException(SeedlyDropsError.saveFailed);
    await completion.setDone(task(), true);
    expect(projects.doneChanges, [('t1', true)]);
  });

  test('a task failure is thrown and pays nothing', () async {
    projects.error = const SeedlyProjectException(
      SeedlyProjectError.saveFailed,
    );
    await expectLater(
      completion.setDone(task(), true),
      throwsA(isA<SeedlyProjectException>()),
    );
    expect(drops.paid, isEmpty);
  });

  test('without drops it only saves the task', () async {
    await SeedlyTaskCompletion(projects: projects).setDone(task(), true);
    expect(projects.doneChanges, [('t1', true)]);
  });
}
