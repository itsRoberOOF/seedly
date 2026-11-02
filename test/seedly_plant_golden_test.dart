import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/widgets/seedly_plant.dart';

void main() {
  testWidgets('the four phases, still', (tester) async {
    tester.view.physicalSize = const Size(4 * 146 + 5 * 8, 250 + 16);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        // Still, so every run captures the same frame.
        data: const MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: ColoredBox(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final phase in SeedlyPlantPhase.values)
                    SizedBox(
                      height: 250,
                      child: SeedlyPlant(phase: phase.number),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    // The SVGs compile in an isolate, outside the fake test clock.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );
    await tester.pump();

    await expectLater(
      find.byType(ColoredBox).first,
      matchesGoldenFile('goldens/plant_phases.png'),
    );
  });
}
