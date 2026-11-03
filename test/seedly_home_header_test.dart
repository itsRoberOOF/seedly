import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/theme/seedly_theme.dart';
import 'package:seedly/widgets/seedly_avatar.dart';
import 'package:seedly/widgets/seedly_home_header.dart';
import 'package:seedly/widgets/seedly_tag.dart';

Widget _host(Widget child) => MaterialApp(
  theme: SeedlyTheme.light,
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(32), child: child),
  ),
);

void main() {
  testWidgets('greets by first name beside a 56px avatar', (tester) async {
    await tester.pumpWidget(
      _host(const SeedlyHomeHeader(name: 'Rober', initials: 'RM', drops: 350)),
    );

    expect(find.text('Hola, Rober'), findsOneWidget);
    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
    expect(find.text('RM'), findsOneWidget);
    expect(tester.getSize(find.byType(SeedlyAvatar)), const Size(56, 56));
    expect(tester.widget<SeedlyAvatar>(find.byType(SeedlyAvatar)).padding, 4);
    expect(tester.getSize(find.byType(SeedlyHomeHeader)).height, 56);
  });

  testWidgets('without a name the greeting stands alone', (tester) async {
    await tester.pumpWidget(
      _host(const SeedlyHomeHeader(initials: 'A', drops: 0)),
    );
    expect(find.text('Hola'), findsOneWidget);

    await tester.pumpWidget(
      _host(const SeedlyHomeHeader(name: '', initials: 'A', drops: 0)),
    );
    expect(find.text('Hola'), findsOneWidget);
  });

  testWidgets('the drops tag is small, with the drop, at the right', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const SeedlyHomeHeader(name: 'Ana', initials: 'A', drops: 350)),
    );

    final tag = tester.widget<SeedlyTag>(find.byType(SeedlyTag));
    expect(tag.size, SeedlyTagSize.small);
    expect(tag.icon, 'assets/images/icon_raindrop.svg');
    expect(tag.label, '350');
    expect(find.bySemanticsLabel('350 gotas'), findsOneWidget);
    // Figma: the tag is 36 tall at the header's right edge, centred in 56.
    // Its width follows the label, which the test font sets wider.
    final header = tester.getRect(find.byType(SeedlyHomeHeader));
    final rect = tester.getRect(find.byType(SeedlyTag));
    expect(rect.right, header.right);
    expect(rect.center.dy, header.center.dy);
    expect(rect.height, 36);
  });

  testWidgets('one drop is "1 gota"', (tester) async {
    await tester.pumpWidget(
      _host(const SeedlyHomeHeader(name: 'Ana', initials: 'A', drops: 1)),
    );
    expect(find.bySemanticsLabel('1 gota'), findsOneWidget);
  });

  testWidgets('a long name is cut and the tag keeps its room', (tester) async {
    await tester.pumpWidget(
      _host(
        const SeedlyHomeHeader(
          name: 'Nombrequeesdemasiadolargoparacaber',
          initials: 'N',
          drops: 12345,
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final greeting = tester.widget<Text>(find.textContaining('Hola, '));
    expect(greeting.overflow, TextOverflow.ellipsis);
  });

  testWidgets('shows the photo instead of the initials', (tester) async {
    // A 1×1 transparent PNG.
    final png = Uint8List.fromList(const [
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
      0x00,
      0x00,
      0x00,
      0x0D,
      0x49,
      0x48,
      0x44,
      0x52,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x08,
      0x06,
      0x00,
      0x00,
      0x00,
      0x1F,
      0x15,
      0xC4,
      0x89,
      0x00,
      0x00,
      0x00,
      0x0D,
      0x49,
      0x44,
      0x41,
      0x54,
      0x78,
      0x9C,
      0x63,
      0xF8,
      0xFF,
      0xFF,
      0x3F,
      0x00,
      0x05,
      0xFE,
      0x02,
      0xFE,
      0xA7,
      0x35,
      0x81,
      0x84,
      0x00,
      0x00,
      0x00,
      0x00,
      0x49,
      0x45,
      0x4E,
      0x44,
      0xAE,
      0x42,
      0x60,
      0x82,
    ]);
    await tester.pumpWidget(
      _host(SeedlyHomeHeader(name: 'Ana', initials: 'A', photo: png, drops: 0)),
    );

    expect(find.text('A'), findsNothing);
    expect(find.bySemanticsLabel('Tu foto de perfil'), findsOneWidget);
  });
}
