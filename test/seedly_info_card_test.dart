import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/theme/seedly_theme.dart';
import 'package:seedly/widgets/seedly_info_card.dart';
import 'package:seedly/widgets/seedly_progress_circle.dart';

const _icon = 'assets/images/project_hogar.svg';

Widget _host(Widget child, {double width = 376}) => MaterialApp(
  theme: SeedlyTheme.light,
  home: Scaffold(
    body: Center(
      child: SizedBox(width: width, child: child),
    ),
  ),
);

void main() {
  testWidgets('a default card is Figma\'s 72px row with the title only', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const SeedlyInfoCard(icon: _icon, title: 'Avanzar Framer')),
    );

    expect(tester.getSize(find.byType(SeedlyInfoCard)), const Size(376, 72));
    expect(find.text('Avanzar Framer'), findsOneWidget);
    // Only the icon tile's SVG: no arrow, no ring.
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.byType(SeedlyProgressCircle), findsNothing);
  });

  testWidgets('superior text is shown in capitals above the title', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const SeedlyInfoCard(
          icon: _icon,
          title: 'Hacer sistema de diseño',
          superior: 'Enfoque de hoy',
        ),
      ),
    );

    final superior = tester.widget<Text>(find.text('ENFOQUE DE HOY'));
    expect(superior.style!.fontSize, 12);
    expect(superior.style!.letterSpacing, 2);
    expect(superior.style!.fontWeight, FontWeight.w500);
    expect(
      tester.getTopLeft(find.text('ENFOQUE DE HOY')).dy,
      lessThan(tester.getTopLeft(find.text('Hacer sistema de diseño')).dy),
    );
    // Figma's text frame is 44px (16 + 4 + 24) inside the 72px card.
    expect(tester.getSize(find.byType(SeedlyInfoCard)).height, 72);
  });

  testWidgets('helper text sits small and grey under the title', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const SeedlyInfoCard(
          icon: _icon,
          title: 'Avanzar Framer',
          helper: 'Hoy • 10:00 AM',
        ),
      ),
    );

    final helper = tester.widget<Text>(find.text('Hoy • 10:00 AM'));
    expect(helper.style!.fontSize, 10);
    expect(helper.style!.color, SeedlyPalette.neutral[600]);
    expect(
      tester.getTopLeft(find.text('Hoy • 10:00 AM')).dy,
      greaterThan(tester.getTopLeft(find.text('Avanzar Framer')).dy),
    );
    // Figma's text frame is 42px (24 + 4 + 14) inside the 72px card.
    expect(tester.getSize(find.byType(SeedlyInfoCard)).height, 72);
  });

  testWidgets('With icon ends in an arrow and With progress in a ring', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const SeedlyInfoCard(icon: _icon, title: 'Tarea', showArrow: true)),
    );
    expect(find.byType(SvgPicture), findsNWidgets(2));

    await tester.pumpWidget(
      _host(
        const SeedlyInfoCard(icon: _icon, title: 'Proyecto', progress: 0.5),
      ),
    );
    expect(find.byType(SeedlyProgressCircle), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
  });

  testWidgets('a card cannot end in both an arrow and a ring', (tester) async {
    expect(
      () => SeedlyInfoCard(
        icon: _icon,
        title: 'Proyecto',
        progress: 0.5,
        showArrow: true,
      ),
      throwsAssertionError,
    );
  });

  testWidgets('a long title is cut to one line in a 260px scroll card', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const SeedlyInfoCard(
          icon: _icon,
          title: 'Un título larguísimo que no cabe en una tarjeta de 260px',
          helper: 'Hoy',
        ),
        width: 260,
      ),
    );

    expect(tester.getSize(find.byType(SeedlyInfoCard)), const Size(260, 72));
    final title = tester.widget<Text>(find.textContaining('Un título'));
    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);
  });

  testWidgets('is a button only when it can be tapped', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(SeedlyInfoCard(icon: _icon, title: 'Tarea', onTap: () => taps++)),
    );
    await tester.tap(find.text('Tarea'));
    expect(taps, 1);

    final handle = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.byType(SeedlyInfoCard)),
      isSemantics(isButton: true, hasTapAction: true, label: 'Tarea'),
    );
    handle.dispose();
  });
}
