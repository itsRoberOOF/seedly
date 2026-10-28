import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/main.dart';
import 'package:seedly/widgets/seedly_loader.dart';

import 'support/fake_seedly_auth_repository.dart';
import 'support/fake_seedly_project_repository.dart';
import 'support/fake_seedly_user_repository.dart';

void main() {
  testWidgets('Seedly opens on its loading screen', (tester) async {
    await tester.pumpWidget(
      MyApp(
        auth: FakeSeedlyAuthRepository(),
        projects: FakeSeedlyProjectRepository(),
        users: FakeSeedlyUserRepository(),
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

  testWidgets('Loading bar reaches each fifth in three seconds', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SeedlyLoader(startAfter: Future<void>.value())),
      ),
    );
    await tester.pump();

    double progress() => tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
        .value!;

    expect(progress(), 0);
    for (var step = 1; step <= 5; step++) {
      await tester.pump(const Duration(milliseconds: 600));
      expect(progress(), closeTo(step / 5, 0.001));
    }

    await tester.pump(const Duration(seconds: 1));
    expect(progress(), 1);
  });
}
