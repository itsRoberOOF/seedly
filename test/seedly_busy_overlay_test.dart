import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/theme/seedly_theme.dart';
import 'package:seedly/widgets/seedly_busy_overlay.dart';

Widget _host({required VoidCallback onTapBehind}) => MaterialApp(
  theme: SeedlyTheme.light,
  home: Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: TextButton(
            onPressed: onTapBehind,
            child: const Text('Detrás'),
          ),
        ),
        const SeedlyBusyOverlay(label: 'Cerrando sesión…'),
      ],
    ),
  ),
);

void main() {
  testWidgets('shows a spinner with its label over everything', (tester) async {
    await tester.pumpWidget(_host(onTapBehind: () {}));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Cerrando sesión…'), findsOneWidget);
    expect(
      tester.getSize(find.byType(SeedlyBusyOverlay)),
      tester.view.physicalSize / tester.view.devicePixelRatio,
    );
  });

  testWidgets('takes the touches meant for what is behind it', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(onTapBehind: () => taps++));

    await tester.tap(find.text('Detrás'), warnIfMissed: false);
    await tester.pump();

    expect(taps, 0);
  });

  testWidgets('is announced once, as its label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(onTapBehind: () {}));

    expect(find.bySemanticsLabel('Cerrando sesión…'), findsOneWidget);
    handle.dispose();
  });
}
