import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/main.dart';
import 'package:seedly/widgets/seedly_loader.dart';

import 'support/fake_seedly_auth_repository.dart';
import 'support/fake_seedly_drops_repository.dart';
import 'support/fake_seedly_project_repository.dart';
import 'support/fake_seedly_user_repository.dart';

void main() {
  testWidgets('Seedly opens on its loading screen', (tester) async {
    await tester.pumpWidget(
      MyApp(
        auth: FakeSeedlyAuthRepository(),
        projects: FakeSeedlyProjectRepository(),
        users: FakeSeedlyUserRepository(),
        drops: FakeSeedlyDropsRepository(),
      ),
    );

    expect(find.text('Seedly'), findsOneWidget);
    expect(find.text('Todo progreso empieza\ncon una semilla'), findsOneWidget);
    expect(find.text('CARGANDO'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('Loading remains at zero before the first visible frame', (
    tester,
  ) async {
    tester.binding.deferFirstFrame();
    try {
      await tester.pumpWidget(
        MyApp(
          auth: FakeSeedlyAuthRepository(),
          projects: FakeSeedlyProjectRepository(),
          users: FakeSeedlyUserRepository(),
          drops: FakeSeedlyDropsRepository(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1500));

      final progress = tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value;
      expect(progress, 0);
    } finally {
      tester.binding.allowFirstFrame();
    }
  });

  group('SeedlyLoader', () {
    Widget host(Widget loader) => MaterialApp(
      home: Scaffold(body: Center(child: loader)),
    );

    double shown(WidgetTester tester) => tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
        .value!;

    testWidgets('shows how far along it is', (tester) async {
      await tester.pumpWidget(host(const SeedlyLoader(progress: 0.4)));
      await tester.pumpAndSettle();

      expect(shown(tester), closeTo(0.4, 0.001));
    });

    testWidgets('glides to a new value instead of jumping', (tester) async {
      await tester.pumpWidget(host(const SeedlyLoader(progress: 0)));
      await tester.pumpWidget(host(const SeedlyLoader(progress: 1)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(shown(tester), inExclusiveRange(0.0, 1.0));

      await tester.pump(const Duration(milliseconds: 300));
      expect(shown(tester), 1);
    });

    testWidgets('keeps what is out of range inside the bar', (tester) async {
      await tester.pumpWidget(host(const SeedlyLoader(progress: 1.7)));
      await tester.pumpAndSettle();
      expect(shown(tester), 1);

      await tester.pumpWidget(host(const SeedlyLoader(progress: -1)));
      await tester.pumpAndSettle();
      expect(shown(tester), 0);
    });

    testWidgets('always says Cargando, whatever the progress', (tester) async {
      await tester.pumpWidget(host(const SeedlyLoader(progress: 0)));
      expect(find.text('CARGANDO'), findsOneWidget);

      await tester.pumpWidget(host(const SeedlyLoader(progress: 0.7)));
      await tester.pumpAndSettle();
      expect(find.text('CARGANDO'), findsOneWidget);
    });

    testWidgets('with reduce motion it does not glide', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(host(const SeedlyLoader(progress: 0)));
      await tester.pumpWidget(host(const SeedlyLoader(progress: 1)));
      await tester.pump();

      expect(shown(tester), 1);
    });

    testWidgets('announces itself as loading with its percentage', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(const SeedlyLoader(progress: 0.25)));

      final node = tester.getSemantics(find.byType(SeedlyLoader));
      expect(node.label, 'Cargando');
      expect(node.value, '25%');
      handle.dispose();
    });
  });
}
