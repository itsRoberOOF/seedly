import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/models/seedly_errors.dart';
import 'package:seedly/screens/seedly_home_screen.dart';
import 'package:seedly/screens/seedly_login_screen.dart';
import 'package:seedly/theme/seedly_theme.dart';
import 'package:seedly/widgets/seedly_alert.dart';

import 'support/fake_seedly_auth_repository.dart';
import 'support/fake_seedly_project_repository.dart';
import 'support/fake_seedly_user_repository.dart';

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

void main() {
  tearDown(hideSeedlyAlert);

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

    await tester.tap(find.text('Proyectos'));
    await tester.pump();
    expect(find.text('Cerrar sesión'), findsNothing);

    await tester.tap(find.text('Mi perfil'));
    await tester.pump();
    expect(find.text('Cerrar sesión'), findsOneWidget);
  });

  testWidgets('signing out returns to the login screen', (tester) async {
    final auth = await _openProfile(tester);
    await tester.tap(find.text('Cerrar sesión'));
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
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    final alert = tester.widget<SeedlyAlert>(find.byType(SeedlyAlert));
    expect(alert.title, 'No se pudo cerrar sesión');
    expect(alert.message, 'Sin conexión. Revisa tu internet.');
    expect(auth.isSignedIn, isTrue);
    expect(find.byType(SeedlyHomeScreen), findsOneWidget);
  });
}
