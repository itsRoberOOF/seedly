import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/main.dart';

import 'support/fake_seedly_auth_repository.dart';
import 'support/fake_seedly_drops_repository.dart';
import 'support/fake_seedly_project_repository.dart';

void main() {
  testWidgets('Initial screen at phone size', (tester) async {
    await (FontLoader('Plus Jakarta Sans')..addFont(
          rootBundle.load(
            'assets/fonts/plus_jakarta_sans/PlusJakartaSans-Variable.ttf',
          ),
        ))
        .load();
    await (FontLoader('Denk One')..addFont(
          rootBundle.load('assets/fonts/denk_one/DenkOne-Regular.ttf'),
        ))
        .load();

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MyApp(
        auth: FakeSeedlyAuthRepository(),
        projects: FakeSeedlyProjectRepository(),
        drops: FakeSeedlyDropsRepository(),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/initial_screen.png'),
    );
  });
}
