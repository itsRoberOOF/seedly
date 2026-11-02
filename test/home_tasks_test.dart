import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/models/seedly_errors.dart';
import 'package:seedly/models/seedly_project.dart';
import 'package:seedly/screens/seedly_home_screen.dart';
import 'package:seedly/theme/seedly_theme.dart';
import 'package:seedly/widgets/seedly_empty_card.dart';
import 'package:seedly/widgets/seedly_plant.dart';

import 'support/fake_seedly_auth_repository.dart';
import 'support/fake_seedly_drops_repository.dart';
import 'support/fake_seedly_notification_service.dart';
import 'support/fake_seedly_project_repository.dart';
import 'support/fake_seedly_user_repository.dart';

SeedlyTask task(String id, DateTime dueDate, {bool done = false}) => SeedlyTask(
  id: id,
  projectId: 'project',
  title: id,
  done: done,
  order: 0,
  dueDate: dueDate,
  dueMinutes: 9 * 60,
);

const huerto = SeedlyProject(
  id: 'project',
  name: 'Huerto',
  kind: SeedlyProjectKind.full,
  icon: SeedlyProjectIcon.hogar,
  taskCount: 4,
  doneCount: 1,
);

Widget home({
  required FakeSeedlyProjectRepository projects,
  FakeSeedlyNotificationService? notifications,
  FakeSeedlyAuthRepository? auth,
  FakeSeedlyDropsRepository? drops,
  void Function(String taskId)? onNotificationTaskTap,
}) => MaterialApp(
  theme: SeedlyTheme.light,
  home: SeedlyHomeScreen(
    auth: auth ?? FakeSeedlyAuthRepository(isSignedIn: true),
    projects: projects,
    users: FakeSeedlyUserRepository(),
    drops: drops,
    notifications: notifications,
    onNotificationTaskTap: onNotificationTaskTap,
  ),
);

void main() {
  testWidgets('Inicio greets the person and shows the real plant state', (
    tester,
  ) async {
    final notifications = FakeSeedlyNotificationService();
    final tapped = <String>[];
    await tester.pumpWidget(
      home(
        projects: FakeSeedlyProjectRepository(),
        notifications: notifications,
        drops: FakeSeedlyDropsRepository(phase: 3, startingDrops: 24),
        onNotificationTaskTap: tapped.add,
      ),
    );
    await tester.pump();

    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
    expect(find.bySemanticsLabel('24 gotas'), findsOneWidget);
    expect(find.byType(SeedlyPlant), findsOneWidget);
    expect(tester.widget<SeedlyPlant>(find.byType(SeedlyPlant)).phase, 3);
    expect(find.text('Regar por 25 minutos'), findsOneWidget);
    expect(notifications.initializeCalls, 1);

    notifications.onTaskReminderTap!.call('Sembrar');
    expect(tapped, ['Sembrar']);
  });

  testWidgets("Inicio focuses on today's first pending task", (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(
      home(
        projects: FakeSeedlyProjectRepository(
          projects: Stream.value([huerto]),
          tasksOn: Stream.value([
            task('Hecha', DateTime(2026, 11, 2), done: true),
            task('Sembrar', DateTime(2026, 11, 2)),
            task('Regar', DateTime(2026, 11, 2)),
          ]),
        ),
        onNotificationTaskTap: tapped.add,
      ),
    );
    await tester.pump();

    expect(find.text('ENFOQUE DE HOY'), findsOneWidget);
    expect(find.text('Sembrar'), findsOneWidget);
    expect(find.text('Hecha'), findsNothing);
    expect(find.text('Regar'), findsNothing);

    await tester.ensureVisible(find.text('Sembrar'));
    await tester.tap(find.text('Sembrar'));
    expect(tapped, ['Sembrar']);
  });

  testWidgets('Inicio lists the tasks to attend with when they are due', (
    tester,
  ) async {
    final today = DateTime.now();
    await tester.pumpWidget(
      home(
        projects: FakeSeedlyProjectRepository(
          tasksFrom: Stream.value([
            task('Sembrar', today),
            task('Hecha', today, done: true),
            task('Podar', today.add(const Duration(days: 1))),
          ]),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Tareas por atender'), findsOneWidget);
    expect(find.text('Sembrar'), findsOneWidget);
    expect(find.text('Hoy • 9:00 AM'), findsOneWidget);
    expect(find.text('Podar'), findsOneWidget);
    expect(find.text('Mañana • 9:00 AM'), findsOneWidget);
    expect(find.text('Hecha'), findsNothing);
  });

  testWidgets('Inicio shows the projects in progress with their progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      home(
        projects: FakeSeedlyProjectRepository(
          projects: Stream.value([
            huerto,
            const SeedlyProject(
              id: 'listo',
              name: 'Terminado',
              kind: SeedlyProjectKind.express,
              icon: SeedlyProjectIcon.planta,
              taskCount: 3,
              doneCount: 3,
            ),
            const SeedlyProject(
              id: 'solo',
              name: 'Una tarea',
              kind: SeedlyProjectKind.express,
              icon: SeedlyProjectIcon.planta,
              taskCount: 2,
              doneCount: 1,
            ),
          ]),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Huerto'), findsOneWidget);
    expect(find.text('3 tareas restantes'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
    expect(find.text('Una tarea'), findsOneWidget);
    expect(find.text('1 tarea restante'), findsOneWidget);
    expect(find.text('Terminado'), findsNothing);
  });

  testWidgets('Inicio explains empty and failed lists', (tester) async {
    await tester.pumpWidget(
      home(
        projects: FakeSeedlyProjectRepository(
          projects: Stream.value([]),
          tasksOn: Stream.value([]),
          tasksFrom: Stream.error('offline'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('No se pudieron cargar tus tareas.'), findsOneWidget);
    expect(find.text('Sin proyectos'), findsOneWidget);
    expect(find.text('Crea tu primer proyecto'), findsOneWidget);
  });

  testWidgets('Inicio invites you to add a task when none is scheduled', (
    tester,
  ) async {
    await tester.pumpWidget(
      home(projects: FakeSeedlyProjectRepository(tasksFrom: Stream.value([]))),
    );
    await tester.pump();

    expect(find.text('Sin pendientes'), findsOneWidget);
    expect(find.text('¿Tienes algo en mente? Crea una tarea'), findsOneWidget);
    expect(find.text('¡Todo al día!'), findsNothing);
  });

  testWidgets('Inicio congratulates you when every task is done', (
    tester,
  ) async {
    final today = DateTime.now();
    await tester.pumpWidget(
      home(
        projects: FakeSeedlyProjectRepository(
          tasksFrom: Stream.value([
            task('Sembrar', today, done: true),
            task('Regar', today, done: true),
          ]),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('¡Todo al día!'), findsOneWidget);
    expect(find.text('Buen trabajo, ¿algo más en mente?'), findsOneWidget);
    expect(find.text('Sin pendientes'), findsNothing);
    expect(find.text('Sembrar'), findsNothing);
  });

  testWidgets('the empty tasks card opens the add menu', (tester) async {
    await tester.pumpWidget(
      home(projects: FakeSeedlyProjectRepository(tasksFrom: Stream.value([]))),
    );
    await tester.pump();

    await tester.ensureVisible(find.text('Sin pendientes'));
    await tester.tap(find.text('Sin pendientes'));
    // The plant keeps swaying, so the modal's slide cannot be settled.
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Proyecto Express'), findsOneWidget);
    expect(find.text('Crear tarea'), findsOneWidget);
  });

  testWidgets('the focus slot invites you to pick one when today is free', (
    tester,
  ) async {
    await tester.pumpWidget(
      home(projects: FakeSeedlyProjectRepository(tasksOn: Stream.value([]))),
    );
    await tester.pump();

    expect(find.text('ENFOQUE DE HOY'), findsOneWidget);
    expect(find.text('¿Qué toca hoy?'), findsOneWidget);
    expect(find.text('¡Hoy quedó al día!'), findsNothing);
  });

  testWidgets('the focus slot congratulates you when today is all done', (
    tester,
  ) async {
    await tester.pumpWidget(
      home(
        projects: FakeSeedlyProjectRepository(
          tasksOn: Stream.value([
            task('Sembrar', DateTime(2026, 11, 2), done: true),
          ]),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('ENFOQUE DE HOY'), findsOneWidget);
    expect(find.text('¡Hoy quedó al día!'), findsOneWidget);
    expect(find.text('¿Qué toca hoy?'), findsNothing);
    expect(find.text('Sembrar'), findsNothing);
  });

  testWidgets('the empty focus card opens the add menu', (tester) async {
    await tester.pumpWidget(
      home(projects: FakeSeedlyProjectRepository(tasksOn: Stream.value([]))),
    );
    await tester.pump();

    await tester.tap(find.text('¿Qué toca hoy?'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Proyecto Express'), findsOneWidget);
  });

  testWidgets('the focus slot shows nothing while today loads or fails', (
    tester,
  ) async {
    await tester.pumpWidget(home(projects: FakeSeedlyProjectRepository()));
    await tester.pump();
    expect(find.text('ENFOQUE DE HOY'), findsNothing);

    await tester.pumpWidget(
      home(
        projects: FakeSeedlyProjectRepository(tasksOn: Stream.error('offline')),
      ),
    );
    await tester.pump();
    expect(find.text('ENFOQUE DE HOY'), findsNothing);
  });

  testWidgets('Inicio congratulates you when every project is finished', (
    tester,
  ) async {
    await tester.pumpWidget(
      home(
        projects: FakeSeedlyProjectRepository(
          projects: Stream.value([
            const SeedlyProject(
              id: 'listo',
              name: 'Terminado',
              kind: SeedlyProjectKind.express,
              icon: SeedlyProjectIcon.planta,
              taskCount: 3,
              doneCount: 3,
            ),
          ]),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('¡Proyectos al día!'), findsOneWidget);
    expect(find.text('Buen trabajo, ¿empezamos otro?'), findsOneWidget);
    expect(find.text('Sin proyectos'), findsNothing);
    expect(find.text('Terminado'), findsNothing);
  });

  testWidgets('the empty projects card opens the add menu', (tester) async {
    await tester.pumpWidget(
      home(projects: FakeSeedlyProjectRepository(projects: Stream.value([]))),
    );
    await tester.pump();

    await tester.ensureVisible(find.text('Sin proyectos'));
    await tester.tap(find.text('Sin proyectos'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Proyecto completo'), findsOneWidget);
  });

  testWidgets('every empty-card text fits a 360px phone on one line', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await (FontLoader('Plus Jakarta Sans')..addFont(
          rootBundle.load(
            'assets/fonts/plus_jakarta_sans/PlusJakartaSans-Variable.ttf',
          ),
        ))
        .load();

    Future<void> fits(FakeSeedlyProjectRepository projects) async {
      await tester.pumpWidget(home(projects: projects));
      await tester.pump();
      final texts = find.descendant(
        of: find.byType(SeedlyEmptyCard),
        matching: find.byType(Text),
      );
      expect(texts, findsWidgets);
      for (final element in texts.evaluate()) {
        final paragraph = element.findRenderObject()! as RenderParagraph;
        expect(
          paragraph.didExceedMaxLines,
          isFalse,
          reason: '"${paragraph.text.toPlainText()}" is cut at 360px',
        );
      }
    }

    await fits(
      FakeSeedlyProjectRepository(
        projects: Stream.value([]),
        tasksOn: Stream.value([]),
        tasksFrom: Stream.value([]),
      ),
    );
    final done = [task('Hecha', DateTime.now(), done: true)];
    await fits(
      FakeSeedlyProjectRepository(
        projects: Stream.value([
          const SeedlyProject(
            id: 'listo',
            name: 'Terminado',
            kind: SeedlyProjectKind.express,
            icon: SeedlyProjectIcon.planta,
            taskCount: 1,
            doneCount: 1,
          ),
        ]),
        tasksOn: Stream.value(done),
        tasksFrom: Stream.value(done),
      ),
    );
  });

  testWidgets('Inicio says so while the lists load', (tester) async {
    await tester.pumpWidget(home(projects: FakeSeedlyProjectRepository()));

    expect(find.text('Cargando tareas…'), findsOneWidget);
    expect(find.text('Cargando proyectos…'), findsOneWidget);
  });

  testWidgets('the shortcuts take the person to Riego and Proyectos', (
    tester,
  ) async {
    await tester.pumpWidget(home(projects: FakeSeedlyProjectRepository()));
    await tester.pump();

    await tester.ensureVisible(find.text('Regar por 25 minutos'));
    await tester.tap(find.text('Regar por 25 minutos'));
    await tester.pump();
    expect(find.byType(SeedlyPlant), findsNothing);
    expect(find.text('Regar por 25 minutos'), findsNothing);

    await tester.tap(find.text('Inicio'));
    await tester.pump();
    await tester.ensureVisible(find.text('Ir a proyectos'));
    await tester.tap(find.text('Ir a proyectos'));
    await tester.pump();
    expect(find.text('Ir a proyectos'), findsNothing);
  });

  testWidgets('going back to Inicio listens to its lists again', (
    tester,
  ) async {
    await tester.pumpWidget(
      home(
        projects: FakeSeedlyProjectRepository(
          projects: Stream.value([huerto]),
          tasksOn: Stream.value([task('Sembrar', DateTime(2026, 11, 2))]),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Huerto'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Mi perfil'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Inicio'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Huerto'), findsOneWidget);
    expect(find.text('Sembrar'), findsOneWidget);
  });

  testWidgets('successful sign-out cancels task reminders', (tester) async {
    final notifications = FakeSeedlyNotificationService();
    await tester.pumpWidget(
      home(
        projects: FakeSeedlyProjectRepository(),
        notifications: notifications,
      ),
    );
    await tester.tap(find.bySemanticsLabel('Mi perfil'));
    await tester.pump();
    await tester.ensureVisible(find.text('Cerrar sesión'));
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(notifications.cancelAllCalls, 1);
  });

  testWidgets('failed sign-out preserves task reminders', (tester) async {
    final notifications = FakeSeedlyNotificationService();
    final auth = FakeSeedlyAuthRepository(isSignedIn: true)
      ..signOutError = const SeedlyAuthException(SeedlyAuthError.signOutFailed);
    await tester.pumpWidget(
      home(
        projects: FakeSeedlyProjectRepository(),
        notifications: notifications,
        auth: auth,
      ),
    );
    await tester.tap(find.bySemanticsLabel('Mi perfil'));
    await tester.pump();
    await tester.ensureVisible(find.text('Cerrar sesión'));
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(notifications.cancelAllCalls, 0);
    expect(find.text('No se pudo cerrar sesión'), findsOneWidget);
  });
}
