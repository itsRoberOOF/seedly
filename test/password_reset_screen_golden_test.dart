import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/screens/seedly_password_reset_screen.dart';
import 'package:seedly/theme/seedly_theme.dart';

import 'support/fake_seedly_auth_repository.dart';

void main() {
  testWidgets('Password reset screen at Figma phone size', (tester) async {
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
        home: SeedlyPasswordResetScreen(auth: FakeSeedlyAuthRepository()),
      ),
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../docs/password_reset_screen.png'),
    );
  });
}
