import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/models/seedly_errors.dart';
import 'package:seedly/screens/seedly_home_screen.dart';
import 'package:seedly/screens/seedly_login_screen.dart';
import 'package:seedly/screens/seedly_sign_up_screen.dart';
import 'package:seedly/theme/seedly_theme.dart';
import 'package:seedly/widgets/seedly_alert.dart';
import 'package:seedly/widgets/seedly_input.dart';

import 'support/fake_seedly_auth_repository.dart';
import 'support/fake_seedly_project_repository.dart';
import 'support/fake_seedly_user_repository.dart';
import 'support/keep_plant_still.dart';

void main() {
  keepPlantStill();
  tearDown(hideSeedlyAlert);

  setUpAll(() async {
    await (FontLoader('Plus Jakarta Sans')..addFont(
          rootBundle.load(
            'assets/fonts/plus_jakarta_sans/PlusJakartaSans-Variable.ttf',
          ),
        ))
        .load();
  });

  Future<void> pumpSignUp(
    WidgetTester tester, {
    FakeSeedlyAuthRepository? auth,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: SeedlyTheme.light,
      home: SeedlySignUpScreen(
        auth: auth ?? FakeSeedlyAuthRepository(),
        projects: FakeSeedlyProjectRepository(),
        users: FakeSeedlyUserRepository(),
      ),
    ),
  );

  Future<void> fill(
    WidgetTester tester, {
    String name = 'Ana',
    String email = 'ana@seedly.app',
    String password = 'secreto123',
    String? confirm,
  }) async {
    final inputs = find.byType(SeedlyInput);
    await tester.enterText(inputs.at(0), name);
    await tester.enterText(inputs.at(1), email);
    await tester.enterText(inputs.at(2), password);
    await tester.enterText(inputs.at(3), confirm ?? password);
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Crear cuenta'));
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();
  }

  SeedlyAlert alert(WidgetTester tester) =>
      tester.widget<SeedlyAlert>(find.byType(SeedlyAlert));

  testWidgets('Regístrate opens sign-up and Inicia sesión goes back', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: SeedlyTheme.light,
        home: SeedlyLoginScreen(
          auth: FakeSeedlyAuthRepository(),
          projects: FakeSeedlyProjectRepository(),
          users: FakeSeedlyUserRepository(),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Regístrate'));
    await tester.tap(find.text('Regístrate'));
    await tester.pumpAndSettle();
    expect(find.byType(SeedlySignUpScreen), findsOneWidget);
    expect(find.text('Crea tu cuenta'), findsOneWidget);

    await tester.ensureVisible(find.text('Inicia sesión'));
    await tester.tap(find.text('Inicia sesión'));
    await tester.pumpAndSettle();
    expect(find.byType(SeedlySignUpScreen), findsNothing);
    expect(find.byType(SeedlyLoginScreen), findsOneWidget);
  });

  testWidgets('an empty form lists every field in one alert', (tester) async {
    final auth = FakeSeedlyAuthRepository();
    await pumpSignUp(tester, auth: auth);

    await submit(tester);

    expect(alert(tester).style, SeedlyAlertStyle.danger);
    expect(alert(tester).title, 'Campos incompletos');
    expect(
      alert(tester).message,
      'Ingresa tu nombre\n'
      'Ingresa un correo válido\n'
      'La contraseña debe tener al menos 8 caracteres\n'
      'Confirma tu contraseña',
    );
    expect(auth.signUpAttempts, isEmpty);
  });

  testWidgets('a short password is rejected', (tester) async {
    final auth = FakeSeedlyAuthRepository();
    await pumpSignUp(tester, auth: auth);
    await fill(tester, password: 'corta');

    await submit(tester);

    expect(
      alert(tester).message,
      'La contraseña debe tener al menos 8 caracteres',
    );
    expect(auth.signUpAttempts, isEmpty);
  });

  testWidgets('the confirmation must match the password', (tester) async {
    final auth = FakeSeedlyAuthRepository();
    await pumpSignUp(tester, auth: auth);
    await fill(tester, confirm: 'secreto124');

    await submit(tester);

    expect(alert(tester).message, 'Las contraseñas no coinciden');
    expect(auth.signUpAttempts, isEmpty);
  });

  testWidgets('a valid form creates the account and opens the home', (
    tester,
  ) async {
    final auth = FakeSeedlyAuthRepository();
    await pumpSignUp(tester, auth: auth);
    await fill(tester, name: '  Ana ', email: ' ana@seedly.app ');

    await submit(tester);

    expect(auth.signUpAttempts.single, (
      name: 'Ana',
      email: 'ana@seedly.app',
      password: 'secreto123',
    ));
    expect(find.byType(SeedlyHomeScreen), findsOneWidget);
    expect(find.byType(SeedlySignUpScreen), findsNothing);
  });

  testWidgets('a rejected sign-up shows the auth message and stays', (
    tester,
  ) async {
    await pumpSignUp(
      tester,
      auth: FakeSeedlyAuthRepository(
        error: const SeedlyAuthException(SeedlyAuthError.emailInUse),
      ),
    );
    await fill(tester);

    await submit(tester);

    expect(alert(tester).style, SeedlyAlertStyle.danger);
    expect(alert(tester).title, 'No se pudo crear la cuenta');
    expect(alert(tester).message, 'Este correo ya tiene una cuenta');
    expect(find.byType(SeedlySignUpScreen), findsOneWidget);
  });

  testWidgets('Google is the only social option and signs in', (tester) async {
    final auth = FakeSeedlyAuthRepository();
    await pumpSignUp(tester, auth: auth);
    expect(find.text('Apple'), findsNothing);

    await tester.ensureVisible(find.text('Google'));
    await tester.tap(find.text('Google'));
    await tester.pumpAndSettle();

    expect(auth.googleAttempts, 1);
    expect(find.byType(SeedlyHomeScreen), findsOneWidget);
  });

  testWidgets('both passwords can be shown', (tester) async {
    await pumpSignUp(tester);
    expect(find.byTooltip('Mostrar contraseña'), findsNWidgets(2));
  });

  testWidgets('going back to login hides an open alert', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: SeedlyTheme.light,
        home: SeedlyLoginScreen(
          auth: FakeSeedlyAuthRepository(),
          projects: FakeSeedlyProjectRepository(),
          users: FakeSeedlyUserRepository(),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Regístrate'));
    await tester.tap(find.text('Regístrate'));
    await tester.pumpAndSettle();
    await submit(tester);
    expect(find.byType(SeedlyAlert), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(SeedlyLoginScreen), findsOneWidget);
    expect(find.byType(SeedlyAlert), findsNothing);
  });

  testWidgets('sign-up can be scrolled on a compact phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpSignUp(tester);
    await tester.ensureVisible(find.text('Inicia sesión'));

    expect(find.text('Inicia sesión'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
