import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/models/seedly_errors.dart';
import 'package:seedly/models/seedly_project.dart';
import 'package:seedly/screens/seedly_projects_view.dart';
import 'package:seedly/theme/seedly_theme.dart';

import 'support/fake_seedly_drops_repository.dart';
import 'support/fake_seedly_project_repository.dart';

const huerto = SeedlyProject(
  id: 'p1',
  name: 'Huerto',
  kind: SeedlyProjectKind.full,
  icon: SeedlyProjectIcon.hogar,
  description: 'Tomates',
  taskCount: 3,
  doneCount: 1,
);

const tasks = [
  SeedlyTask(id: 't1', projectId: 'p1', title: 'Sembrar', done: true, order: 0),
  SeedlyTask(id: 't2', projectId: 'p1', title: 'Regar', done: false, order: 1),
];

/// Like Firestore's snapshots: every new listener gets the current value,
/// which a screen needs when it remounts a list it had closed.
Stream<T> replay<T>(T value) => Stream.multi((listener) => listener.add(value));

Widget app(
  FakeSeedlyProjectRepository projects, {
  FakeSeedlyDropsRepository? drops,
}) => MaterialApp(
  theme: SeedlyTheme.light,
  home: Scaffold(
    body: SeedlyProjectsView(projects: projects, drops: drops),
  ),
);

void main() {
  testWidgets('shows a loader until the first projects arrive', (tester) async {
    final controller = StreamController<List<SeedlyProject>>();
    addTearDown(controller.close);
    await tester.pumpWidget(
      app(FakeSeedlyProjectRepository(projects: controller.stream)),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    controller.add([huerto]);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Huerto'), findsOneWidget);
    expect(find.text('3 tareas • 33% completado'), findsOneWidget);
  });

  testWidgets('explains an empty catalog', (tester) async {
    await tester.pumpWidget(
      app(FakeSeedlyProjectRepository(projects: Stream.value([]))),
    );
    await tester.pump();
    expect(find.textContaining('Aún no tienes proyectos'), findsOneWidget);
  });

  testWidgets('a failed load offers to retry', (tester) async {
    final projects = FakeSeedlyProjectRepository(
      projects: Stream.error(
        const SeedlyProjectException(SeedlyProjectError.loadFailed),
      ),
    );
    await tester.pumpWidget(app(projects));
    await tester.pump();
    expect(find.textContaining('No se pudieron cargar'), findsOneWidget);

    projects.projects = Stream.value([huerto]);
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Huerto'), findsOneWidget);
  });

  group('catalog', () {
    SeedlyProject project(
      String id,
      String name, {
      int tasks = 4,
      int done = 1,
      DateTime? end,
    }) => SeedlyProject(
      id: id,
      name: name,
      kind: SeedlyProjectKind.full,
      icon: SeedlyProjectIcon.planta,
      taskCount: tasks,
      doneCount: done,
      endDate: end,
    );

    Future<void> open(
      WidgetTester tester,
      List<SeedlyProject> list, {
      DateTime? today,
    }) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: SeedlyTheme.light,
          home: Scaffold(
            body: SeedlyProjectsView(
              projects: FakeSeedlyProjectRepository(
                projects: replay(list),
                tasksOfProject: replay(tasks),
              ),
              today: today,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('Activos and Completados split the projects', (tester) async {
      await open(tester, [
        project('a', 'En curso'),
        project('b', 'Terminado', tasks: 2, done: 2),
      ]);
      expect(find.text('En curso'), findsOneWidget);
      expect(find.text('Terminado'), findsNothing);

      await tester.tap(find.text('Completados'));
      await tester.pump();
      expect(find.text('Terminado'), findsOneWidget);
      expect(find.text('En curso'), findsNothing);
    });

    testWidgets('the search bar filters by name', (tester) async {
      await open(tester, [
        project('a', 'Huerto'),
        project('b', 'Arquitectura'),
      ]);
      await tester.enterText(find.byType(TextField), 'arqui');
      await tester.pump();
      expect(find.text('Arquitectura'), findsOneWidget);
      expect(find.text('Huerto'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(
        find.textContaining('No hay proyectos que coincidan'),
        findsOneWidget,
      );
    });

    testWidgets('an expanded card shows its tag and pending tasks', (
      tester,
    ) async {
      await open(tester, [
        project('a', 'Huerto', end: DateTime(2026, 11, 3)),
      ], today: DateTime(2026, 11, 2));
      expect(find.text('1 día para la entrega'), findsNothing);
      await tester.tap(find.text('Huerto'));
      await tester.pump();
      await tester.pump();
      expect(find.text('1 día para la entrega'), findsOneWidget);
      // Only the pending task of the sample list, not the done one.
      expect(find.text('Regar'), findsOneWidget);
      expect(find.text('Sembrar'), findsNothing);
      expect(find.text('Ver proyecto'), findsOneWidget);

      await tester.tap(find.text('Huerto'));
      await tester.pump();
      expect(find.text('Ver proyecto'), findsNothing);
    });

    testWidgets('a project ending in more than a week shows no tag', (
      tester,
    ) async {
      await open(tester, [
        project('a', 'Huerto', end: DateTime(2026, 12, 25)),
      ], today: DateTime(2026, 11, 2));
      await tester.tap(find.text('Huerto'));
      await tester.pump();
      expect(find.textContaining('para la entrega'), findsNothing);
    });
  });

  group('detail', () {
    late FakeSeedlyProjectRepository projects;
    late FakeSeedlyDropsRepository drops;

    setUp(() {
      projects = FakeSeedlyProjectRepository(
        projects: replay([huerto]),
        projectById: replay<SeedlyProject?>(huerto),
        tasksOfProject: replay(tasks),
      );
      drops = FakeSeedlyDropsRepository();
    });

    Future<void> openDetail(WidgetTester tester) async {
      // The Figma frame's size, tall enough for the delete modal.
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(projects, drops: drops));
      await tester.pump();
      // Expand the card, then open the project from it.
      await tester.tap(find.text('Huerto'));
      await tester.pump();
      await tester.tap(find.text('Ver proyecto'));
      // The project and then its tasks arrive on separate streams.
      for (var i = 0; i < 3; i++) {
        await tester.pump();
      }
    }

    testWidgets('opens from the catalog with its tasks', (tester) async {
      await openDetail(tester);
      expect(find.text('Tomates'), findsOneWidget);
      expect(find.text('Sembrar'), findsOneWidget);
      expect(find.text('Regar'), findsOneWidget);
    });

    testWidgets('ticking a task saves it and pays its drops', (tester) async {
      await openDetail(tester);
      await tester.tap(find.text('Regar'));
      await tester.pump();
      expect(projects.doneChanges, [('t2', true)]);
      expect(drops.paid.keys, contains('task_t2'));
    });

    testWidgets('completing a task shows one instant drops toast', (
      tester,
    ) async {
      await openDetail(tester);
      await tester.tap(find.text('Regar'));
      // Shown on the same frame as the tap, before the write settles, and only
      // ever one at a time.
      await tester.pump();
      expect(find.textContaining('gotas'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.textContaining('gotas'), findsOneWidget);
    });

    testWidgets('the filter shows pending and completed tasks', (tester) async {
      await openDetail(tester);
      expect(find.text('1 restante'), findsOneWidget);
      await tester.tap(find.text('Pendientes'));
      await tester.pump();
      expect(find.text('Regar'), findsOneWidget);
      expect(find.text('Sembrar'), findsNothing);
      await tester.tap(find.text('Completadas'));
      await tester.pump();
      expect(find.text('Sembrar'), findsOneWidget);
      expect(find.text('Regar'), findsNothing);
      await tester.tap(find.text('Todas'));
      await tester.pump();
      expect(find.text('Regar'), findsOneWidget);
      expect(find.text('Sembrar'), findsOneWidget);
    });

    testWidgets('deleting a task asks first, in the Figma modal', (
      tester,
    ) async {
      await openDetail(tester);
      await tester.tap(find.byTooltip('Más opciones').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      expect(find.text('Eliminar tarea'), findsOneWidget);
      expect(projects.deletedTasks, isEmpty);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(projects.deletedTasks, isEmpty);

      await tester.tap(find.byTooltip('Más opciones').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      // The modal's own "Eliminar" button.
      await tester.tap(find.text('Eliminar').last);
      await tester.pumpAndSettle();
      expect(projects.deletedTasks, ['t2']);
    });

    testWidgets('the trash can of Editar proyecto deletes it after asking', (
      tester,
    ) async {
      await openDetail(tester);
      await tester.tap(find.byTooltip('Editar proyecto'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Eliminar proyecto'));
      await tester.pumpAndSettle();
      expect(find.text('Eliminar proyecto'), findsOneWidget);
      expect(projects.deletedProjects, isEmpty);
      await tester.tap(find.text('Eliminar').last);
      await tester.pumpAndSettle();
      expect(projects.deletedProjects, ['p1']);
    });

    testWidgets('editing the project saves its fields', (tester) async {
      await openDetail(tester);
      await tester.tap(find.byTooltip('Editar proyecto'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Huerto'),
        'Jardín',
      );
      await tester.ensureVisible(find.text('Guardar cambios'));
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      final (id, changes) = projects.updatedProjects.single;
      expect(id, 'p1');
      expect(changes.name, 'Jardín');
      expect(changes.description, 'Tomates');
    });

    testWidgets('Editar proyecto lists the tasks and can add one', (
      tester,
    ) async {
      await openDetail(tester);
      await tester.tap(find.byTooltip('Editar proyecto'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Sembrar'));
      expect(find.text('Sembrar'), findsOneWidget);
      expect(find.text('Regar'), findsOneWidget);
      await tester.ensureVisible(find.text('Añadir tarea'));
      await tester.tap(find.text('Añadir tarea'));
      await tester.pumpAndSettle();
      expect(find.text('Nueva tarea'), findsWidgets);
      // Back goes to Editar proyecto, where it was opened from.
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(find.text('Editar proyecto'), findsOneWidget);
    });

    testWidgets('editing a task saves its title', (tester) async {
      await openDetail(tester);
      await tester.tap(find.byTooltip('Más opciones').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      expect(find.text('Editar tarea'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Regar'),
        'Regar mucho',
      );
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      final (id, task) = projects.updatedTasks.single;
      expect(id, 't2');
      expect(task.title, 'Regar mucho');
      expect(task.done, isFalse);
    });

    testWidgets('adding a task appends it to this project', (tester) async {
      await openDetail(tester);
      await tester.tap(find.text('Añadir tarea'));
      await tester.pumpAndSettle();
      expect(find.text('Nueva tarea'), findsWidgets);
      await tester.enterText(find.byType(TextFormField).first, 'Cosechar');
      await tester.tap(find.text('Crear tarea'));
      await tester.pumpAndSettle();
      final (id, task) = projects.addedTasks.single;
      expect(id, 'p1');
      expect(task.title, 'Cosechar');
    });

    testWidgets('a failed save is reported and keeps the form open', (
      tester,
    ) async {
      await openDetail(tester);
      projects.error = const SeedlyProjectException(
        SeedlyProjectError.saveFailed,
      );
      await tester.tap(find.byTooltip('Más opciones').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(find.text('No se pudo guardar la tarea'), findsOneWidget);
      expect(find.text('Editar tarea'), findsOneWidget);
    });
  });
}
