import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/theme/seedly_theme.dart';
import 'package:seedly/widgets/seedly_empty_card.dart';

Widget _host(Widget child, {double width = 376}) => MaterialApp(
  theme: SeedlyTheme.light,
  home: Scaffold(
    body: Center(
      child: SizedBox(width: width, child: child),
    ),
  ),
);

Color? _tileColor(WidgetTester tester) => tester
    .widgetList<Container>(
      find.descendant(
        of: find.byType(SeedlyEmptyCard),
        matching: find.byType(Container),
      ),
    )
    .map((container) => container.decoration)
    .whereType<BoxDecoration>()
    .first
    .color;

void main() {
  testWidgets('is as tall as an info card and says what to do', (tester) async {
    await tester.pumpWidget(
      _host(
        const SeedlyEmptyCard(
          title: 'Sin pendientes',
          helper: '¿Tienes algo en mente? Crea una tarea',
        ),
      ),
    );

    expect(tester.getSize(find.byType(SeedlyEmptyCard)), const Size(376, 72));
    expect(find.text('Sin pendientes'), findsOneWidget);
    expect(find.text('¿Tienes algo en mente? Crea una tarea'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Sin pendientes')).style!.fontSize,
      16,
    );
  });

  testWidgets('draws a dashed outline instead of a solid one', (tester) async {
    await tester.pumpWidget(
      _host(const SeedlyEmptyCard(title: 'Título', helper: 'Ayuda')),
    );

    final paint = tester.widget<CustomPaint>(
      find
          .descendant(
            of: find.byType(SeedlyEmptyCard),
            matching: find.byType(CustomPaint),
          )
          .first,
    );
    expect(paint.foregroundPainter, isNotNull);
    expect(
      paint.foregroundPainter!.shouldRepaint(paint.foregroundPainter!),
      isFalse,
    );
    // No shadow, unlike the filled cards.
    expect(
      find.descendant(
        of: find.byType(SeedlyEmptyCard),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              (widget.decoration as BoxDecoration).boxShadow != null,
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('the tile is pale green with a plus, or green with a tick', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const SeedlyEmptyCard(title: 'Título', helper: 'Ayuda')),
    );
    expect(_tileColor(tester), SeedlyPalette.primary[50]);

    await tester.pumpWidget(
      _host(
        const SeedlyEmptyCard(title: 'Título', helper: 'Ayuda', done: true),
      ),
    );
    expect(_tileColor(tester), SeedlyPalette.primary[500]);
  });

  testWidgets('with a tap it is a button ending in an arrow', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        SeedlyEmptyCard(title: 'Título', helper: 'Ayuda', onTap: () => taps++),
      ),
    );

    // The tile's icon and the arrow.
    expect(find.byType(SvgPicture), findsNWidgets(2));
    await tester.tap(find.text('Título'));
    expect(taps, 1);

    final handle = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.byType(SeedlyEmptyCard)),
      isSemantics(isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });

  testWidgets('without a tap there is no arrow and it is not a button', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const SeedlyEmptyCard(title: 'Título', helper: 'Ayuda')),
    );

    expect(find.byType(SvgPicture), findsOneWidget);
    final handle = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.byType(SeedlyEmptyCard)),
      isNot(isSemantics(isButton: true)),
    );
    handle.dispose();
  });

  testWidgets(
    'superior text is in capitals above the title, without a helper',
    (tester) async {
      await tester.pumpWidget(
        _host(
          const SeedlyEmptyCard(
            superior: 'Enfoque de hoy',
            title: '¿Qué quieres lograr hoy?',
          ),
        ),
      );

      final superior = tester.widget<Text>(find.text('ENFOQUE DE HOY'));
      expect(superior.style!.fontSize, 12);
      expect(superior.style!.letterSpacing, 2);
      expect(
        tester.getTopLeft(find.text('ENFOQUE DE HOY')).dy,
        lessThan(tester.getTopLeft(find.text('¿Qué quieres lograr hoy?')).dy),
      );
      // The same 72px as the filled focus card, which also has no helper.
      expect(tester.getSize(find.byType(SeedlyEmptyCard)).height, 72);
    },
  );

  testWidgets('long texts are cut to one line', (tester) async {
    await tester.pumpWidget(
      _host(
        const SeedlyEmptyCard(
          title: 'Un título larguísimo que no cabe en una tarjeta estrecha',
          helper:
              'Una ayuda larguísima que tampoco cabe en la tarjeta estrecha',
        ),
        width: 260,
      ),
    );

    expect(tester.getSize(find.byType(SeedlyEmptyCard)), const Size(260, 72));
    expect(tester.takeException(), isNull);
  });
}
