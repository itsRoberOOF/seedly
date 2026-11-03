import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/theme/seedly_theme.dart';
import 'package:seedly/widgets/seedly_plant.dart';
import 'package:seedly/widgets/seedly_plant_blob.dart';

import 'support/keep_plant_still.dart';

Widget _host(Widget child) => MaterialApp(
  theme: SeedlyTheme.light,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  keepPlantStill();

  testWidgets('is Figma\'s 300×331 Planta frame', (tester) async {
    await tester.pumpWidget(_host(const SeedlyPlantBlob(phase: 1)));

    expect(tester.getSize(find.byType(SeedlyPlantBlob)), const Size(300, 331));
  });

  testWidgets('the 303px mascot stands 14px from the top, centred', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const SeedlyPlantBlob(phase: 2)));

    final frame = tester.getRect(find.byType(SeedlyPlantBlob));
    final mascot = tester.getRect(find.byType(SeedlyPlant));
    expect(mascot.top, frame.top + 14);
    expect(mascot.height, 303);
    expect(mascot.center.dx, frame.center.dx);
    expect(tester.widget<SeedlyPlant>(find.byType(SeedlyPlant)).phase, 2);
  });

  testWidgets('scale shrinks the frame and the mascot together', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const SeedlyPlantBlob(phase: 1, scale: 0.5)));

    expect(
      tester.getSize(find.byType(SeedlyPlantBlob)),
      const Size(150, 165.5),
    );
    final frame = tester.getRect(find.byType(SeedlyPlantBlob));
    final mascot = tester.getRect(find.byType(SeedlyPlant));
    expect(mascot.top, frame.top + 7);
    expect(mascot.height, 151.5);
    expect(mascot.center.dx, frame.center.dx);
  });

  test('a frame cannot have no size', () {
    expect(() => SeedlyPlantBlob(phase: 1, scale: 0), throwsAssertionError);
  });

  testWidgets('passes watering to the plant', (tester) async {
    await tester.pumpWidget(
      _host(const SeedlyPlantBlob(phase: 1, watering: true)),
    );

    expect(
      tester.widget<SeedlyPlant>(find.byType(SeedlyPlant)).watering,
      isTrue,
    );
  });
}
