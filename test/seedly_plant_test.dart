import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/models/seedly_drops.dart';
import 'package:seedly/widgets/seedly_plant.dart';
import 'package:seedly/widgets/seedly_watering_rain.dart';

const _degree = math.pi / 180;

Widget _wrap(Widget child, {bool reduceMotion = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduceMotion),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: SizedBox(height: 500, child: child)),
  ),
);

/// Every SVG asset on screen, by name.
List<String> _assets(WidgetTester tester) => [
  for (final svg in tester.widgetList<SvgPicture>(find.byType(SvgPicture)))
    (svg.bytesLoader as SvgAssetLoader).assetName,
];

List<String> _plantAssets(WidgetTester tester) =>
    _assets(tester).where((a) => a.contains('plant_phase')).toList();

int _drops(WidgetTester tester) =>
    _assets(tester).where((a) => a == SeedlyWateringRain.dropAsset).length;

/// The sway transform applied to the plant.
Matrix4 _sway(WidgetTester tester) => tester
    .widget<Transform>(
      find
          .ancestor(
            of: find.byType(SvgPicture).first,
            matching: find.byType(Transform),
          )
          .first,
    )
    .transform;

void main() {
  group('seedlyPlantPose', () {
    void expectPose(SeedlyPlantPose pose, SeedlyPlantPose expected) {
      expect(pose.scaleX, closeTo(expected.scaleX, 1e-9));
      expect(pose.scaleY, closeTo(expected.scaleY, 1e-9));
      expect(pose.rotation, closeTo(expected.rotation, 1e-9));
      expect(pose.dy, closeTo(expected.dy, 1e-9));
    }

    test('hits the CSS keyframes', () {
      expectPose(seedlyPlantPose(0), (
        scaleX: 1,
        scaleY: 1,
        rotation: 0,
        dy: 0,
      ));
      expectPose(seedlyPlantPose(0.25), (
        scaleX: 1.018,
        scaleY: 1.026,
        rotation: 1.4 * _degree,
        dy: -3,
      ));
      expectPose(seedlyPlantPose(0.5), (
        scaleX: 1.01,
        scaleY: 1.038,
        rotation: 0,
        dy: -5,
      ));
      expectPose(seedlyPlantPose(0.75), (
        scaleX: 1.018,
        scaleY: 1.026,
        rotation: -1.4 * _degree,
        dy: -3,
      ));
    });

    test('loops without a jump', () {
      expectPose(seedlyPlantPose(1), seedlyPlantPose(0));
      expectPose(seedlyPlantPose(1.25), seedlyPlantPose(0.25));
      final end = seedlyPlantPose(0.9999);
      expect(end.rotation.abs(), lessThan(1e-4 * _degree));
      expect(end.dy.abs(), lessThan(1e-4));
    });

    test('sways the same to each side', () {
      // The second half mirrors the first: same stretch, opposite tilt.
      // Curves.easeInOut is solved numerically, so allow a hair of error.
      for (var i = 0; i <= 50; i++) {
        final first = seedlyPlantPose(i / 100);
        final mirror = seedlyPlantPose(1 - i / 100);
        expect(mirror.rotation, closeTo(-first.rotation, 1e-6));
        expect(mirror.scaleX, closeTo(first.scaleX, 1e-6));
        expect(mirror.scaleY, closeTo(first.scaleY, 1e-6));
        expect(mirror.dy, closeTo(first.dy, 1e-5));
      }
    });

    test('stays within the keyframe limits', () {
      for (var t = 0.0; t <= 1; t += 0.005) {
        final pose = seedlyPlantPose(t);
        expect(pose.scaleX, inInclusiveRange(1, 1.018));
        expect(pose.scaleY, inInclusiveRange(1, 1.038));
        expect(pose.rotation.abs(), lessThanOrEqualTo(1.4 * _degree + 1e-9));
        expect(pose.dy, inInclusiveRange(-5, 0));
      }
    });

    test('eases in and out of each keyframe', () {
      // Halfway between 0% and 25% in time, ease-in-out is halfway in value.
      expect(
        seedlyPlantPose(0.125).rotation,
        closeTo(0.7 * _degree, 1e-3 * _degree),
      );
      // Near a keyframe it barely moves.
      expect(seedlyPlantPose(0.01).rotation, lessThan(0.05 * _degree));
    });
  });

  group('SeedlyPlantPhase', () {
    test('has one look per phase of the drops system', () {
      expect(SeedlyPlantPhase.values, hasLength(SeedlyDrops.maxPhase));
      expect([for (final p in SeedlyPlantPhase.values) p.number], [1, 2, 3, 4]);
    });

    test('keeps out-of-range phases at the nearest look', () {
      expect(SeedlyPlantPhase.of(0), SeedlyPlantPhase.seed);
      expect(SeedlyPlantPhase.of(-3), SeedlyPlantPhase.seed);
      expect(SeedlyPlantPhase.of(3), SeedlyPlantPhase.young);
      expect(SeedlyPlantPhase.of(9), SeedlyPlantPhase.adult);
    });

    testWidgets('every look is a bundled SVG flutter_svg can draw', (
      tester,
    ) async {
      // Large assets load in an isolate, which the fake test clock never
      // waits for.
      await tester.runAsync(() async {
        for (final phase in SeedlyPlantPhase.values) {
          final svg = await rootBundle.loadString(phase.asset);
          expect(svg, contains('viewBox="0 0 292 500"'), reason: phase.asset);
          // flutter_svg ignores CSS: the motion lives in SeedlyPlant.
          expect(svg, isNot(contains('<style')), reason: phase.asset);
          // Compiling it is what drawing it needs; it throws on bad SVG.
          final bytes = await SvgAssetLoader(phase.asset).loadBytes(null);
          expect(bytes.lengthInBytes, greaterThan(0), reason: phase.asset);
        }
      });
    });
  });

  group('SeedlyPlant', () {
    testWidgets('shows the art of its phase and names it', (tester) async {
      for (final phase in SeedlyPlantPhase.values) {
        // A new key mounts each one fresh, without the grow transition.
        await tester.pumpWidget(
          _wrap(SeedlyPlant(key: ValueKey(phase), phase: phase.number)),
        );
        expect(_plantAssets(tester), [phase.asset]);
        expect(
          find.bySemanticsLabel(
            'Planta en fase ${phase.number}: ${phase.label}',
          ),
          findsOneWidget,
        );
      }
    });

    testWidgets('keeps the art proportions and pivots on the pot', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const SeedlyPlant(phase: 2)));
      expect(tester.getSize(find.byType(SeedlyPlant)), const Size(292, 500));
    });

    testWidgets('sways in a loop', (tester) async {
      await tester.pumpWidget(_wrap(const SeedlyPlant(phase: 4)));
      final start = _sway(tester).clone();

      await tester.pump(SeedlyPlant.swayDuration * 0.25);
      final quarter = _sway(tester).clone();
      expect(quarter, isNot(start));
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pump(SeedlyPlant.swayDuration * 0.75);
      expect(_sway(tester).storage, [
        for (final v in start.storage) moreOrLessEquals(v, epsilon: 1e-6),
      ]);
    });

    testWidgets('moves the plant up by SVG units scaled to its size', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const SeedlyPlant(phase: 4)));
      final plant = tester.getRect(find.byType(SeedlyPlant));
      await tester.pump(SeedlyPlant.swayDuration * 0.5);

      // At 50% the art moves 5 units up, then stretches 1.038 tall and
      // 1.01 wide from the pivot at y 490 of 500; drawn 500 px tall, a unit
      // is a pixel.
      final art = tester.getRect(find.byType(SvgPicture));
      expect(art.height, closeTo(500 * 1.038, 0.01));
      expect(art.width, closeTo(292 * 1.01, 0.01));
      expect(art.top, closeTo(plant.top + 490 - (490 + 5) * 1.038, 0.01));
      expect(art.center.dx, closeTo(plant.center.dx, 0.01));
    });

    testWidgets('a new phase grows in, then only it remains', (tester) async {
      await tester.pumpWidget(_wrap(const SeedlyPlant(phase: 1)));
      await tester.pumpWidget(_wrap(const SeedlyPlant(phase: 2)));
      await tester.pump(SeedlyPlant.growDuration * 0.5);
      expect(
        _plantAssets(tester),
        unorderedEquals([
          SeedlyPlantPhase.seed.asset,
          SeedlyPlantPhase.sprout.asset,
        ]),
      );

      await tester.pump(SeedlyPlant.growDuration);
      expect(_plantAssets(tester), [SeedlyPlantPhase.sprout.asset]);
    });

    testWidgets('rains only while watering', (tester) async {
      await tester.pumpWidget(_wrap(const SeedlyPlant(phase: 3)));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_drops(tester), 0);

      await tester.pumpWidget(
        _wrap(const SeedlyPlant(phase: 3, watering: true)),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(_drops(tester), greaterThan(0));
      expect(
        find.bySemanticsLabel('Planta en fase 3: Joven, regándose'),
        findsOneWidget,
      );

      await tester.pumpWidget(_wrap(const SeedlyPlant(phase: 3)));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_drops(tester), 0);
    });

    testWidgets('drops never fall past the soil', (tester) async {
      await tester.pumpWidget(
        _wrap(const SeedlyPlant(phase: 2, watering: true)),
      );
      final plant = tester.getRect(find.byType(SeedlyPlant));
      final soil = plant.top + plant.height * SeedlyWateringRain.soilLine;
      for (var frame = 0; frame < 40; frame++) {
        await tester.pump(SeedlyWateringRain.duration ~/ 40);
        for (final drop
            in find
                .byWidgetPredicate(
                  (w) =>
                      w is SvgPicture &&
                      (w.bytesLoader as SvgAssetLoader).assetName ==
                          SeedlyWateringRain.dropAsset,
                )
                .evaluate()) {
          final box = drop.renderObject! as RenderBox;
          final bottom = box.localToGlobal(box.size.bottomLeft(Offset.zero)).dy;
          expect(bottom, lessThanOrEqualTo(soil + 0.5));
        }
      }
    });

    testWidgets('with reduce motion it stands still and no rain falls', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const SeedlyPlant(phase: 3, watering: true), reduceMotion: true),
      );
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pump(const Duration(seconds: 2));
      expect(_sway(tester), Matrix4.identity());
      expect(_drops(tester), 0);

      // A new phase appears at once.
      await tester.pumpWidget(
        _wrap(const SeedlyPlant(phase: 4, watering: true), reduceMotion: true),
      );
      await tester.pump();
      expect(_plantAssets(tester), [SeedlyPlantPhase.adult.asset]);
    });

    testWidgets('turning reduce motion off starts the sway', (tester) async {
      await tester.pumpWidget(
        _wrap(const SeedlyPlant(phase: 1), reduceMotion: true),
      );
      expect(tester.hasRunningAnimations, isFalse);

      await tester.pumpWidget(_wrap(const SeedlyPlant(phase: 1)));
      expect(tester.hasRunningAnimations, isTrue);
    });
  });
}
