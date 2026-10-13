import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/theme/seedly_theme.dart';
import 'package:seedly/widgets/seedly_date_picker.dart';

final _today = DateTime(2026, 10, 12);

Future<List<DateTime>> _pump(
  WidgetTester tester, {
  DateTime? selected,
  DateTime? firstDate,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final picked = <DateTime>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: SeedlyTheme.light,
      home: Scaffold(
        body: SeedlyDatePicker(
          selected: selected,
          firstDate: firstDate,
          today: _today,
          onChanged: picked.add,
        ),
      ),
    ),
  );
  return picked;
}

BoxDecoration? _cellDecoration(WidgetTester tester, String day) {
  final cell = find.descendant(
    of: find.bySemanticsLabel(day),
    matching: find.byType(Container),
  );
  return tester.widget<Container>(cell.first).decoration as BoxDecoration?;
}

void main() {
  testWidgets('weeks start on Sunday with six full rows', (tester) async {
    await _pump(tester);
    expect(find.text('Octubre 2026'), findsOneWidget);
    // 1 Oct 2026 is a Thursday, so the grid opens on Sunday 27 Sep.
    final firstCell = tester.getTopLeft(find.bySemanticsLabel('27 sep 2026'));
    expect(
      firstCell.dx,
      lessThan(tester.getTopLeft(find.bySemanticsLabel('28 sep 2026')).dx),
    );
    expect(find.bySemanticsLabel('7 nov 2026'), findsOneWidget);
  });

  testWidgets('the arrows change month', (tester) async {
    await _pump(tester);
    await tester.tap(find.byTooltip('Mes siguiente'));
    await tester.pump();
    expect(find.text('Noviembre 2026'), findsOneWidget);
    await tester.tap(find.byTooltip('Mes anterior'));
    await tester.tap(find.byTooltip('Mes anterior'));
    await tester.pump();
    expect(find.text('Septiembre 2026'), findsOneWidget);
  });

  testWidgets('days and months before firstDate are out of reach', (
    tester,
  ) async {
    final picked = await _pump(tester, firstDate: DateTime(2026, 10, 15));
    await tester.tap(find.bySemanticsLabel('14 oct 2026'));
    await tester.tap(find.bySemanticsLabel('15 oct 2026'));
    expect(picked, [DateTime(2026, 10, 15)]);
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip('Mes anterior'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('today is outlined and the selection filled green', (
    tester,
  ) async {
    await _pump(tester, selected: DateTime(2026, 10, 16));
    final brand = SeedlyPalette.primary[500];
    final today = _cellDecoration(tester, '12 oct 2026')!;
    expect(today.color, SeedlyPalette.primary[50]);
    expect((today.border! as Border).top.color, brand);
    final selected = _cellDecoration(tester, '16 oct 2026')!;
    expect(selected.color, brand);
    expect(selected.border, isNull);
    expect(_cellDecoration(tester, '20 oct 2026')?.color, isNull);
  });
}
