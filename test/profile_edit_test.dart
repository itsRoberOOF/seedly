import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/models/seedly_errors.dart';
import 'package:seedly/models/seedly_user_profile.dart';
import 'package:seedly/screens/seedly_home_screen.dart';
import 'package:seedly/screens/seedly_login_screen.dart';
import 'package:seedly/screens/seedly_profile_view.dart';
import 'package:seedly/theme/seedly_theme.dart';
import 'package:seedly/widgets/seedly_alert.dart';
import 'package:seedly/widgets/seedly_input.dart';
import 'package:seedly/widgets/seedly_menu.dart';

import 'support/fake_seedly_auth_repository.dart';
import 'support/fake_seedly_image_picker.dart';
import 'support/fake_seedly_project_repository.dart';
import 'support/fake_seedly_user_repository.dart';
import 'support/keep_plant_still.dart';
import 'support/sign_out.dart';

SeedlyUserProfile _profile({String? username, String? bio}) =>
    SeedlyUserProfile(
      uid: 'ana',
      email: 'ana@seedly.app',
      displayName: 'Ana',
      username: username,
      bio: bio,
      createdAt: DateTime(2026),
    );

Future<void> _openView(
  WidgetTester tester,
  FakeSeedlyUserRepository users, {
  SeedlyUserProfile? profile,
  FutureOr<void> Function()? onSignOut,
  ValueChanged<bool>? onLeavingChanged,
  FakeSeedlyAuthRepository? auth,
}) async {
  tester.view.physicalSize = const Size(440, 956);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: SeedlyTheme.light,
      home: Scaffold(
        body: SeedlyProfileView(
          profile: profile ?? _profile(),
          auth: auth ?? FakeSeedlyAuthRepository(isSignedIn: true),
          users: users,
          picker: FakeSeedlyImagePicker(),
          onSignOut: onSignOut ?? () {},
          onLeavingChanged: onLeavingChanged,
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder get _nameField => find.byType(EditableText).at(0);
Finder get _usernameField => find.byType(EditableText).at(2);
Finder get _bioField => find.byType(EditableText).at(3);

String _text(WidgetTester tester, Finder field) =>
    tester.widget<EditableText>(field).controller.text;

Future<void> _blur(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
}

Future<void> _type(WidgetTester tester, Finder field, String text) async {
  await tester.enterText(field, text);
  await tester.pump();
}

void main() {
  keepPlantStill();
  tearDown(hideSeedlyAlert);

  testWidgets('shows the saved username and bio', (tester) async {
    final users = FakeSeedlyUserRepository(
      stored: _profile(username: 'rober', bio: 'Hola'),
    );
    await _openView(tester, users);

    expect(_text(tester, _usernameField), 'rober');
    expect(_text(tester, _bioField), 'Hola');
  });

  testWidgets('a later emit updates the fields but not a focused one', (
    tester,
  ) async {
    final users = FakeSeedlyUserRepository(
      stored: _profile(username: 'rober', bio: 'Hola'),
    );
    await _openView(tester, users);

    users.emit(_profile(username: 'nuevo', bio: 'Adiós'));
    await tester.pump();
    expect(_text(tester, _usernameField), 'nuevo');
    expect(_text(tester, _bioField), 'Adiós');

    await _type(tester, _bioField, 'Escribiendo');
    users.emit(_profile(username: 'otro', bio: 'Remoto'));
    await tester.pump();
    expect(_text(tester, _usernameField), 'otro');
    expect(_text(tester, _bioField), 'Escribiendo');
  });

  testWidgets('losing focus saves only the username, normalized', (
    tester,
  ) async {
    final users = FakeSeedlyUserRepository();
    await _openView(tester, users);

    await _type(tester, _usernameField, ' @Rober_1 ');
    await _blur(tester);

    expect(users.updates, hasLength(1));
    expect(users.updates.single.username!.value, 'rober_1');
    expect(users.updates.single.bio, isNull);
    expect(_text(tester, _usernameField), 'rober_1');
  });

  testWidgets('losing focus saves the name to Auth and the profile', (
    tester,
  ) async {
    final users = FakeSeedlyUserRepository();
    final auth = FakeSeedlyAuthRepository(isSignedIn: true);
    await _openView(tester, users, auth: auth);

    expect(_text(tester, _nameField), 'Ana');
    await _type(tester, _nameField, '  Ana María ');
    await _blur(tester);

    expect(auth.renames, ['Ana María']);
    expect(users.updates, hasLength(1));
    expect(users.updates.single.displayName!.value, 'Ana María');
    expect(users.updates.single.username, isNull);
    expect(users.updates.single.bio, isNull);
    expect(_text(tester, _nameField), 'Ana María');
    expect(find.bySemanticsLabel('Iniciales de Ana María'), findsOneWidget);
  });

  testWidgets('an empty name alerts and is not saved', (tester) async {
    final users = FakeSeedlyUserRepository();
    final auth = FakeSeedlyAuthRepository(isSignedIn: true);
    await _openView(tester, users, auth: auth);

    await _type(tester, _nameField, '   ');
    await _blur(tester);

    expect(auth.renames, isEmpty);
    expect(users.updates, isEmpty);
    expect(find.text('Nombre no válido'), findsOneWidget);
  });

  testWidgets('a name Auth refuses is not saved to the profile', (
    tester,
  ) async {
    final users = FakeSeedlyUserRepository();
    final auth = FakeSeedlyAuthRepository(isSignedIn: true)
      ..renameError = const SeedlyProfileException(
        SeedlyProfileError.saveFailed,
      );
    await _openView(tester, users, auth: auth);

    await _type(tester, _nameField, 'Otra');
    await _blur(tester);

    expect(auth.renames, ['Otra']);
    expect(users.updates, isEmpty);
    expect(find.text('No se pudo actualizar el perfil'), findsOneWidget);
    expect(find.bySemanticsLabel('Iniciales de Ana'), findsOneWidget);
  });

  testWidgets('losing focus saves only the bio', (tester) async {
    final users = FakeSeedlyUserRepository();
    await _openView(tester, users);

    await _type(tester, _bioField, 'Me gustan las plantas');
    await _blur(tester);

    expect(users.updates, hasLength(1));
    expect(users.updates.single.username, isNull);
    expect(users.updates.single.bio!.value, 'Me gustan las plantas');
  });

  testWidgets('does not save without changes', (tester) async {
    final users = FakeSeedlyUserRepository(
      stored: _profile(username: 'rober', bio: 'Hola'),
    );
    await _openView(tester, users);

    await tester.tap(_usernameField);
    await tester.pump();
    await _blur(tester);
    await _type(tester, _bioField, 'Hola ');
    await _blur(tester);

    expect(users.updates, isEmpty);
    expect(find.text('Perfil actualizado'), findsNothing);
  });

  testWidgets('an invalid username alerts, is not saved and turns red', (
    tester,
  ) async {
    final users = FakeSeedlyUserRepository();
    await _openView(tester, users);

    await _type(tester, _usernameField, 'ab');
    await _blur(tester);

    expect(find.text('Usuario no válido'), findsOneWidget);
    expect(users.updates, isEmpty);
    final field = tester.widget<TextFormField>(
      find.byType(TextFormField).at(2),
    );
    expect(field.validator!('ab'), isNotNull);
    expect(
      tester
          .state<FormFieldState<String>>(find.byType(TextFormField).at(2))
          .hasError,
      isTrue,
    );
  });

  testWidgets('clearing a saved username sends a null value', (tester) async {
    final users = FakeSeedlyUserRepository(stored: _profile(username: 'rober'));
    await _openView(tester, users);

    await _type(tester, _usernameField, '');
    await _blur(tester);

    expect(users.updates.single.username, isNotNull);
    expect(users.updates.single.username!.value, isNull);
  });

  testWidgets('the done key saves once, not again when focus is lost', (
    tester,
  ) async {
    final users = FakeSeedlyUserRepository();
    await _openView(tester, users);

    await _type(tester, _usernameField, 'rober');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await _blur(tester);

    expect(users.updates, hasLength(1));
  });

  testWidgets('shows a success alert, or the sync message when offline', (
    tester,
  ) async {
    final users = FakeSeedlyUserRepository();
    await _openView(tester, users);

    await _type(tester, _bioField, 'Uno');
    await _blur(tester);
    expect(find.text('Perfil actualizado'), findsOneWidget);
    expect(find.text('Tus cambios ya están guardados.'), findsOneWidget);

    users.updateResult = SeedlyProfileSave.pendingSync;
    await _type(tester, _bioField, 'Dos');
    await _blur(tester);
    await tester.pump();
    expect(
      find.text('Tus cambios se guardarán cuando vuelva la conexión.'),
      findsOneWidget,
    );
  });

  testWidgets('a failed save alerts and retries on the next focus loss', (
    tester,
  ) async {
    final users = FakeSeedlyUserRepository()
      ..updateError = const SeedlyProfileException(
        SeedlyProfileError.saveFailed,
      );
    await _openView(tester, users);

    await _type(tester, _bioField, 'Hola');
    await _blur(tester);
    expect(find.text('No se pudo actualizar el perfil'), findsOneWidget);
    expect(find.text('Inténtalo de nuevo en un momento.'), findsOneWidget);
    expect(users.updates, isEmpty);

    users.updateError = null;
    await tester.tap(_bioField);
    await tester.pump();
    await _blur(tester);

    expect(users.updates, hasLength(1));
    expect(users.updates.single.bio!.value, 'Hola');
    expect(find.text('Perfil actualizado'), findsOneWidget);
  });

  testWidgets('leaving the profile with a focused edit saves it silently', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final users = FakeSeedlyUserRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: SeedlyTheme.light,
        home: SeedlyHomeScreen(
          auth: FakeSeedlyAuthRepository(isSignedIn: true),
          projects: FakeSeedlyProjectRepository(),
          users: users,
        ),
      ),
    );
    await tester.tap(
      find.descendant(
        of: find.byType(SeedlyMenu),
        matching: find.text('Mi perfil'),
      ),
    );
    await tester.pump();
    await _type(tester, _bioField, 'Sin perder el foco');

    await tester.tap(find.text('Proyectos'));
    await tester.pump();

    expect(find.byType(SeedlyProfileView), findsNothing);
    expect(users.updates.single.bio!.value, 'Sin perder el foco');
    expect(find.text('Perfil actualizado'), findsNothing);
  });

  testWidgets('tapping the empty page unfocuses and saves', (tester) async {
    final users = FakeSeedlyUserRepository();
    await _openView(tester, users);

    await _type(tester, _bioField, 'Hola');
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();

    expect(users.updates.single.bio!.value, 'Hola');
  });

  testWidgets('login reaches Home, whose profile reads the given users', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final users = FakeSeedlyUserRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: SeedlyTheme.light,
        home: SeedlyLoginScreen(
          auth: FakeSeedlyAuthRepository(),
          projects: FakeSeedlyProjectRepository(),
          users: users,
        ),
      ),
    );
    final inputs = find.byType(SeedlyInput);
    await tester.enterText(inputs.at(0), 'ana@seedly.app');
    await tester.enterText(inputs.at(1), 'secreto123');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.byType(SeedlyHomeScreen), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(SeedlyMenu),
        matching: find.text('Mi perfil'),
      ),
    );
    await tester.pump();
    users.emit(_profile(username: 'ana_1'));
    await tester.pump();

    expect(_text(tester, _usernameField), 'ana_1');
  });

  group('bio length', () {
    testWidgets('typing or pasting past 250 units is cut', (tester) async {
      final users = FakeSeedlyUserRepository();
      await _openView(tester, users);

      await _type(tester, _bioField, 'a' * 260);
      expect(_text(tester, _bioField), 'a' * 250);

      await _type(tester, _bioField, '');
      await _type(tester, _bioField, '${'a' * 240}${'😀' * 10}');
      expect(_text(tester, _bioField), '${'a' * 240}${'😀' * 5}');
      await _blur(tester);

      expect(users.updates.single.bio!.value!.length, 250);
    });

    testWidgets('typing one more character at a full field is rejected', (
      tester,
    ) async {
      final users = FakeSeedlyUserRepository();
      await _openView(tester, users);

      await _type(tester, _bioField, 'a' * 250);
      await _type(tester, _bioField, '${'a' * 250}X');
      expect(_text(tester, _bioField), 'a' * 250);
    });

    testWidgets('125 emojis are saved', (tester) async {
      final users = FakeSeedlyUserRepository();
      await _openView(tester, users);

      await _type(tester, _bioField, '😀' * 126);
      expect(_text(tester, _bioField), '😀' * 125);
      await _blur(tester);

      expect(users.updates, hasLength(1));
      expect(users.updates.single.bio!.value, '😀' * 125);
      expect(find.text('Bio no válida'), findsNothing);
    });
  });

  group('signing out', () {
    Future<void> signOut(WidgetTester tester) async {
      await tapSignOut(tester);
      await tester.pump();
    }

    testWidgets('saves a focused bio first, then signs out', (tester) async {
      final users = FakeSeedlyUserRepository();
      final gate = Completer<void>();
      users.updateGate = gate.future;
      final log = <String>[];
      await _openView(
        tester,
        users,
        onSignOut: () => log.add('signOut:${users.updates.length}'),
      );

      await _type(tester, _bioField, 'Antes de salir');
      await signOut(tester);
      expect(users.updates, hasLength(1));
      expect(users.updates.single.bio!.value, 'Antes de salir');
      expect(log, isEmpty);

      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(log, ['signOut:1']);
      expect(users.updates, hasLength(1));
    });

    testWidgets('saves a focused username first, then signs out', (
      tester,
    ) async {
      final users = FakeSeedlyUserRepository();
      final gate = Completer<void>();
      users.updateGate = gate.future;
      final log = <String>[];
      await _openView(
        tester,
        users,
        onSignOut: () => log.add('signOut:${users.updates.length}'),
      );

      await _type(tester, _usernameField, 'rober');
      await signOut(tester);
      expect(users.updates, hasLength(1));
      expect(users.updates.single.username!.value, 'rober');
      expect(log, isEmpty);

      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(log, ['signOut:1']);
    });

    testWidgets('a failed save warns first and the next tap signs out', (
      tester,
    ) async {
      final users = FakeSeedlyUserRepository()
        ..updateError = const SeedlyProfileException(
          SeedlyProfileError.saveFailed,
        );
      var signedOut = 0;
      await _openView(tester, users, onSignOut: () => signedOut++);

      await _type(tester, _bioField, 'Hola');
      await signOut(tester);
      await tester.pump();
      expect(find.text('No se guardaron tus cambios'), findsOneWidget);
      expect(
        find.textContaining('Toca Cerrar sesión otra vez'),
        findsOneWidget,
      );
      expect(signedOut, 0);

      users.updateError = null;
      await signOut(tester);
      await tester.pump();
      expect(signedOut, 1);
    });

    for (final reason in SeedlyProfileError.values) {
      testWidgets('a permanent $reason warns once, then signs out', (
        tester,
      ) async {
        final error = SeedlyProfileException(reason);
        final users = FakeSeedlyUserRepository()..updateError = error;
        var signedOut = 0;
        await _openView(tester, users, onSignOut: () => signedOut++);

        await _type(tester, _bioField, 'Hola');
        await signOut(tester);
        await tester.pump();
        expect(find.text('No se guardaron tus cambios'), findsOneWidget);
        expect(
          find.textContaining('Toca Cerrar sesión otra vez'),
          findsOneWidget,
        );
        expect(find.textContaining(error.message), findsOneWidget);
        expect(signedOut, 0);

        await signOut(tester);
        await tester.pump();
        expect(signedOut, 1);
        expect(users.updates, isEmpty);
      });
    }

    testWidgets('an invalid username warns first, the next tap signs out', (
      tester,
    ) async {
      final users = FakeSeedlyUserRepository();
      var signedOut = 0;
      await _openView(tester, users, onSignOut: () => signedOut++);

      await _type(tester, _usernameField, 'ab');
      await signOut(tester);
      await tester.pump();

      expect(find.text('No se guardaron tus cambios'), findsOneWidget);
      expect(
        find.textContaining('Toca Cerrar sesión otra vez'),
        findsOneWidget,
      );
      expect(users.updates, isEmpty);
      expect(signedOut, 0);

      await signOut(tester);
      await tester.pump();
      expect(users.updates, isEmpty);
      expect(signedOut, 1);
    });

    testWidgets('a successful save signs out at once with no alert left', (
      tester,
    ) async {
      final users = FakeSeedlyUserRepository();
      var signedOut = 0;
      await _openView(tester, users, onSignOut: () => signedOut++);

      await _type(tester, _bioField, 'Hola');
      await signOut(tester);
      await tester.pump();

      expect(users.updates, hasLength(1));
      expect(signedOut, 1);
      expect(find.byType(SeedlyAlert), findsNothing);
    });

    testWidgets('editing again after the warning starts over', (tester) async {
      final users = FakeSeedlyUserRepository()
        ..updateError = const SeedlyProfileException(
          SeedlyProfileError.saveFailed,
        );
      var signedOut = 0;
      await _openView(tester, users, onSignOut: () => signedOut++);

      await _type(tester, _bioField, 'Hola');
      await signOut(tester);
      await tester.pump();
      expect(find.text('No se guardaron tus cambios'), findsOneWidget);
      hideSeedlyAlert();
      await tester.pump();

      await _type(tester, _bioField, 'Hola otra vez');
      await signOut(tester);
      await tester.pump();
      expect(find.text('No se guardaron tus cambios'), findsOneWidget);
      expect(signedOut, 0);

      await signOut(tester);
      await tester.pump();
      expect(signedOut, 1);
    });

    testWidgets('a save that works after a warning signs out and resets', (
      tester,
    ) async {
      final users = FakeSeedlyUserRepository()
        ..updateError = const SeedlyProfileException(
          SeedlyProfileError.saveFailed,
        );
      var signedOut = 0;
      await _openView(tester, users, onSignOut: () => signedOut++);

      await _type(tester, _bioField, 'Hola');
      await signOut(tester);
      await tester.pump();
      expect(signedOut, 0);

      users.updateError = null;
      await signOut(tester);
      await tester.pump();
      expect(users.updates, hasLength(1));
      expect(signedOut, 1);

      // The warning mark was cleared: a new failure warns again.
      users.updateError = const SeedlyProfileException(
        SeedlyProfileError.saveFailed,
      );
      await _type(tester, _bioField, 'Otra');
      await signOut(tester);
      await tester.pump();
      expect(find.text('No se guardaron tus cambios'), findsOneWidget);
      expect(signedOut, 1);
    });

    testWidgets('a double tap with a slow save saves and signs out once', (
      tester,
    ) async {
      final users = FakeSeedlyUserRepository();
      final gate = Completer<void>();
      users.updateGate = gate.future;
      var signedOut = 0;
      await _openView(tester, users, onSignOut: () => signedOut++);

      await _type(tester, _bioField, 'Hola');
      await signOut(tester);
      // Signing out is already under way: the second tap opens no modal.
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cerrar sesión'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.widgetWithText(FilledButton, 'Cerrar sesión'), findsNothing);
      expect(users.updates, hasLength(1));

      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(users.updates, hasLength(1));
      expect(signedOut, 1);
    });

    testWidgets('two quick taps on a failing save only warn', (tester) async {
      final users = FakeSeedlyUserRepository()
        ..updateError = const SeedlyProfileException(
          SeedlyProfileError.saveFailed,
        );
      final gate = Completer<void>();
      users.updateGate = gate.future;
      var signedOut = 0;
      await _openView(tester, users, onSignOut: () => signedOut++);

      await _type(tester, _bioField, 'Hola');
      await signOut(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cerrar sesión'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.widgetWithText(FilledButton, 'Cerrar sesión'), findsNothing);
      expect(signedOut, 0);

      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(find.text('No se guardaron tus cambios'), findsOneWidget);
      expect(signedOut, 0);

      await signOut(tester);
      await tester.pump();
      expect(signedOut, 1);
    });

    testWidgets('tells the shell it is leaving from the confirmed tap', (
      tester,
    ) async {
      final users = FakeSeedlyUserRepository();
      final gate = Completer<void>();
      users.updateGate = gate.future;
      final leaving = <bool>[];
      await _openView(tester, users, onLeavingChanged: leaving.add);

      await _type(tester, _bioField, 'Hola');
      await signOut(tester);

      // Leaving began before the slow save ended, so the shell can already
      // block the screen.
      expect(leaving, [true]);

      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(leaving, [true, false]);
    });

    testWidgets('keeps leaving until the shell has signed out', (tester) async {
      final signingOut = Completer<void>();
      final leaving = <bool>[];
      await _openView(
        tester,
        FakeSeedlyUserRepository(),
        onSignOut: () => signingOut.future,
        onLeavingChanged: leaving.add,
      );

      await signOut(tester);
      await tester.pump();
      expect(leaving, [true]);

      signingOut.complete();
      await tester.pump();
      expect(leaving, [true, false]);
    });

    testWidgets('stops leaving when a failed save only warns', (tester) async {
      final users = FakeSeedlyUserRepository()
        ..updateError = const SeedlyProfileException(
          SeedlyProfileError.saveFailed,
        );
      final leaving = <bool>[];
      await _openView(tester, users, onLeavingChanged: leaving.add);

      await _type(tester, _bioField, 'Hola');
      await signOut(tester);
      await tester.pump();
      await tester.pump();

      expect(find.text('No se guardaron tus cambios'), findsOneWidget);
      expect(leaving, [true, false]);
    });

    testWidgets('Home leaves no success alert over the login', (tester) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final users = FakeSeedlyUserRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: SeedlyTheme.light,
          home: SeedlyHomeScreen(
            auth: FakeSeedlyAuthRepository(isSignedIn: true),
            projects: FakeSeedlyProjectRepository(),
            users: users,
          ),
        ),
      );
      await tester.tap(
        find.descendant(
          of: find.byType(SeedlyMenu),
          matching: find.text('Mi perfil'),
        ),
      );
      await tester.pump();
      await _type(tester, _bioField, 'Hasta pronto');

      await tapSignOut(tester);
      await tester.pumpAndSettle();

      expect(find.byType(SeedlyLoginScreen), findsOneWidget);
      expect(find.byType(SeedlyAlert), findsNothing);
    });

    testWidgets('without pending changes it signs out and saves nothing', (
      tester,
    ) async {
      final users = FakeSeedlyUserRepository(
        stored: _profile(username: 'rober', bio: 'Hola'),
      );
      var signedOut = 0;
      await _openView(tester, users, onSignOut: () => signedOut++);

      await signOut(tester);
      await tester.pump();

      expect(users.updates, isEmpty);
      expect(signedOut, 1);
    });

    testWidgets('Home saves the bio before it signs out', (tester) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final users = FakeSeedlyUserRepository();
      final auth = FakeSeedlyAuthRepository(isSignedIn: true);
      var updatesAtSignOut = -1;
      auth.onSignOut = () => updatesAtSignOut = users.updates.length;
      await tester.pumpWidget(
        MaterialApp(
          theme: SeedlyTheme.light,
          home: SeedlyHomeScreen(
            auth: auth,
            projects: FakeSeedlyProjectRepository(),
            users: users,
          ),
        ),
      );
      await tester.tap(
        find.descendant(
          of: find.byType(SeedlyMenu),
          matching: find.text('Mi perfil'),
        ),
      );
      await tester.pump();
      await _type(tester, _bioField, 'Hasta pronto');

      await tapSignOut(tester);
      await tester.pumpAndSettle();

      expect(users.updates, hasLength(1));
      expect(updatesAtSignOut, 1);
      expect(auth.signOutCalls, 1);
      expect(find.byType(SeedlyLoginScreen), findsOneWidget);
    });
  });

  testWidgets('an expired session shows its own message', (tester) async {
    final users = FakeSeedlyUserRepository()
      ..updateError = const SeedlyProfileException(
        SeedlyProfileError.sessionExpired,
      );
    await _openView(tester, users);

    await _type(tester, _bioField, 'Hola');
    await _blur(tester);

    expect(find.text('No se pudo actualizar el perfil'), findsOneWidget);
    expect(
      find.text(
        'No se pudo guardar tu perfil. Cierra sesión y vuelve a entrar; si '
        'sigue fallando, inténtalo más tarde.',
      ),
      findsOneWidget,
    );
  });

  group('initials label', () {
    String initialsLabel(WidgetTester tester) => tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.semanticsLabel)
        .whereType<String>()
        .singleWhere((label) => label.startsWith('Iniciales'));

    testWidgets('names the account by its display name', (tester) async {
      await _openView(tester, FakeSeedlyUserRepository());
      expect(initialsLabel(tester), 'Iniciales de Ana');
    });

    testWidgets('uses the display name given, with accents', (tester) async {
      await _openView(
        tester,
        FakeSeedlyUserRepository(),
        profile: SeedlyUserProfile(
          uid: 'rober',
          email: 'rober@seedly.app',
          displayName: 'Rober Morán',
          createdAt: DateTime(2026),
        ),
      );
      expect(initialsLabel(tester), 'Iniciales de Rober Morán');
    });

    testWidgets('falls back to the email', (tester) async {
      await _openView(
        tester,
        FakeSeedlyUserRepository(),
        profile: SeedlyUserProfile(
          uid: 'ana',
          email: 'ana@seedly.app',
          createdAt: DateTime(2026),
        ),
      );
      expect(initialsLabel(tester), 'Iniciales de ana@seedly.app');
    });

    for (final name in ['', '   ']) {
      testWidgets('falls back to the email for "$name"', (tester) async {
        await _openView(
          tester,
          FakeSeedlyUserRepository(),
          profile: SeedlyUserProfile(
            uid: 'ana',
            email: 'ana@seedly.app',
            displayName: name,
            createdAt: DateTime(2026),
          ),
        );
        expect(initialsLabel(tester), 'Iniciales de ana@seedly.app');
      });
    }
  });

  group('watching the profile', () {
    Future<void> failAndWait(
      WidgetTester tester,
      FakeSeedlyUserRepository users,
      Duration delay,
    ) async {
      final calls = users.watchCalls;
      await tester.pump(delay - const Duration(milliseconds: 1));
      expect(users.watchCalls, calls, reason: 'retried before $delay');
      await tester.pump(const Duration(milliseconds: 1));
      expect(users.watchCalls, calls + 1, reason: 'no retry after $delay');
    }

    testWidgets('an error keeps the last values and re-reads after 2 s', (
      tester,
    ) async {
      final users = FakeSeedlyUserRepository(
        stored: _profile(username: 'rober', bio: 'Hola'),
      );
      await _openView(tester, users);
      expect(users.watchCalls, 1);

      users.emitError();
      await tester.pump();
      expect(_text(tester, _usernameField), 'rober');
      expect(_text(tester, _bioField), 'Hola');
      expect(tester.takeException(), isNull);

      await failAndWait(tester, users, const Duration(seconds: 2));
      users.emit(_profile(username: 'nuevo', bio: 'Adiós'));
      await tester.pump();
      expect(_text(tester, _usernameField), 'nuevo');
      expect(_text(tester, _bioField), 'Adiós');
    });

    testWidgets('backs off 2, 4, 8, 16, 30, 30 s and then gives up', (
      tester,
    ) async {
      final users = FakeSeedlyUserRepository();
      await _openView(tester, users);

      users.failingWatches = 6;
      users.emitError();
      await tester.pump();
      for (final seconds in [2, 4, 8, 16, 30, 30]) {
        await failAndWait(tester, users, Duration(seconds: seconds));
      }
      expect(users.watchCalls, 7);

      await tester.pump(const Duration(minutes: 5));
      expect(users.watchCalls, 7);
      expect(tester.takeException(), isNull);
    });

    testWidgets('receiving data starts the backoff over', (tester) async {
      final users = FakeSeedlyUserRepository();
      await _openView(tester, users);

      users.failingWatches = 1;
      users.emitError();
      await tester.pump();
      await failAndWait(tester, users, const Duration(seconds: 2));
      await failAndWait(tester, users, const Duration(seconds: 4));
      // That read succeeded and reported the profile.
      users.emitError();
      await tester.pump();
      await failAndWait(tester, users, const Duration(seconds: 2));
    });

    testWidgets('leaving the view cancels the retry', (tester) async {
      final users = FakeSeedlyUserRepository();
      await _openView(tester, users);

      users.emitError();
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 1));

      expect(users.watchCalls, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('signing out from Home leaves no pending retry', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final users = FakeSeedlyUserRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: SeedlyTheme.light,
          home: SeedlyHomeScreen(
            auth: FakeSeedlyAuthRepository(isSignedIn: true),
            projects: FakeSeedlyProjectRepository(),
            users: users,
          ),
        ),
      );
      await tester.tap(
        find.descendant(
          of: find.byType(SeedlyMenu),
          matching: find.text('Mi perfil'),
        ),
      );
      await tester.pump();
      users.emitError();
      await tester.pump();

      await tapSignOut(tester);
      await tester.pumpAndSettle();
      users.emitError();
      await tester.pump(const Duration(minutes: 1));

      expect(find.byType(SeedlyLoginScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
