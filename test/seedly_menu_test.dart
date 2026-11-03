import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/screens/seedly_home_screen.dart';
import 'package:seedly/theme/seedly_theme.dart';
import 'package:seedly/widgets/seedly_menu.dart';

import 'support/fake_seedly_auth_repository.dart';
import 'support/fake_seedly_project_repository.dart';
import 'support/fake_seedly_user_repository.dart';

Color? _labelColor(WidgetTester tester, SeedlyMenuTab tab) =>
    tester.widget<Text>(find.text(tab.label)).style?.color;

Color? _iconColor(WidgetTester tester, SeedlyMenuTab tab) {
  final icon = tester.widget<SvgPicture>(
    find.byWidgetPredicate(
      (widget) =>
          widget is SvgPicture &&
          (widget.bytesLoader as SvgAssetLoader).assetName == tab.icon,
    ),
  );
  final filter = icon.colorFilter;
  return filter ==
          ColorFilter.mode(SeedlyPalette.primary[500]!, BlendMode.srcIn)
      ? SeedlyPalette.primary[500]
      : SeedlyPalette.neutral[600];
}

void main() {
  testWidgets('each variant highlights only its active tab in brand green', (
    tester,
  ) async {
    for (final active in SeedlyMenuTab.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: SeedlyTheme.light,
          home: Scaffold(bottomNavigationBar: SeedlyMenu(active: active)),
        ),
      );
      for (final tab in SeedlyMenuTab.values) {
        final expected = tab == active
            ? SeedlyPalette.primary[500]
            : SeedlyPalette.neutral[600];
        expect(_labelColor(tester, tab), expected, reason: '$active/$tab');
        expect(_iconColor(tester, tab), expected, reason: '$active/$tab');
      }
    }
  });

  testWidgets('tabs follow the Figma order around the add button', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: SeedlyTheme.light,
        home: const Scaffold(
          bottomNavigationBar: SeedlyMenu(active: SeedlyMenuTab.inicio),
        ),
      ),
    );
    double x(Finder finder) => tester.getCenter(finder).dx;
    final add = find.bySemanticsLabel('Agregar');
    expect(x(find.text('Inicio')), lessThan(x(find.text('Proyectos'))));
    expect(x(find.text('Proyectos')), lessThan(x(add)));
    expect(x(add), lessThan(x(find.text('Riego'))));
    expect(x(find.text('Riego')), lessThan(x(find.text('Mi perfil'))));
    expect(tester.getSize(add), const Size(56, 56));
  });

  testWidgets('the add button sits in the exact centre of the menu', (
    tester,
  ) async {
    for (final width in [360.0, 390.0, 440.0]) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: SeedlyTheme.light,
          home: const Scaffold(
            bottomNavigationBar: SeedlyMenu(active: SeedlyMenuTab.inicio),
          ),
        ),
      );
      final menu = tester.getCenter(find.byType(SeedlyMenu)).dx;
      final add = tester.getCenter(find.bySemanticsLabel('Agregar')).dx;
      expect(add, closeTo(menu, 0.5), reason: '$width');
      // Opposite tabs mirror each other around it.
      final inicio = tester.getCenter(find.text('Inicio')).dx;
      final perfil = tester.getCenter(find.text('Mi perfil')).dx;
      expect(perfil - add, closeTo(add - inicio, 0.5), reason: '$width');
    }
  });

  testWidgets('labels never touch the add button, even at 320px', (
    tester,
  ) async {
    for (final width in [320.0, 360.0, 390.0]) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: SeedlyTheme.light,
          home: const Scaffold(
            bottomNavigationBar: SeedlyMenu(active: SeedlyMenuTab.inicio),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: '$width');
      final add = tester.getRect(find.bySemanticsLabel('Agregar'));
      expect(
        add.left - tester.getRect(find.text('Proyectos')).right,
        greaterThanOrEqualTo(16),
        reason: '$width',
      );
      expect(
        tester.getRect(find.text('Riego')).left - add.right,
        greaterThanOrEqualTo(16),
        reason: '$width',
      );
    }
  });

  testWidgets('the outer tabs sit close to the screen edges', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: SeedlyTheme.light,
        home: const Scaffold(
          bottomNavigationBar: SeedlyMenu(active: SeedlyMenuTab.inicio),
        ),
      ),
    );
    // With Figma's 24px sides the icons were ~59px in; now ~44px.
    expect(tester.getCenter(find.text('Inicio')).dx, lessThan(46));
    expect(390 - tester.getCenter(find.text('Mi perfil')).dx, lessThan(46));
  });

  testWidgets('only enabled tabs report taps', (tester) async {
    final taps = <SeedlyMenuTab>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: SeedlyTheme.light,
        home: Scaffold(
          bottomNavigationBar: SeedlyMenu(
            active: SeedlyMenuTab.inicio,
            enabledTabs: const {SeedlyMenuTab.proyectos},
            onSelected: taps.add,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Riego'));
    await tester.tap(find.text('Proyectos'));
    await tester.tap(find.bySemanticsLabel('Agregar'));
    expect(taps, [SeedlyMenuTab.proyectos]);
  });

  for (final (inset, height) in [(0.0, 104.0), (8.0, 104.0), (34.0, 122.0)]) {
    testWidgets('a ${inset}px system bar inset makes the menu ${height}px', (
      tester,
    ) async {
      tester.view.padding = FakeViewPadding(bottom: inset);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: SeedlyTheme.light,
          home: const Scaffold(
            bottomNavigationBar: SeedlyMenu(active: SeedlyMenuTab.inicio),
          ),
        ),
      );
      // 16px over Figma's 88px; the inset replaces the 16px bottom padding
      // instead of adding to it.
      expect(tester.getSize(find.byType(SeedlyMenu)).height, height);
    });
  }

  testWidgets('home starts on Inicio and every tab switches the variant', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: SeedlyTheme.light,
        home: SeedlyHomeScreen(
          auth: FakeSeedlyAuthRepository(isSignedIn: true),
          projects: FakeSeedlyProjectRepository(),
          users: FakeSeedlyUserRepository(),
        ),
      ),
    );
    SeedlyMenuTab active() =>
        tester.widget<SeedlyMenu>(find.byType(SeedlyMenu)).active;

    expect(active(), SeedlyMenuTab.inicio);
    for (final tab in [
      SeedlyMenuTab.proyectos,
      SeedlyMenuTab.riego,
      SeedlyMenuTab.perfil,
      SeedlyMenuTab.inicio,
    ]) {
      await tester.tap(
        find.descendant(
          of: find.byType(SeedlyMenu),
          matching: find.text(tab.label),
        ),
      );
      await tester.pump();
      expect(active(), tab);
    }
  });
}
