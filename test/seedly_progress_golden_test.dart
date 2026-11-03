import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/screens/seedly_progress_view.dart';
import 'package:seedly/theme/seedly_theme.dart';

import 'support/fake_seedly_drops_repository.dart';
import 'support/keep_plant_still.dart';

Future<void> _open(WidgetTester tester, FakeSeedlyDropsRepository drops) async {
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
      theme: SeedlyTheme.light,
      home: SeedlyProgressView(drops: drops),
    ),
  );
  await tester.pump();
  // SVG compilation finishes outside the fake test clock.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pump();
}

void main() {
  keepPlantStill();

  testWidgets('en camino', (tester) async {
    await _open(
      tester,
      FakeSeedlyDropsRepository(phase: 2, startingDrops: 300),
    );
    await expectLater(
      find.byType(SeedlyProgressView),
      matchesGoldenFile('goldens/progress_on_the_way.png'),
    );
  });

  testWidgets('lista para crecer', (tester) async {
    await _open(
      tester,
      FakeSeedlyDropsRepository(phase: 2, startingDrops: 500),
    );
    await expectLater(
      find.byType(SeedlyProgressView),
      matchesGoldenFile('goldens/progress_ready.png'),
    );
  });

  testWidgets('planta creció', (tester) async {
    final drops = FakeSeedlyDropsRepository(phase: 2, startingDrops: 500);
    await _open(tester, drops);
    await tester.tap(find.text('Haz crecer tu planta'));
    await tester.pump();
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    await expectLater(
      find.byType(SeedlyProgressView),
      matchesGoldenFile('goldens/progress_grown.png'),
    );
  });

  testWidgets('planta al máximo', (tester) async {
    await _open(
      tester,
      FakeSeedlyDropsRepository(phase: 4, startingDrops: 1240),
    );
    await expectLater(
      find.byType(SeedlyProgressView),
      matchesGoldenFile('goldens/progress_maximum.png'),
    );
  });
}
