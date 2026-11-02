import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/theme/seedly_theme.dart';
import 'package:seedly/widgets/seedly_tag.dart';

Widget _host(Widget child) => MaterialApp(
  theme: SeedlyTheme.light,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('the medium tag is Figma\'s 14px pill', (tester) async {
    await tester.pumpWidget(_host(SeedlyTag(label: 'Hoy', onTap: () {})));

    final text = tester.widget<Text>(find.text('Hoy'));
    expect(text.style!.fontSize, 14);
    expect(tester.getSize(find.byType(SeedlyTag)).height, 20 + 2 * 12);
    expect(find.byType(SvgPicture), findsNothing);
  });

  testWidgets('the small tag with an icon is Figma\'s 36px drops tag', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        SeedlyTag(
          label: '350',
          size: SeedlyTagSize.small,
          icon: 'assets/images/icon_raindrop.svg',
          onTap: () {},
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('350'));
    expect(text.style!.fontSize, 12);
    // 8 above and below the 16px label.
    expect(tester.getSize(find.byType(SvgPicture)), const Size(20, 20));
    expect(tester.getSize(find.byType(SeedlyTag)).height, 36);
  });

  testWidgets('a screen reader hears the semantic label, and taps work', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        SeedlyTag(
          label: '350',
          semanticLabel: '350 gotas',
          onTap: () => taps++,
        ),
      ),
    );

    expect(find.bySemanticsLabel('350 gotas'), findsOneWidget);
    await tester.tap(find.byType(SeedlyTag));
    expect(taps, 1);
  });
}
