import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/models/seedly_errors.dart';
import 'package:seedly/screens/seedly_home_screen.dart';
import 'package:seedly/screens/seedly_login_screen.dart';
import 'package:seedly/screens/seedly_sign_up_screen.dart';
import 'package:seedly/theme/seedly_theme.dart';
import 'package:seedly/widgets/seedly_alert.dart';
import 'package:seedly/widgets/seedly_busy_overlay.dart';
import 'package:seedly/widgets/seedly_input.dart';

import 'support/fake_seedly_auth_repository.dart';
import 'support/fake_seedly_project_repository.dart';
import 'support/fake_seedly_user_repository.dart';
import 'support/keep_plant_still.dart';

Future<void> _open(
  WidgetTester tester,
  Widget Function(FakeSeedlyAuthRepository auth) screen,
  FakeSeedlyAuthRepository auth,
) async {
  tester.view.physicalSize = const Size(440, 956);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(theme: SeedlyTheme.light, home: screen(auth)),
  );
}

Widget _login(FakeSeedlyAuthRepository auth) => SeedlyLoginScreen(
  auth: auth,
  projects: FakeSeedlyProjectRepository(),
  users: FakeSeedlyUserRepository(),
);

Widget _signUp(FakeSeedlyAuthRepository auth) => SeedlySignUpScreen(
  auth: auth,
  projects: FakeSeedlyProjectRepository(),
  users: FakeSeedlyUserRepository(),
);

Future<void> _signInWithEmail(WidgetTester tester) async {
  final inputs = find.byType(SeedlyInput);
  await tester.enterText(inputs.at(0), 'ana@seedly.app');
  await tester.enterText(inputs.at(1), 'secreto123');
  await tester.tap(find.text('Iniciar sesión'));
  await tester.pump();
}

Future<void> _createAccount(WidgetTester tester) async {
  final inputs = find.byType(SeedlyInput);
  await tester.enterText(inputs.at(0), 'Ana');
  await tester.enterText(inputs.at(1), 'ana@seedly.app');
  await tester.enterText(inputs.at(2), 'secreto123');
  await tester.enterText(inputs.at(3), 'secreto123');
  await tester.ensureVisible(find.text('Crear cuenta'));
  await tester.tap(find.text('Crear cuenta'));
  await tester.pump();
}

Future<void> _tapGoogle(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Google'));
  await tester.tap(find.text('Google'));
  await tester.pump();
}

/// The screen's own PopScope; found by predicate because the one in the
/// sign-up form has another type argument than a bare `PopScope`.
PopScope _popScope(WidgetTester tester, Type screen) => tester.widget(
  find
      .descendant(
        of: find.byType(screen),
        matching: find.byWidgetPredicate((widget) => widget is PopScope),
      )
      .first,
) as PopScope;

void main() {
  keepPlantStill();
  tearDown(hideSeedlyAlert);

  group('Iniciar sesión', () {
    testWidgets('there is no veil until the form is sent', (tester) async {
      await _open(tester, _login, FakeSeedlyAuthRepository());

      expect(find.byType(SeedlyBusyOverlay), findsNothing);
      expect(_popScope(tester, SeedlyLoginScreen).canPop, isTrue);
    });

    testWidgets('sending the form covers the screen while it waits', (
      tester,
    ) async {
      final gate = Completer<void>();
      final auth = FakeSeedlyAuthRepository()..signInGate = gate.future;
      await _open(tester, _login, auth);

      await _signInWithEmail(tester);

      expect(find.byType(SeedlyBusyOverlay), findsOneWidget);
      expect(find.text('Iniciando sesión…'), findsOneWidget);
      expect(
        tester.getRect(find.byType(SeedlyBusyOverlay)),
        tester.getRect(find.byType(SeedlyLoginScreen)),
      );

      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('nothing behind the veil can be used, not even back', (
      tester,
    ) async {
      final gate = Completer<void>();
      final auth = FakeSeedlyAuthRepository()..signInGate = gate.future;
      await _open(tester, _login, auth);
      await _signInWithEmail(tester);

      await tester.tap(find.text('Regístrate'), warnIfMissed: false);
      await tester.pump();
      expect(find.byType(SeedlySignUpScreen), findsNothing);
      expect(_popScope(tester, SeedlyLoginScreen).canPop, isFalse);

      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('signed in, Inicio opens with no veil', (tester) async {
      final gate = Completer<void>();
      final auth = FakeSeedlyAuthRepository()..signInGate = gate.future;
      await _open(tester, _login, auth);
      await _signInWithEmail(tester);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.byType(SeedlyHomeScreen), findsOneWidget);
      expect(find.byType(SeedlyBusyOverlay), findsNothing);
    });

    testWidgets('a failed sign-in lifts the veil and says why', (tester) async {
      final gate = Completer<void>();
      final auth = FakeSeedlyAuthRepository(
        error: const SeedlyAuthException(SeedlyAuthError.network),
      )..signInGate = gate.future;
      await _open(tester, _login, auth);
      await _signInWithEmail(tester);
      expect(find.byType(SeedlyBusyOverlay), findsOneWidget);

      gate.complete();
      await tester.pump();
      await tester.pump();

      expect(find.byType(SeedlyBusyOverlay), findsNothing);
      expect(find.text('No se pudo iniciar sesión'), findsOneWidget);
      expect(_popScope(tester, SeedlyLoginScreen).canPop, isTrue);
    });

    testWidgets('Google covers the screen too, and closing it lifts it', (
      tester,
    ) async {
      final gate = Completer<void>();
      final auth = FakeSeedlyAuthRepository(googleResult: false)
        ..signInGate = gate.future;
      await _open(tester, _login, auth);

      await _tapGoogle(tester);
      expect(find.text('Iniciando sesión…'), findsOneWidget);

      gate.complete();
      await tester.pump();
      await tester.pump();

      // The picker was closed: back to the login, quietly.
      expect(find.byType(SeedlyBusyOverlay), findsNothing);
      expect(find.byType(SeedlyLoginScreen), findsOneWidget);
      expect(find.byType(SeedlyAlert), findsNothing);
    });

    testWidgets('the keyboard is put away when the form is sent', (
      tester,
    ) async {
      final gate = Completer<void>();
      final auth = FakeSeedlyAuthRepository()..signInGate = gate.future;
      await _open(tester, _login, auth);
      await tester.tap(find.byType(SeedlyInput).first);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNotNull);
      expect(FocusManager.instance.primaryFocus!.context, isNotNull);

      await _signInWithEmail(tester);

      expect(
        FocusManager.instance.primaryFocus?.context?.widget,
        isNot(isA<EditableText>()),
      );

      gate.complete();
      await tester.pumpAndSettle();
    });
  });

  group('Crear cuenta', () {
    testWidgets('creating the account says so while it waits', (tester) async {
      final gate = Completer<void>();
      final auth = FakeSeedlyAuthRepository()..signInGate = gate.future;
      await _open(tester, _signUp, auth);

      await _createAccount(tester);

      expect(find.byType(SeedlyBusyOverlay), findsOneWidget);
      expect(find.text('Creando tu cuenta…'), findsOneWidget);
      expect(_popScope(tester, SeedlySignUpScreen).canPop, isFalse);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(SeedlyHomeScreen), findsOneWidget);
      expect(find.byType(SeedlyBusyOverlay), findsNothing);
    });

    testWidgets('Google from here says it is signing in', (tester) async {
      final gate = Completer<void>();
      final auth = FakeSeedlyAuthRepository()..signInGate = gate.future;
      await _open(tester, _signUp, auth);

      await _tapGoogle(tester);

      expect(find.text('Iniciando sesión…'), findsOneWidget);
      expect(find.text('Creando tu cuenta…'), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a failed sign-up lifts the veil and says why', (tester) async {
      final gate = Completer<void>();
      final auth = FakeSeedlyAuthRepository(
        error: const SeedlyAuthException(SeedlyAuthError.network),
      )..signInGate = gate.future;
      await _open(tester, _signUp, auth);
      await _createAccount(tester);
      expect(find.byType(SeedlyBusyOverlay), findsOneWidget);

      gate.complete();
      await tester.pump();
      await tester.pump();

      expect(find.byType(SeedlyBusyOverlay), findsNothing);
      expect(find.text('No se pudo crear la cuenta'), findsOneWidget);
      expect(_popScope(tester, SeedlySignUpScreen).canPop, isTrue);
    });
  });
}
