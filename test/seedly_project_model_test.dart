import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/models/seedly_project.dart';

SeedlyProject _project({int taskCount = 4, int doneCount = 1}) => SeedlyProject(
  id: 'huerto',
  name: 'Huerto',
  kind: SeedlyProjectKind.full,
  icon: SeedlyProjectIcon.hogar,
  taskCount: taskCount,
  doneCount: doneCount,
);

void main() {
  test('progress and remaining follow the counters', () {
    final project = _project();
    expect(project.remaining, 3);
    expect(project.progress, 0.25);
    expect(project.isComplete, isFalse);
  });

  test('a project with every task done is complete', () {
    final project = _project(taskCount: 3, doneCount: 3);
    expect(project.remaining, 0);
    expect(project.progress, 1);
    expect(project.isComplete, isTrue);
  });

  test('a project without tasks is neither complete nor divided by zero', () {
    final project = _project(taskCount: 0, doneCount: 0);
    expect(project.progress, 0);
    expect(project.isComplete, isFalse);
  });

  test('equal projects compare equal', () {
    expect(_project(), _project());
    expect(_project().hashCode, _project().hashCode);
    expect(_project(), isNot(_project(doneCount: 2)));
  });
}
