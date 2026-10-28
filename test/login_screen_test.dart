import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/models/seedly_errors.dart';
import 'package:seedly/screens/seedly_home_screen.dart';
import 'package:seedly/screens/seedly_loading_screen.dart';
import 'package:seedly/screens/seedly_login_screen.dart';
import 'package:seedly/theme/seedly_theme.dart';
import 'package:seedly/widgets/seedly_alert.dart';
import 'package:seedly/widgets/seedly_button.dart';
import 'package:seedly/widgets/seedly_input.dart';

import 'support/fake_seedly_auth_repository.dart';
import 'support/fake_seedly_project_repository.dart';
import 'support/fake_seedly_user_repository.dart';

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
  testWidgets('completed loading replaces splash with login', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: SeedlyTheme.light,
        home: SeedlyLoadingScreen(
          auth: FakeSeedlyAuthRepository(),
          projects: FakeSeedlyProjectRepository(),
          users: FakeSeedlyUserRepository(),
          startAfter: Future<void>.value(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.byType(SeedlyLoginScreen), findsOneWidget);
    expect(find.text('CARGANDO'), findsNothing);
    expect(find.text('Bienvenido.'), findsOneWidget);
  });

  testWidgets('login fields validate and password visibility toggles', (
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

    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SeedlyAlert>(find.byType(SeedlyAlert)).message,
      'Ingresa un correo válido\nIngresa tu contraseña',
    );

    final inputs = find.byType(SeedlyInput);
    await tester.enterText(inputs.at(0), 'hola@seedly.com');
    await tester.enterText(inputs.at(1), 'secreto123');
    final password = find.descendant(
      of: inputs.at(1),
      matching: find.byType(TextFormField),
    );
    expect(
      tester
          .widget<EditableText>(
            find.descendant(of: password, matching: find.byType(EditableText)),
          )
          .obscureText,
      isTrue,
    );
    await tester.tap(find.byTooltip('Mostrar contraseña'));
    await tester.pump();
    expect(
      tester
          .widget<EditableText>(
            find.descendant(of: password, matching: find.byType(EditableText)),
          )
          .obscureText,
      isFalse,
    );
  });

  testWidgets('Google is full width and signs in through the auth service', (
    tester,
  ) async {
    final auth = FakeSeedlyAuthRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: SeedlyTheme.light,
        home: SeedlyLoginScreen(
          auth: auth,
          projects: FakeSeedlyProjectRepository(),
          users: FakeSeedlyUserRepository(),
        ),
      ),
    );
    expect(find.byType(SeedlyButton), findsNWidgets(4));
    expect(find.text('Apple'), findsNothing);
    final google = tester.getRect(
      find.ancestor(
        of: find.text('Google'),
        matching: find.byType(OutlinedButton),
      ),
    );
    final signIn = tester.getRect(
      find.ancestor(
        of: find.text('Iniciar sesión'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(google.width, signIn.width);
    await tester.ensureVisible(find.text('Google'));
    await tester.tap(find.text('Google'));
    await tester.pumpAndSettle();
    expect(auth.googleAttempts, 1);
    expect(find.byType(SeedlyHomeScreen), findsOneWidget);
    expect(find.byType(SeedlyLoginScreen), findsNothing);
  });

  testWidgets('closing the Google picker stays on login silently', (
    tester,
  ) async {
    final auth = FakeSeedlyAuthRepository(googleResult: false);
    await tester.pumpWidget(
      MaterialApp(
        theme: SeedlyTheme.light,
        home: SeedlyLoginScreen(
          auth: auth,
          projects: FakeSeedlyProjectRepository(),
          users: FakeSeedlyUserRepository(),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Google'));
    await tester.tap(find.text('Google'));
    await tester.pumpAndSettle();

    expect(find.byType(SeedlyLoginScreen), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('valid email credentials open the home', (tester) async {
    final auth = FakeSeedlyAuthRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: SeedlyTheme.light,
        home: SeedlyLoginScreen(
          auth: auth,
          projects: FakeSeedlyProjectRepository(),
          users: FakeSeedlyUserRepository(),
        ),
      ),
    );
    final inputs = find.byType(SeedlyInput);
    await tester.enterText(inputs.at(0), '  hola@seedly.com ');
    await tester.enterText(inputs.at(1), 'secreto123');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(auth.emailAttempts.single, (
      email: 'hola@seedly.com',
      password: 'secreto123',
    ));
    expect(find.byType(SeedlyHomeScreen), findsOneWidget);
  });

  testWidgets('rejected credentials show the auth message and stay', (
    tester,
  ) async {
    final auth = FakeSeedlyAuthRepository(
      error: const SeedlyAuthException(SeedlyAuthError.invalidCredentials),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: SeedlyTheme.light,
        home: SeedlyLoginScreen(
          auth: auth,
          projects: FakeSeedlyProjectRepository(),
          users: FakeSeedlyUserRepository(),
        ),
      ),
    );
    final inputs = find.byType(SeedlyInput);
    await tester.enterText(inputs.at(0), 'hola@seedly.com');
    await tester.enterText(inputs.at(1), 'mala');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    final alert = tester.widget<SeedlyAlert>(find.byType(SeedlyAlert));
    expect(alert.style, SeedlyAlertStyle.danger);
    expect(alert.title, 'No se pudo iniciar sesión');
    expect(alert.message, 'Correo o contraseña incorrectos');
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byType(SeedlyLoginScreen), findsOneWidget);
  });

  testWidgets('a new sign-in attempt clears the previous error alert', (
    tester,
  ) async {
    final auth = FakeSeedlyAuthRepository(
      error: const SeedlyAuthException(SeedlyAuthError.invalidCredentials),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: SeedlyTheme.light,
        home: SeedlyLoginScreen(
          auth: auth,
          projects: FakeSeedlyProjectRepository(),
          users: FakeSeedlyUserRepository(),
        ),
      ),
    );
    final inputs = find.byType(SeedlyInput);
    await tester.enterText(inputs.at(0), 'hola@seedly.com');
    await tester.enterText(inputs.at(1), 'mala');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.byType(SeedlyAlert), findsOneWidget);

    auth.error = null;
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.byType(SeedlyAlert), findsNothing);
    expect(find.byType(SeedlyHomeScreen), findsOneWidget);
  });

  testWidgets('validation errors show in a danger alert, not under fields', (
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
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    final alert = tester.widget<SeedlyAlert>(find.byType(SeedlyAlert));
    expect(alert.style, SeedlyAlertStyle.danger);
    expect(alert.title, 'Campos incompletos');
    expect(
      find.descendant(
        of: find.byType(SeedlyInput),
        matching: find.textContaining('Ingresa'),
      ),
      findsNothing,
    );
  });

  testWidgets('only the failing fields are listed in the alert', (
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
    await tester.enterText(find.byType(SeedlyInput).at(0), 'hola@seedly.com');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<SeedlyAlert>(find.byType(SeedlyAlert)).message,
      'Ingresa tu contraseña',
    );
  });

  testWidgets('invalid fields turn danger-600 and clear once fixed', (
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
    InputDecorator decorator(int index) => tester.widget<InputDecorator>(
      find.descendant(
        of: find.byType(SeedlyInput).at(index),
        matching: find.byType(InputDecorator),
      ),
    );
    Color borderColor(InputBorder? border) =>
        (border! as OutlineInputBorder).borderSide.color;

    expect(decorator(0).decoration.error, isNull);
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    final danger = SeedlyPalette.danger[600];
    for (final index in [0, 1]) {
      expect(decorator(index).decoration.error, isNotNull);
      expect(borderColor(decorator(index).decoration.errorBorder), danger);
      expect(
        borderColor(decorator(index).decoration.focusedErrorBorder),
        danger,
      );
    }

    // After the first failed submit, fixing a field clears its border
    // without submitting again.
    await tester.enterText(find.byType(SeedlyInput).at(0), 'hola@seedly.com');
    await tester.pump();
    expect(decorator(0).decoration.error, isNull);
    expect(decorator(1).decoration.error, isNotNull);
  });

  testWidgets('showing validation errors does not shift the layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
    final anchors = [
      find.text('Contraseña *'),
      find.text('¿Olvidaste tu contraseña?'),
      find.text('Iniciar sesión'),
      find.text('Google'),
      find.text('Regístrate'),
    ];
    final before = [for (final anchor in anchors) tester.getRect(anchor)];

    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.byType(SeedlyAlert), findsOneWidget);
    expect([for (final anchor in anchors) tester.getRect(anchor)], before);
  });

  testWidgets('invalid form never reaches the auth service', (tester) async {
    final auth = FakeSeedlyAuthRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: SeedlyTheme.light,
        home: SeedlyLoginScreen(
          auth: auth,
          projects: FakeSeedlyProjectRepository(),
          users: FakeSeedlyUserRepository(),
        ),
      ),
    );
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(auth.emailAttempts, isEmpty);
  });

  testWidgets('a saved session skips login after loading', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: SeedlyTheme.light,
        home: SeedlyLoadingScreen(
          auth: FakeSeedlyAuthRepository(isSignedIn: true),
          projects: FakeSeedlyProjectRepository(),
          users: FakeSeedlyUserRepository(),
          startAfter: Future<void>.value(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.byType(SeedlyHomeScreen), findsOneWidget);
    expect(find.byType(SeedlyLoginScreen), findsNothing);
  });

  testWidgets('login can be scrolled on a compact phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
    expect(find.text('Regístrate'), findsOneWidget);
    final error = tester.takeException();
    expect(error, isNull);
  });

  testWidgets(
    'standard phone fits login without scrolling and keeps an upper bias',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
      final scroll = tester.state<ScrollableState>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      );
      expect(scroll.position.maxScrollExtent, 0);
      final top = tester.getRect(find.text('Bienvenido.')).top;
      final bottom = 844 - tester.getRect(find.text('Regístrate')).bottom;
      expect(top, greaterThan(bottom));
    },
  );

  testWidgets('button label has a tight line box at the vertical center', (
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
    final label = tester.getRect(find.text('Iniciar sesión'));
    final button = tester.getRect(
      find.ancestor(
        of: find.text('Iniciar sesión'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(label.height, lessThan(26));
    expect((label.center.dy - button.center.dy).abs(), lessThan(2));
  });

  testWidgets('recovery and sign-in actions form a compact visual group', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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

    final passwordField = find.descendant(
      of: find.byType(SeedlyInput).at(1),
      matching: find.byType(TextFormField),
    );
    final passwordToRecovery =
        tester.getRect(find.text('¿Olvidaste tu contraseña?')).top -
        tester.getRect(passwordField).bottom;
    final signIn = tester.getRect(
      find.ancestor(
        of: find.text('Iniciar sesión'),
        matching: find.byType(FilledButton),
      ),
    );
    final divider = tester.getRect(find.text('o continúa con'));
    final google = tester.getRect(
      find.ancestor(
        of: find.text('Google'),
        matching: find.byType(OutlinedButton),
      ),
    );

    expect(passwordToRecovery, lessThanOrEqualTo(20));
    expect(divider.top - signIn.bottom, lessThanOrEqualTo(24));
    expect(google.top - divider.bottom, lessThanOrEqualTo(24));
  });

  testWidgets('welcome moves lower while the full login still fits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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

    expect(tester.getRect(find.text('Bienvenido.')).top, greaterThan(125));
    expect(tester.getRect(find.text('Regístrate')).bottom, lessThan(844));
  });

  testWidgets('recovery link leaves a little breathing room before sign in', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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

    final recovery = tester.getRect(
      find.ancestor(
        of: find.text('¿Olvidaste tu contraseña?'),
        matching: find.byType(TextButton),
      ),
    );
    final signIn = tester.getRect(
      find.ancestor(
        of: find.text('Iniciar sesión'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(signIn.top - recovery.bottom, inInclusiveRange(19, 21));
  });
}
