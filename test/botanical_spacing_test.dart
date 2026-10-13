import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/widgets/seedly_botanical_background.dart';

void main() {
  testWidgets('Lower pot leaves more breathing room under the loading bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(350, 764);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const key = Key('botanical-art');
    await tester.pumpWidget(
      const RepaintBoundary(
        key: key,
        child: SizedBox(
          width: 350,
          height: 764,
          child: SeedlyBotanicalBackground(),
        ),
      ),
    );

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(key),
    );
    final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
    final bytes = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    final pixels = bytes!.buffer.asUint8List();

    bool hasStroke(int left, int top, int right, int bottom) {
      for (var y = top; y < bottom; y++) {
        for (var x = left; x < right; x++) {
          if (pixels[(y * image!.width + x) * 4 + 3] > 0) return true;
        }
      }
      return false;
    }

    expect(hasStroke(230, 550, 350, 600), isFalse);
    expect(hasStroke(230, 690, 350, 725), isTrue);
    image!.dispose();
  });

  testWidgets('Leaf beside Seedly stays farther outside the left edge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(350, 764);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const key = Key('botanical-art');
    await tester.pumpWidget(
      const RepaintBoundary(
        key: key,
        child: SizedBox(
          width: 350,
          height: 764,
          child: SeedlyBotanicalBackground(),
        ),
      ),
    );

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(key),
    );
    final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
    final bytes = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    final pixels = bytes!.buffer.asUint8List();

    bool hasStroke(int left, int top, int right, int bottom) {
      for (var y = top; y < bottom; y++) {
        for (var x = left; x < right; x++) {
          if (pixels[(y * image!.width + x) * 4 + 3] > 0) return true;
        }
      }
      return false;
    }

    expect(hasStroke(44, 440, 90, 550), isFalse);
    expect(hasStroke(0, 440, 43, 550), isTrue);
    image!.dispose();
  });
}
