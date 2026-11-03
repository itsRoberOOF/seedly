import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/models/seedly_errors.dart';
import 'package:seedly/models/seedly_project.dart';
import 'package:seedly/screens/seedly_home_screen.dart';
import 'package:seedly/screens/seedly_inicio_view.dart';
import 'package:seedly/screens/seedly_login_screen.dart';
import 'package:seedly/theme/seedly_theme.dart';
import 'package:seedly/widgets/seedly_alert.dart';
import 'package:seedly/widgets/seedly_menu.dart';
import 'package:seedly/widgets/seedly_plant_blob.dart';
import 'package:seedly/widgets/seedly_plant.dart';

import 'support/fake_seedly_auth_repository.dart';
import 'support/fake_seedly_project_repository.dart';
import 'support/fake_seedly_user_repository.dart';
import 'support/sign_out.dart';

Future<FakeSeedlyAuthRepository> _openProfile(
  WidgetTester tester, {
  SeedlyAuthException? signOutError,
}) async {
  // A phone-sized view, so the whole profile is on screen.
  tester.view.physicalSize = const Size(440, 956);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final auth = FakeSeedlyAuthRepository(isSignedIn: true)
    ..signOutError = signOutError;
  await tester.pumpWidget(
    MaterialApp(
      theme: SeedlyTheme.light,
      home: SeedlyHomeScreen(
        auth: auth,
        projects: FakeSeedlyProjectRepository(),
        users: FakeSeedlyUserRepository(),
      ),
    ),
  );
  await tester.tap(find.text('Mi perfil'));
  await tester.pump();
  return auth;
}

/// A menu label; Inicio's own "Proyectos" title shares the text.
Finder _tab(String label) =>
    find.descendant(of: find.byType(SeedlyMenu), matching: find.text(label));

Widget _home() => MaterialApp(
  theme: SeedlyTheme.light,
  home: SeedlyHomeScreen(
    auth: FakeSeedlyAuthRepository(isSignedIn: true),
    projects: FakeSeedlyProjectRepository(),
    users: FakeSeedlyUserRepository(),
  ),
);

void main() {
  tearDown(hideSeedlyAlert);

  group('Inicio', () {
    testWidgets('opens first and shows the plant at its first phase', (
      tester,
    ) async {
      await tester.pumpWidget(_home());

      final plant = tester.widget<SeedlyPlant>(find.byType(SeedlyPlant));
      expect(plant.phase, 1);
      expect(plant.watering, isFalse);
      expect(
        find.bySemanticsLabel('Planta en fase 1: Semilla'),
        findsOneWidget,
      );
      expect(tester.hasRunningAnimations, isTrue);
    });

    testWidgets('puts the plant where Figma does, scaled down', (tester) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_home());

      // Figma: 48 top padding, 56 header, 24 gap, 14 into the Planta frame;
      // the mascot is 303 tall and centred. The frame is drawn at
      // SeedlyInicioView.plantScale, from the same top-centre point.
      const scale = SeedlyInicioView.plantScale;
      final rect = tester.getRect(find.byType(SeedlyPlant));
      expect(rect.top, closeTo(48 + 56 + 24 + 14 * scale, 0.01));
      expect(rect.height, closeTo(303 * scale, 0.01));
      expect(rect.center.dx, 220);
    });

    testWidgets('without a focus task the button keeps a single 24px gap', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_home());
      await tester.pump();

      final plant = tester.getRect(find.byType(SeedlyPlantBlob));
      final button = tester.getRect(find.text('Regar por 25 minutos'));
      // The button's text is centred in its 60px, so measure from the card.
      final card = tester.getRect(
        find.ancestor(
          of: find.text('Regar por 25 minutos'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(card.top - plant.bottom, 24);
      expect(card.height, 60);
      expect(button.center.dy, card.center.dy);
    });

    testWidgets('the first project fits above the menu on a phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: SeedlyTheme.light,
          home: SeedlyHomeScreen(
            auth: FakeSeedlyAuthRepository(isSignedIn: true),
            users: FakeSeedlyUserRepository(),
            projects: FakeSeedlyProjectRepository(
              projects: Stream.value([
                const SeedlyProject(
                  id: 'huerto',
                  name: 'Huerto',
                  kind: SeedlyProjectKind.full,
                  icon: SeedlyProjectIcon.hogar,
                  taskCount: 4,
                  doneCount: 1,
                ),
              ]),
              tasksOn: Stream.value([
                SeedlyTask(
                  id: 'sembrar',
                  projectId: 'huerto',
                  title: 'Sembrar',
                  done: false,
                  order: 0,
                  dueDate: DateTime.now(),
                ),
              ]),
            ),
          ),
        ),
      );
      await tester.pump();

      final card = tester.getRect(find.text('Huerto'));
      final menu = tester.getRect(find.byType(SeedlyMenu));
      expect(card.bottom, lessThan(menu.top));
    });

    testWidgets('only Inicio shows the plant', (tester) async {
      await tester.pumpWidget(_home());

      for (final tab in ['Proyectos', 'Riego', 'Mi perfil']) {
        await tester.tap(_tab(tab));
        await tester.pump();
        expect(find.byType(SeedlyPlant), findsNothing, reason: tab);
      }

      await tester.tap(_tab('Inicio'));
      await tester.pump();
      expect(find.byType(SeedlyPlant), findsOneWidget);
    });

    testWidgets('with reduce motion the plant stands still', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(_home());

      expect(find.byType(SeedlyPlant), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  testWidgets('only Mi perfil shows the sign-out button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: SeedlyTheme.light,
        home: SeedlyHomeScreen(
          auth: FakeSeedlyAuthRepository(isSignedIn: true),
          projects: FakeSeedlyProjectRepository(),
          users: FakeSeedlyUserRepository(),
        ),
      ),
    );
    expect(find.text('Cerrar sesión'), findsNothing);

    await tester.tap(_tab('Proyectos'));
    await tester.pump();
    expect(find.text('Cerrar sesión'), findsNothing);

    await tester.tap(find.text('Mi perfil'));
    await tester.pump();
    expect(find.text('Cerrar sesión'), findsOneWidget);
  });

  testWidgets('signing out returns to the login screen', (tester) async {
    final auth = await _openProfile(tester);
    await tapSignOut(tester);
    await tester.pumpAndSettle();

    expect(auth.signOutCalls, 1);
    expect(auth.isSignedIn, isFalse);
    expect(find.byType(SeedlyLoginScreen), findsOneWidget);
    expect(find.byType(SeedlyHomeScreen), findsNothing);
  });

  testWidgets('a failed sign-out shows an alert and keeps the session', (
    tester,
  ) async {
    final auth = await _openProfile(
      tester,
      signOutError: const SeedlyAuthException(SeedlyAuthError.network),
    );
    await tapSignOut(tester);
    await tester.pumpAndSettle();

    final alert = tester.widget<SeedlyAlert>(find.byType(SeedlyAlert));
    expect(alert.title, 'No se pudo cerrar sesión');
    expect(alert.message, 'Sin conexión. Revisa tu internet.');
    expect(auth.isSignedIn, isTrue);
    expect(find.byType(SeedlyHomeScreen), findsOneWidget);
  });
}
