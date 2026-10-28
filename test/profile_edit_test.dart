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
import 'support/fake_seedly_project_repository.dart';
import 'support/fake_seedly_user_repository.dart';

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
  FakeSeedlyUserRepository users,
) async {
  tester.view.physicalSize = const Size(440, 956);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: SeedlyTheme.light,
      home: Scaffold(
        body: SeedlyProfileView(
          profile: _profile(),
          users: users,
          onSignOut: () {},
        ),
      ),
    ),
  );
  await tester.pump();
}

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
}
