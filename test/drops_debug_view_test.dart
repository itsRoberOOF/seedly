import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/models/seedly_errors.dart';
import 'package:seedly/models/seedly_project.dart';
import 'package:seedly/screens/seedly_drops_debug_view.dart';

import 'support/fake_seedly_auth_repository.dart';
import 'support/fake_seedly_drops_repository.dart';
import 'support/fake_seedly_project_repository.dart';

Future<FakeSeedlyDropsRepository> _open(
  WidgetTester tester, {
  bool signedIn = true,
  int startingDrops = 0,
  FakeSeedlyProjectRepository? projects,
}) async {
  // Tall enough for the whole panel, which has grown past the default view.
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final drops = FakeSeedlyDropsRepository(startingDrops: startingDrops);
  await tester.pumpWidget(
    MaterialApp(
      home: SeedlyDropsDebugView(
        auth: FakeSeedlyAuthRepository(isSignedIn: signedIn),
        drops: drops,
        projects: projects ?? FakeSeedlyProjectRepository(),
        app: const Text('La app'),
      ),
    ),
  );
  await tester.pump();
  return drops;
}

void main() {
  testWidgets('asks to sign in first', (tester) async {
    await _open(tester, signedIn: false);

    expect(find.text('Iniciar sesión'), findsWidgets);
    expect(find.textContaining('Fase'), findsNothing);
  });

  testWidgets('shows the plant and pays a task', (tester) async {
    await _open(tester);
    await tester.pump();
    expect(find.text('Fase 1 · 0 gotas · meta 150'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('drops-id')), 't1');
    await tester.tap(find.text('Pagar tarea'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Pagar tarea: 3'), findsOneWidget);
    expect(find.text('Fase 1 · 3 gotas · meta 150'), findsOneWidget);
  });

  testWidgets('shows why the plant cannot grow', (tester) async {
    await _open(tester);

    await tester.tap(find.text('Crecer'));
    await tester.pump();

    expect(
      find.text('Crecer: Aún no tienes gotas suficientes para crecer.'),
      findsOneWidget,
    );
  });

  testWidgets('grows once there are enough drops', (tester) async {
    await _open(tester, startingDrops: 150);

    await tester.tap(find.text('Crecer'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Fase 2 · 150 gotas · meta 500'), findsOneWidget);
  });

  group('sample projects', () {
    testWidgets('creates two projects with tasks due today', (tester) async {
      final projects = FakeSeedlyProjectRepository();
      await _open(tester, projects: projects);

      await tester.tap(find.text('Crear proyectos de prueba (tareas de hoy)'));
      await tester.pump();

      expect(
        find.text('Crear proyectos de prueba: 2 proyectos con tareas de hoy'),
        findsOneWidget,
      );
      expect(projects.created.map((project) => project.name), [
        'Prueba UI/UX',
        'Prueba Arquitectura',
      ]);
    });

    testWidgets('shows why they could not be created', (tester) async {
      final projects = FakeSeedlyProjectRepository(
        error: const SeedlyProjectException(SeedlyProjectError.sessionExpired),
      );
      await _open(tester, projects: projects);

      await tester.tap(find.text('Crear proyectos de prueba (tareas de hoy)'));
      await tester.pump();

      expect(projects.created, isEmpty);
      expect(
        find.textContaining('Crear proyectos de prueba: '),
        findsOneWidget,
      );
    });

    test('the tasks are due today and the rings differ', () {
      final today = DateTime(2026, 11, 2, 17, 45);
      final samples = SeedlyDropsDebugView.sampleProjects(today);

      for (final project in samples) {
        for (final task in project.tasks) {
          expect(task.dueDate, DateTime(2026, 11, 2));
          expect(task.dueMinutes, isNotNull);
        }
      }
      double progress(NewSeedlyProject project) =>
          project.tasks.where((task) => task.done).length /
          project.tasks.length;
      expect(progress(samples[0]), 0.25);
      expect(progress(samples[1]), closeTo(2 / 3, 1e-9));
      // Neither is complete, so both show up in Inicio's "Proyectos".
      expect(
        samples.every((project) => project.tasks.any((t) => !t.done)),
        isTrue,
      );
    });
  });
}
