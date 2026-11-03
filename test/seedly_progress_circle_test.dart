import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/theme/seedly_theme.dart';
import 'package:seedly/widgets/seedly_progress_circle.dart';

Widget _host(Widget child) => MaterialApp(
  theme: SeedlyTheme.light,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('is Figma\'s 36px ring with the percentage inside', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const SeedlyProgressCircle(progress: 0.5)));

    expect(
      tester.getSize(find.byType(SeedlyProgressCircle)),
      const Size(36, 36),
    );
    final text = tester.widget<Text>(find.text('50%'));
    expect(text.style!.fontSize, 10);
    expect(find.bySemanticsLabel('Avance 50%'), findsOneWidget);
  });

  testWidgets('rounds the percentage and clamps what is out of range', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const SeedlyProgressCircle(progress: 1 / 3)));
    expect(find.text('33%'), findsOneWidget);

    await tester.pumpWidget(_host(const SeedlyProgressCircle(progress: 1.5)));
    expect(find.text('100%'), findsOneWidget);

    await tester.pumpWidget(_host(const SeedlyProgressCircle(progress: -1)));
    expect(find.text('0%'), findsOneWidget);
  });

  testWidgets('repaints only when the progress changes', (tester) async {
    await tester.pumpWidget(_host(const SeedlyProgressCircle(progress: 0.25)));
    final first = tester
        .widget<CustomPaint>(
          find.descendant(
            of: find.byType(SeedlyProgressCircle),
            matching: find.byType(CustomPaint),
          ),
        )
        .painter!;

    await tester.pumpWidget(_host(const SeedlyProgressCircle(progress: 0.25)));
    final same = tester
        .widget<CustomPaint>(
          find.descendant(
            of: find.byType(SeedlyProgressCircle),
            matching: find.byType(CustomPaint),
          ),
        )
        .painter!;
    await tester.pumpWidget(_host(const SeedlyProgressCircle(progress: 0.75)));
    final other = tester
        .widget<CustomPaint>(
          find.descendant(
            of: find.byType(SeedlyProgressCircle),
            matching: find.byType(CustomPaint),
          ),
        )
        .painter!;

    expect(same.shouldRepaint(first), isFalse);
    expect(other.shouldRepaint(first), isTrue);
  });
}
