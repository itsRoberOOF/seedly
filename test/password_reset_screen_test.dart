import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/models/seedly_errors.dart';
import 'package:seedly/screens/seedly_login_screen.dart';
import 'package:seedly/screens/seedly_password_reset_screen.dart';
import 'package:seedly/theme/seedly_theme.dart';
import 'package:seedly/widgets/seedly_alert.dart';
import 'package:seedly/widgets/seedly_input.dart';

import 'support/fake_seedly_auth_repository.dart';
import 'support/fake_seedly_project_repository.dart';

void main() {
  tearDown(hideSeedlyAlert);

  setUpAll(() async {
    await (FontLoader('Plus Jakarta Sans')..addFont(
          rootBundle.load(
            'assets/fonts/plus_jakarta_sans/PlusJakartaSans-Variable.ttf',
          ),
        ))
        .load();
  });

  /// Opens the recovery screen from the login, after typing [loginEmail].
  Future<void> openFromLogin(
    WidgetTester tester,
    FakeSeedlyAuthRepository auth, {
    String loginEmail = '',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: SeedlyTheme.light,
        home: SeedlyLoginScreen(
          auth: auth,
          projects: FakeSeedlyProjectRepository(),
        ),
      ),
    );
    await tester.enterText(find.byType(SeedlyInput).first, loginEmail);
    await tester.tap(find.text('¿Olvidaste tu contraseña?'));
    await tester.pumpAndSettle();
  }

  Future<void> send(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Enviar enlace'));
    await tester.tap(find.text('Enviar enlace'));
    await tester.pumpAndSettle();
  }

  SeedlyAlert alert(WidgetTester tester) =>
      tester.widget<SeedlyAlert>(find.byType(SeedlyAlert));

  String typedEmail(WidgetTester tester) => tester
      .widget<EditableText>(
        find.descendant(
          of: find.byType(SeedlyInput),
          matching: find.byType(EditableText),
        ),
      )
      .controller
      .text;

  testWidgets('the login link opens it with the email already typed', (
    tester,
  ) async {
    await openFromLogin(
      tester,
      FakeSeedlyAuthRepository(),
      loginEmail: ' ana@seedly.app ',
    );

    expect(find.byType(SeedlyPasswordResetScreen), findsOneWidget);
    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
    expect(typedEmail(tester), 'ana@seedly.app');
  });

  testWidgets('a valid email sends the link and returns to the login', (
    tester,
  ) async {
    final auth = FakeSeedlyAuthRepository();
    await openFromLogin(tester, auth, loginEmail: 'ana@seedly.app');

    await send(tester);

    expect(auth.resetRequests, ['ana@seedly.app']);
    expect(find.byType(SeedlyPasswordResetScreen), findsNothing);
    expect(find.byType(SeedlyLoginScreen), findsOneWidget);
    expect(alert(tester).style, SeedlyAlertStyle.success);
    expect(alert(tester).title, 'Revisa tu correo');
    expect(
      alert(tester).message,
      'Si hay una cuenta con ese correo, te enviamos un enlace para '
      'cambiar tu contraseña.',
    );
  });

  testWidgets('an invalid email never reaches the auth service', (
    tester,
  ) async {
    final auth = FakeSeedlyAuthRepository();
    await openFromLogin(tester, auth, loginEmail: 'ana@');

    await send(tester);

    expect(alert(tester).style, SeedlyAlertStyle.danger);
    expect(alert(tester).title, 'Campos incompletos');
    expect(alert(tester).message, 'Ingresa un correo válido');
    expect(auth.resetRequests, isEmpty);
    expect(find.byType(SeedlyPasswordResetScreen), findsOneWidget);
  });

  testWidgets('a failed send shows why and stays to retry', (tester) async {
    final auth = FakeSeedlyAuthRepository(
      error: const SeedlyAuthException(SeedlyAuthError.network),
    );
    await openFromLogin(tester, auth, loginEmail: 'ana@seedly.app');

    await send(tester);

    expect(alert(tester).style, SeedlyAlertStyle.danger);
    expect(alert(tester).title, 'No se pudo enviar el enlace');
    expect(alert(tester).message, 'Sin conexión. Revisa tu internet.');
    expect(find.byType(SeedlyPasswordResetScreen), findsOneWidget);
  });

  testWidgets('the back arrow returns to the login without an alert', (
    tester,
  ) async {
    await openFromLogin(tester, FakeSeedlyAuthRepository());

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    expect(find.byType(SeedlyLoginScreen), findsOneWidget);
    expect(find.byType(SeedlyAlert), findsNothing);
  });

  testWidgets('leaving hides an open alert', (tester) async {
    await openFromLogin(tester, FakeSeedlyAuthRepository(), loginEmail: 'ana@');
    await send(tester);
    expect(find.byType(SeedlyAlert), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(SeedlyLoginScreen), findsOneWidget);
    expect(find.byType(SeedlyAlert), findsNothing);
  });

  testWidgets('an alert leaves the back arrow free to tap', (tester) async {
    await openFromLogin(tester, FakeSeedlyAuthRepository(), loginEmail: 'ana@');
    await send(tester);
    // Sending scrolled down to the button; the arrow comes back on scroll.
    await tester.ensureVisible(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    expect(find.byType(SeedlyAlert), findsOneWidget);
    expect(
      tester.getRect(find.byType(SeedlyAlert)).top,
      greaterThan(tester.getRect(find.byTooltip('Volver')).bottom),
    );
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    expect(find.byType(SeedlyLoginScreen), findsOneWidget);
    expect(find.byType(SeedlyAlert), findsNothing);
  });

  testWidgets('it can be scrolled on a compact phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: SeedlyTheme.light,
        home: SeedlyPasswordResetScreen(auth: FakeSeedlyAuthRepository()),
      ),
    );
    await tester.ensureVisible(find.text('Enviar enlace'));

    expect(find.text('Enviar enlace'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
