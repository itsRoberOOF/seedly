import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/screens/seedly_home_screen.dart';
import 'package:seedly/models/seedly_user_profile.dart';
import 'package:seedly/screens/seedly_login_screen.dart';
import 'package:seedly/screens/seedly_profile_view.dart';
import 'package:seedly/theme/seedly_theme.dart';
import 'package:seedly/widgets/seedly_avatar.dart';
import 'package:seedly/widgets/seedly_button.dart';
import 'package:seedly/widgets/seedly_input.dart';
import 'package:seedly/widgets/seedly_menu.dart';

import 'support/fake_seedly_auth_repository.dart';
import 'support/fake_seedly_image_picker.dart';
import 'support/fake_seedly_project_repository.dart';
import 'support/fake_seedly_user_repository.dart';

Future<FakeSeedlyAuthRepository> _openProfile(
  WidgetTester tester, {
  Size size = const Size(440, 956),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
  final auth = FakeSeedlyAuthRepository(
    isSignedIn: true,
    displayName: 'Rober Morán',
    email: 'robermoran28@gmail.com',
  );
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
  await tester.tap(
    find.descendant(
      of: find.byType(SeedlyMenu),
      matching: find.text('Mi perfil'),
    ),
  );
  await tester.pump();
  return auth;
}

ScrollableState _scrollable(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable).first);

Widget _wrap(Widget child) => MaterialApp(
  theme: SeedlyTheme.light,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('shows the account and every label', (tester) async {
    await _openProfile(tester);

    for (final text in [
      'INFORMACIÓN',
      'Nombre',
      'Correo electrónico',
      'Usuario',
      'Bio',
      'CUENTA',
      'Cerrar sesión',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    // Title and menu entry.
    expect(find.text('Mi perfil'), findsNWidgets(2));
    expect(find.text('Rober Morán'), findsOneWidget);
    expect(find.text('robermoran28@gmail.com'), findsOneWidget);
  });

  testWidgets('Usuario and Bio are editable, Nombre and Correo are not', (
    tester,
  ) async {
    await _openProfile(tester);

    expect(find.text('Tu usuario'), findsOneWidget);
    expect(find.text('Cuéntanos sobre ti'), findsOneWidget);
    final fields = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .toList();
    expect(fields, hasLength(4));
    expect(fields.map((field) => field.readOnly), [true, true, false, false]);
  });

  testWidgets('fits 440x956 without scrolling', (tester) async {
    await _openProfile(tester);

    expect(tester.takeException(), isNull);
    expect(_scrollable(tester).position.maxScrollExtent, 0);
  });

  testWidgets('scrolls to the sign-out button at 320x640', (tester) async {
    await _openProfile(tester, size: const Size(320, 640));

    expect(tester.takeException(), isNull);
    expect(_scrollable(tester).position.maxScrollExtent, greaterThan(0));
    await tester.ensureVisible(find.text('Cerrar sesión'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    final bottom = tester.getBottomLeft(find.byType(SeedlyButton)).dy;
    expect(bottom, lessThanOrEqualTo(640));
  });

  testWidgets('stays usable with the keyboard open', (tester) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await _openProfile(tester, size: const Size(390, 844));

    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Cerrar sesión'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Cerrar sesión'), findsOneWidget);
  });

  testWidgets('the edit button opens the photo modal', (tester) async {
    await _openProfile(tester);

    await tester.tap(find.byTooltip('Cambiar imagen'));
    await tester.pumpAndSettle();

    expect(find.text('Foto de perfil'), findsOneWidget);
    expect(find.text('Elegir imagen'), findsOneWidget);
  });

  testWidgets('Cerrar sesión signs out and returns to the login', (
    tester,
  ) async {
    final auth = await _openProfile(tester);

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(auth.signOutCalls, 1);
    expect(find.byType(SeedlyLoginScreen), findsOneWidget);
  });

  testWidgets('SeedlyButton paints its border and text with color', (
    tester,
  ) async {
    const red = Color(0xFFD92D20);
    await tester.pumpWidget(
      _wrap(
        SeedlyButton(
          label: 'Borrar',
          variant: SeedlyButtonVariant.outline,
          color: red,
          onPressed: () {},
        ),
      ),
    );

    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(button.style!.side!.resolve({})!.color, red);
    expect(button.style!.foregroundColor!.resolve({}), red);
  });

  testWidgets('SeedlyAvatar honours size', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SeedlyAvatar(icon: 'assets/images/menu_profile.svg', size: 140),
      ),
    );
    expect(tester.getSize(find.byType(SeedlyAvatar)), const Size(140, 140));

    await tester.pumpWidget(
      _wrap(
        SeedlyAvatar(
          icon: 'assets/images/menu_profile.svg',
          size: 140,
          onEdit: () {},
        ),
      ),
    );
    expect(tester.getSize(find.byType(SeedlyAvatar)), const Size(140, 140));
  });

  testWidgets('a read-only SeedlyInput ignores typing', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SeedlyInput(
          label: 'Nombre',
          hint: 'Tu nombre',
          readOnly: true,
          initialValue: 'Ana',
        ),
      ),
    );

    await tester.enterText(find.byType(EditableText), 'Otro');
    await tester.pump();

    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Otro'), findsNothing);
  });

  testWidgets('rebuilding the profile view with another name updates Nombre', (
    tester,
  ) async {
    Widget view(String name) => _wrap(
      SizedBox(
        height: 900,
        child: SeedlyProfileView(
          profile: SeedlyUserProfile(
            uid: 'u1',
            email: 'ana@example.com',
            displayName: name,
            createdAt: DateTime(2026),
          ),
          users: FakeSeedlyUserRepository(),
          picker: FakeSeedlyImagePicker(),
          onSignOut: () {},
        ),
      ),
    );
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(view('Ana'));
    expect(find.text('Ana'), findsOneWidget);

    await tester.pumpWidget(view('Ana Nueva'));

    expect(find.text('Ana Nueva'), findsOneWidget);
    expect(find.text('Ana'), findsNothing);
  });

  testWidgets('SeedlyInput renders a prefix icon and a fixed height', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SeedlyInput(
                label: 'Usuario',
                hint: 'Tu usuario',
                prefixAsset: 'assets/images/profile_at_sign.svg',
              ),
              SeedlyInput(
                label: 'Bio',
                hint: 'Cuéntanos sobre ti',
                fieldHeight: 86,
                suffixAsset: 'assets/images/profile_expand.svg',
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(SvgPicture), findsNWidgets(2));
    final bio = find.ancestor(
      of: find.text('Cuéntanos sobre ti'),
      matching: find.byType(SizedBox),
    );
    expect(
      tester.getSize(bio.first).height == 86 ||
          tester.getSize(bio.at(1)).height == 86,
      isTrue,
    );
  });
}
