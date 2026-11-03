import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/models/seedly_errors.dart';
import 'package:seedly/models/seedly_project.dart';
import 'package:seedly/screens/seedly_add_task_view.dart';
import 'package:seedly/theme/seedly_theme.dart';
import 'package:seedly/widgets/seedly_modal.dart';

import 'support/fake_seedly_project_repository.dart';

const huerto = SeedlyProject(
  id: 'p1',
  name: 'Huerto',
  kind: SeedlyProjectKind.full,
  icon: SeedlyProjectIcon.hogar,
  taskCount: 4,
  doneCount: 2,
);

const arquitectura = SeedlyProject(
  id: 'p2',
  name: 'Arquitectura',
  kind: SeedlyProjectKind.full,
  icon: SeedlyProjectIcon.codigo,
  taskCount: 2,
  doneCount: 1,
);

void main() {
  late FakeSeedlyProjectRepository projects;
  late List<(SeedlyProject, NewSeedlyTask)> created;
  var closed = 0;

  Future<void> open(
    WidgetTester tester, {
    List<SeedlyProject> list = const [huerto, arquitectura],
    DateTime? today,
  }) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    projects = FakeSeedlyProjectRepository(projects: Stream.value(list));
    created = [];
    closed = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: SeedlyTheme.light,
        home: Scaffold(
          body: SeedlyAddTaskView(
            projects: projects,
            today: today ?? DateTime(2026, 11, 2),
            onClose: () => closed++,
            onCreated: (project, task) => created.add((project, task)),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> pickProject(WidgetTester tester, String name) async {
    await tester.tap(find.text('Elige un proyecto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  testWidgets('starts asking for a project', (tester) async {
    await open(tester);
    expect(find.text('Nueva tarea'), findsOneWidget);
    expect(find.text('Proyecto *'), findsOneWidget);
    expect(find.text('Elige un proyecto'), findsOneWidget);
  });

  testWidgets('the modal lists the projects with their progress', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Elige un proyecto'));
    await tester.pumpAndSettle();
    expect(find.text('Buscar proyectos...'), findsOneWidget);
    expect(find.text('Huerto'), findsOneWidget);
    expect(find.text('4 tareas • 50% completado'), findsOneWidget);
    expect(find.text('Arquitectura'), findsOneWidget);
  });

  testWidgets('the modal search filters by name', (tester) async {
    await open(tester);
    await tester.tap(find.text('Elige un proyecto'));
    await tester.pumpAndSettle();
    // The modal's own search field, not the task title behind it.
    final search = find.descendant(
      of: find.byType(SeedlyModal),
      matching: find.byType(TextField),
    );
    await tester.enterText(search, 'arqui');
    await tester.pump();
    expect(find.text('Arquitectura'), findsOneWidget);
    expect(find.text('Huerto'), findsNothing);
    await tester.enterText(search, 'zzz');
    await tester.pump();
    expect(
      find.textContaining('No hay proyectos que coincidan'),
      findsOneWidget,
    );
  });

  testWidgets('a person with no projects is told to create one first', (
    tester,
  ) async {
    await open(tester, list: const []);
    await tester.tap(find.text('Elige un proyecto'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Aún no tienes proyectos'), findsOneWidget);
  });

  testWidgets('choosing a project shows it in the field', (tester) async {
    await open(tester);
    await pickProject(tester, 'Arquitectura');
    expect(find.text('Elige un proyecto'), findsNothing);
    expect(find.text('Arquitectura'), findsOneWidget);
  });

  testWidgets('saving without a project is refused and says so', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Regar');
    await tester.tap(find.text('Crear tarea'));
    await tester.pump();
    expect(find.text('Campos incompletos'), findsOneWidget);
    expect(find.text('Elige un proyecto'), findsWidgets);
    expect(projects.addedTasks, isEmpty);
    expect(created, isEmpty);
  });

  testWidgets('saving without a title is refused even with a project', (
    tester,
  ) async {
    await open(tester);
    await pickProject(tester, 'Huerto');
    await tester.tap(find.text('Crear tarea'));
    await tester.pump();
    expect(find.text('Campos incompletos'), findsOneWidget);
    expect(projects.addedTasks, isEmpty);
  });

  testWidgets('saving adds the task to the chosen project', (tester) async {
    await open(tester);
    await pickProject(tester, 'Huerto');
    await tester.enterText(find.byType(TextFormField).first, 'Cosechar');
    await tester.tap(find.text('Crear tarea'));
    await tester.pumpAndSettle();

    final (projectId, task) = projects.addedTasks.single;
    expect(projectId, 'p1');
    expect(task.title, 'Cosechar');
    expect(task.done, isFalse);
    expect(created.single.$1.name, 'Huerto');
    expect(created.single.$2.title, 'Cosechar');
  });

  testWidgets('a quick date is saved with the task', (tester) async {
    await open(tester);
    await pickProject(tester, 'Huerto');
    await tester.enterText(find.byType(TextFormField).first, 'Regar');
    await tester.tap(find.text('Mañana'));
    await tester.pump();
    await tester.tap(find.text('Crear tarea'));
    await tester.pumpAndSettle();
    expect(projects.addedTasks.single.$2.dueDate, DateTime(2026, 11, 3));
  });

  testWidgets('a failed save is reported and the form stays open', (
    tester,
  ) async {
    await open(tester);
    projects.error = const SeedlyProjectException(
      SeedlyProjectError.saveFailed,
    );
    await pickProject(tester, 'Huerto');
    await tester.enterText(find.byType(TextFormField).first, 'Cosechar');
    await tester.tap(find.text('Crear tarea'));
    await tester.pumpAndSettle();
    expect(find.text('No se pudo crear la tarea'), findsOneWidget);
    expect(created, isEmpty);
    expect(find.text('Nueva tarea'), findsOneWidget);
  });

  testWidgets('back closes the form', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Volver'));
    await tester.pump();
    expect(closed, 1);
  });
}
