import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/screens/seedly_home_screen.dart';
import 'package:seedly/screens/seedly_loading_screen.dart';
import 'package:seedly/screens/seedly_login_screen.dart';
import 'package:seedly/services/seedly_startup.dart';
import 'package:seedly/theme/seedly_theme.dart';

import 'support/fake_seedly_auth_repository.dart';
import 'support/fake_seedly_project_repository.dart';
import 'support/fake_seedly_user_repository.dart';
import 'support/keep_plant_still.dart';

Widget _screen({
  FakeSeedlyAuthRepository? auth,
  FakeSeedlyUserRepository? users,
  SeedlyStartup? startup,
}) => MaterialApp(
  theme: SeedlyTheme.light,
  home: SeedlyLoadingScreen(
    auth: auth ?? FakeSeedlyAuthRepository(isSignedIn: true),
    projects: FakeSeedlyProjectRepository(),
    users: users ?? FakeSeedlyUserRepository(),
    startAfter: Future<void>.value(),
    startup: startup,
  ),
);

double _bar(WidgetTester tester) => tester
    .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
    .value!;

void main() {
  keepPlantStill();

  testWidgets('the bar follows what is loaded and the caption stays put', (
    tester,
  ) async {
    final profile = Completer<void>();
    final tasks = Completer<void>();
    await tester.pumpWidget(
      _screen(
        startup: SeedlyStartup(
          steps: [() => profile.future, () => tasks.future],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('CARGANDO'), findsOneWidget);
    expect(_bar(tester), lessThan(0.2));

    profile.complete();
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('CARGANDO'), findsOneWidget);
    expect(_bar(tester), greaterThanOrEqualTo(0.5));

    tasks.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('Inicio waits for the data, then opens', (tester) async {
    final profile = Completer<void>();
    await tester.pumpWidget(
      _screen(
        startup: SeedlyStartup(
          steps: [() => profile.future],
          stepTimeout: const Duration(seconds: 30),
        ),
      ),
    );

    // Well past the minimum time, and still loading.
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(SeedlyLoadingScreen), findsOneWidget);
    expect(find.byType(SeedlyHomeScreen), findsNothing);

    profile.complete();
    // The full bar stays a moment before leaving.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.byType(SeedlyHomeScreen), findsOneWidget);
    expect(find.byType(SeedlyLoadingScreen), findsNothing);
  });

  testWidgets('without a connection it gives up waiting and opens anyway', (
    tester,
  ) async {
    await tester.pumpWidget(
      _screen(
        startup: SeedlyStartup(
          steps: [() => Completer<void>().future],
          stepTimeout: const Duration(seconds: 2),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.byType(SeedlyHomeScreen), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(SeedlyHomeScreen), findsOneWidget);
  });

  testWidgets('nobody signed in goes to the login after the minimum time', (
    tester,
  ) async {
    await tester.pumpWidget(_screen(auth: FakeSeedlyAuthRepository()));

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SeedlyLoginScreen), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(SeedlyLoginScreen), findsOneWidget);
  });

  testWidgets('loads what Inicio reads for the person signed in', (
    tester,
  ) async {
    final users = FakeSeedlyUserRepository();
    await tester.pumpWidget(_screen(users: users));
    await tester.pump(const Duration(milliseconds: 100));

    expect(users.watchCalls, 1);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(SeedlyHomeScreen), findsOneWidget);
  });

  testWidgets('does not start before the first visible frame', (tester) async {
    final first = Completer<void>();
    final users = FakeSeedlyUserRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: SeedlyTheme.light,
        home: SeedlyLoadingScreen(
          auth: FakeSeedlyAuthRepository(isSignedIn: true),
          projects: FakeSeedlyProjectRepository(),
          users: users,
          startAfter: first.future,
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 3));
    expect(users.watchCalls, 0);
    expect(_bar(tester), 0);

    first.complete();
    await tester.pump(const Duration(milliseconds: 100));
    expect(users.watchCalls, 1);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('leaving the screen mid-load stops it and opens nothing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _screen(startup: SeedlyStartup(steps: [() => Completer<void>().future])),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump(const Duration(seconds: 6));

    expect(tester.takeException(), isNull);
    expect(find.byType(SeedlyHomeScreen), findsNothing);
    // testWidgets fails the test if a timer outlived the screen.
  });
}
