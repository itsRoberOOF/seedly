import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/theme/seedly_theme.dart';
import 'package:seedly/widgets/seedly_checkbox.dart';

Widget _host(Widget child) => MaterialApp(
  theme: SeedlyTheme.light,
  home: Scaffold(body: Center(child: child)),
);

BoxDecoration _box(WidgetTester tester) =>
    tester
            .widget<AnimatedContainer>(
              find.descendant(
                of: find.byType(SeedlyCheckboxBox),
                matching: find.byType(AnimatedContainer),
              ),
            )
            .decoration!
        as BoxDecoration;

void main() {
  final brand = SeedlyPalette.primary[500];

  testWidgets('box states match Figma', (tester) async {
    await tester.pumpWidget(_host(const SeedlyCheckboxBox(value: false)));
    expect((_box(tester).border! as Border).top.color, brand);
    expect(_box(tester).color, isNull);

    await tester.pumpWidget(
      _host(const SeedlyCheckboxBox(value: false, placeholder: true)),
    );
    expect(
      (_box(tester).border! as Border).top.color,
      SeedlyPalette.neutral[500],
    );

    await tester.pumpWidget(
      _host(const SeedlyCheckboxBox(value: false, hovered: true)),
    );
    expect(_box(tester).color, SeedlyPalette.primary[50]);

    await tester.pumpWidget(_host(const SeedlyCheckboxBox(value: true)));
    await tester.pumpAndSettle();
    expect(_box(tester).color, brand);
    expect(_box(tester).border, isNull);
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('the icon checkbox toggles with a 48px tap target', (
    tester,
  ) async {
    var value = false;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => SeedlyCheckbox(
            value: value,
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(SeedlyCheckbox)), const Size(48, 48));
    await tester.tap(find.byType(SeedlyCheckbox));
    await tester.pump();
    expect(value, isTrue);
    await tester.tap(find.byType(SeedlyCheckbox));
    await tester.pump();
    expect(value, isFalse);
  });

  testWidgets('a disabled checkbox ignores taps', (tester) async {
    await tester.pumpWidget(
      _host(const SeedlyCheckbox(value: false, onChanged: null)),
    );
    final ink = tester.widget<InkResponse>(
      find.descendant(
        of: find.byType(SeedlyCheckbox),
        matching: find.byType(InkResponse),
      ),
    );
    expect(ink.onTap, isNull);
    // No hover fill either.
    expect(_box(tester).color, isNull);
  });

  testWidgets('tile shows the time until checked, then greys the label', (
    tester,
  ) async {
    var value = false;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => SizedBox(
            width: 250,
            child: SeedlyCheckboxTile(
              label: 'Diseño de frontend',
              time: '2:00 PM',
              value: value,
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      ),
    );
    expect(find.text('2:00 PM'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Diseño de frontend')).style?.color,
      SeedlyPalette.neutral[850],
    );
    // The whole row is tappable, not only the box.
    await tester.tap(find.text('Diseño de frontend'));
    await tester.pumpAndSettle();
    expect(value, isTrue);
    expect(find.text('2:00 PM'), findsNothing);
    expect(
      tester.widget<Text>(find.text('Diseño de frontend')).style?.color,
      SeedlyPalette.neutral[600],
    );
  });

  testWidgets('a checked card turns grey and flat', (tester) async {
    BoxDecoration card() =>
        tester
                .widget<AnimatedContainer>(
                  find
                      .descendant(
                        of: find.byType(SeedlyCheckboxCard),
                        matching: find.byType(AnimatedContainer),
                      )
                      .first,
                )
                .decoration!
            as BoxDecoration;

    var more = 0;
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 250,
          child: SeedlyCheckboxCard(
            label: 'Hacer guía 6',
            value: false,
            onChanged: (_) {},
            actions: [SeedlyCardAction('Editar', () => more++)],
          ),
        ),
      ),
    );
    expect(card().color, SeedlyPalette.neutral[50]);
    expect(card().boxShadow, SeedlyShadows.card);
    await tester.tap(find.byTooltip('Más opciones'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    expect(more, 1);

    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 250,
          child: SeedlyCheckboxCard(
            label: 'Hacer guía 6',
            value: true,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(card().color, SeedlyPalette.neutral[200]);
    expect(card().border, isNull);
    expect(card().boxShadow, isNull);
  });
}
