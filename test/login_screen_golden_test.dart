import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/screens/seedly_login_screen.dart';
import 'package:seedly/theme/seedly_theme.dart';

import 'support/fake_seedly_auth_repository.dart';
import 'support/fake_seedly_project_repository.dart';
import 'support/fake_seedly_user_repository.dart';

void main() {
  testWidgets('Login screen at Figma phone size', (tester) async {
    await (FontLoader('Plus Jakarta Sans')..addFont(
          rootBundle.load(
            'assets/fonts/plus_jakarta_sans/PlusJakartaSans-Variable.ttf',
          ),
        ))
        .load();
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: SeedlyTheme.light,
        home: SeedlyLoginScreen(
          auth: FakeSeedlyAuthRepository(),
          projects: FakeSeedlyProjectRepository(),
          users: FakeSeedlyUserRepository(),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../docs/login_screen.png'),
    );
  });

  testWidgets('Login screen fits a standard phone', (tester) async {
    await (FontLoader('Plus Jakarta Sans')..addFont(
          rootBundle.load(
            'assets/fonts/plus_jakarta_sans/PlusJakartaSans-Variable.ttf',
          ),
        ))
        .load();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: SeedlyTheme.light,
        home: SeedlyLoginScreen(
          auth: FakeSeedlyAuthRepository(),
          projects: FakeSeedlyProjectRepository(),
          users: FakeSeedlyUserRepository(),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../docs/login_screen_390.png'),
    );
  });
}
