import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/models/seedly_errors.dart';
import 'package:seedly/models/seedly_project.dart';
import 'package:seedly/screens/seedly_home_screen.dart';
import 'package:seedly/theme/seedly_theme.dart';
import 'package:seedly/widgets/seedly_plant.dart';

import 'support/fake_seedly_auth_repository.dart';
import 'support/fake_seedly_drops_repository.dart';
import 'support/fake_seedly_notification_service.dart';
import 'support/fake_seedly_project_repository.dart';
import 'support/fake_seedly_user_repository.dart';

SeedlyTask task(String id, DateTime dueDate) => SeedlyTask(
  id: id,
  projectId: 'project',
  title: id,
  done: false,
  order: 0,
  dueDate: dueDate,
  dueMinutes: 9 * 60,
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
  testWidgets("Inicio shows today's tasks and the real plant state", (
    tester,
  ) async {
    final projects = FakeSeedlyProjectRepository(
      tasksOn: Stream.value([
        task('Sembrar', DateTime(2026, 11, 2)),
        task('Mañana', DateTime(2026, 11, 3)),
      ]),
      tasksFrom: Stream.value([]),
    );
    final notifications = FakeSeedlyNotificationService();
    final tapped = <String>[];
    await tester.pumpWidget(
      home(
        projects: projects,
        notifications: notifications,
        drops: FakeSeedlyDropsRepository(phase: 3, startingDrops: 24),
        onNotificationTaskTap: tapped.add,
      ),
    );
    await tester.pump();

    expect(find.text('Tareas de hoy'), findsOneWidget);
    expect(find.text('Sembrar'), findsOneWidget);
    expect(find.text('Mañana'), findsNothing);
    expect(find.byType(SeedlyPlant), findsOneWidget);
    expect(notifications.initializeCalls, 1);

    notifications.onTaskReminderTap!.call('Sembrar');
    expect(tapped, ['Sembrar']);
  });

  testWidgets('Inicio explains an empty task day', (tester) async {
    await tester.pumpWidget(
      home(
        projects: FakeSeedlyProjectRepository(
          tasksOn: Stream.value([]),
          tasksFrom: Stream.value([]),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('No tienes tareas para hoy.'), findsOneWidget);
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
