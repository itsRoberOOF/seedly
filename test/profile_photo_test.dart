import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/models/seedly_errors.dart';
import 'package:seedly/models/seedly_user_profile.dart';
import 'package:seedly/screens/seedly_home_screen.dart';
import 'package:seedly/screens/seedly_profile_view.dart';
import 'package:seedly/services/seedly_image_picker.dart';
import 'package:seedly/theme/seedly_theme.dart';
import 'package:seedly/widgets/seedly_alert.dart';
import 'package:seedly/widgets/seedly_avatar.dart';
import 'package:seedly/widgets/seedly_menu.dart';

import 'support/fake_seedly_auth_repository.dart';
import 'support/fake_seedly_image_picker.dart';
import 'support/fake_seedly_project_repository.dart';
import 'support/fake_seedly_user_repository.dart';

SeedlyUserProfile _profile({
  String? displayName = 'Rober Morán',
  Uint8List? photo,
}) => SeedlyUserProfile(
  uid: 'ana',
  email: 'ana@seedly.app',
  displayName: displayName,
  photo: photo,
  createdAt: DateTime(2026),
);

Future<void> _open(
  WidgetTester tester,
  FakeSeedlyUserRepository users,
  FakeSeedlyImagePicker picker, {
  String? displayName = 'Rober Morán',
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
          profile: _profile(displayName: displayName),
          auth: FakeSeedlyAuthRepository(isSignedIn: true),
          users: users,
          picker: picker,
          onSignOut: () {},
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder get _avatarPhoto => find.descendant(
  of: find.byType(SeedlyAvatar),
  matching: find.byType(Image),
);

Finder get _initials =>
    find.descendant(of: find.byType(SeedlyAvatar), matching: find.text('RM'));

Future<void> _tapEdit(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Cambiar imagen'));
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester) async {
  await _tapEdit(tester);
  await tester.tap(find.text('Elegir imagen'));
  await tester.pumpAndSettle();
}

Future<void> _remove(WidgetTester tester) async {
  await _tapEdit(tester);
  await tester.tap(find.text('Quitar foto'));
  await tester.pumpAndSettle();
}

const _saveFailed = SeedlyProfileException(SeedlyProfileError.saveFailed);

void main() {
  tearDown(hideSeedlyAlert);

  testWidgets('without a photo the avatar shows the name initials', (
    tester,
  ) async {
    await _open(tester, FakeSeedlyUserRepository(), FakeSeedlyImagePicker());

    expect(_initials, findsOneWidget);
    expect(_avatarPhoto, findsNothing);
  });

  testWidgets('without a name the avatar shows the email initial', (
    tester,
  ) async {
    await _open(
      tester,
      FakeSeedlyUserRepository(),
      FakeSeedlyImagePicker(),
      displayName: null,
    );

    expect(
      find.descendant(of: find.byType(SeedlyAvatar), matching: find.text('A')),
      findsOneWidget,
    );
  });

  testWidgets('a saved photo replaces the initials', (tester) async {
    final users = FakeSeedlyUserRepository(stored: _profile(photo: tinyPng));
    await _open(tester, users, FakeSeedlyImagePicker());

    expect(_avatarPhoto, findsOneWidget);
    expect(_initials, findsNothing);

    users.emit(_profile());
    await tester.pumpAndSettle();
    expect(_avatarPhoto, findsNothing);
    expect(_initials, findsOneWidget);
  });

  testWidgets('choosing a photo shows it and saves only the photo', (
    tester,
  ) async {
    final users = FakeSeedlyUserRepository();
    final picker = FakeSeedlyImagePicker(photo: tinyPng);
    await _open(tester, users, picker);

    await _choose(tester);

    expect(users.updates, hasLength(1));
    final update = users.updates.single;
    expect(update.photo!.value, tinyPng);
    expect(update.username, isNull);
    expect(update.bio, isNull);
    expect(_avatarPhoto, findsOneWidget);
    expect(_initials, findsNothing);
    expect(find.text('Perfil actualizado'), findsOneWidget);
    expect(find.text('Tus cambios ya están guardados.'), findsOneWidget);
  });

  testWidgets('an offline save says it will sync', (tester) async {
    final users = FakeSeedlyUserRepository()
      ..updateResult = SeedlyProfileSave.pendingSync;
    await _open(tester, users, FakeSeedlyImagePicker(photo: tinyPng));

    await _choose(tester);

    expect(
      find.text('Tus cambios se guardarán cuando vuelva la conexión.'),
      findsOneWidget,
    );
  });

  testWidgets('removing the photo saves a null and brings the initials back', (
    tester,
  ) async {
    final users = FakeSeedlyUserRepository(stored: _profile(photo: tinyPng));
    await _open(tester, users, FakeSeedlyImagePicker());

    await _remove(tester);

    final update = users.updates.single;
    expect(update.photo, isNotNull);
    expect(update.photo!.value, isNull);
    expect(update.username, isNull);
    expect(update.bio, isNull);
    expect(_initials, findsOneWidget);
    expect(_avatarPhoto, findsNothing);
    expect(find.text('Perfil actualizado'), findsOneWidget);
  });

  testWidgets('a failed save alerts and brings back no photo', (tester) async {
    final users = FakeSeedlyUserRepository()..updateError = _saveFailed;
    await _open(tester, users, FakeSeedlyImagePicker(photo: tinyPng));

    await _choose(tester);

    expect(find.text('No se pudo actualizar el perfil'), findsOneWidget);
    expect(find.text('Perfil actualizado'), findsNothing);
    expect(_avatarPhoto, findsNothing);
    expect(_initials, findsOneWidget);
  });

  testWidgets('a failed save brings back the previous photo', (tester) async {
    final users = FakeSeedlyUserRepository(stored: _profile(photo: tinyPng))
      ..updateError = _saveFailed;
    await _open(tester, users, FakeSeedlyImagePicker());

    await _remove(tester);

    expect(find.text('No se pudo actualizar el perfil'), findsOneWidget);
    expect(_avatarPhoto, findsOneWidget);
    expect(_initials, findsNothing);
  });

  testWidgets('a picker error alerts in the modal and saves nothing', (
    tester,
  ) async {
    final users = FakeSeedlyUserRepository();
    final picker = FakeSeedlyImagePicker(
      error: const SeedlyImagePickerException('Sin permisos.'),
    );
    await _open(tester, users, picker);

    await _choose(tester);

    expect(find.text('No se pudo cargar la imagen'), findsOneWidget);
    expect(find.text('Sin permisos.'), findsOneWidget);
    expect(find.text('Foto de perfil'), findsOneWidget);
    expect(users.updates, isEmpty);
  });

  testWidgets('closing the modal without choosing saves nothing', (
    tester,
  ) async {
    final users = FakeSeedlyUserRepository();
    await _open(tester, users, FakeSeedlyImagePicker(photo: tinyPng));

    await _tapEdit(tester);
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();

    expect(users.updates, isEmpty);
    expect(_initials, findsOneWidget);
    expect(find.text('Perfil actualizado'), findsNothing);
  });

  testWidgets('Home hands its image picker to the profile', (tester) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final picker = FakeSeedlyImagePicker(photo: tinyPng);
    final users = FakeSeedlyUserRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: SeedlyTheme.light,
        home: SeedlyHomeScreen(
          auth: FakeSeedlyAuthRepository(isSignedIn: true),
          projects: FakeSeedlyProjectRepository(),
          users: users,
          imagePicker: picker,
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

    await _choose(tester);

    expect(picker.calls, 1);
    expect(users.updates.single.photo!.value, tinyPng);
  });
}
