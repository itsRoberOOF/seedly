import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/models/seedly_errors.dart';
import 'package:seedly/screens/seedly_home_screen.dart';
import 'package:seedly/screens/seedly_login_screen.dart';
import 'package:seedly/screens/seedly_profile_view.dart';
import 'package:seedly/theme/seedly_theme.dart';
import 'package:seedly/widgets/seedly_alert.dart';
import 'package:seedly/widgets/seedly_busy_overlay.dart';
import 'package:seedly/widgets/seedly_menu.dart';

import 'support/fake_seedly_auth_repository.dart';
import 'support/fake_seedly_notification_service.dart';
import 'support/fake_seedly_project_repository.dart';
import 'support/fake_seedly_user_repository.dart';
import 'support/sign_out.dart';

Future<FakeSeedlyAuthRepository> _openProfile(
  WidgetTester tester, {
  Size size = const Size(440, 956),
  Future<void>? signOutGate,
  SeedlyAuthException? signOutError,
  FakeSeedlyNotificationService? notifications,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final auth =
      FakeSeedlyAuthRepository(
          isSignedIn: true,
          displayName: 'Rober Morán',
          email: 'robermoran28@gmail.com',
        )
        ..signOutGate = signOutGate
        ..signOutError = signOutError;
  await tester.pumpWidget(
    MaterialApp(
      theme: SeedlyTheme.light,
      home: SeedlyHomeScreen(
        auth: auth,
        projects: FakeSeedlyProjectRepository(),
        users: FakeSeedlyUserRepository(),
        notifications: notifications,
      ),
    ),
  );
  await tester.tap(
    find.descendant(
      of: find.byType(SeedlyMenu),
      matching: find.text('Mi perfil'),
    ),
  );
  await tester.pump();
  return auth;
}

void main() {
  tearDown(hideSeedlyAlert);

  testWidgets('there is no veil until Cerrar sesión is confirmed', (
    tester,
  ) async {
    await _openProfile(tester);

    expect(find.byType(SeedlyBusyOverlay), findsNothing);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Cerrar sesión'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Only asked so far.
    expect(find.byType(SeedlyBusyOverlay), findsNothing);
  });

  testWidgets('confirming covers the whole screen at once, menu included', (
    tester,
  ) async {
    final gate = Completer<void>();
    final auth = await _openProfile(tester, signOutGate: gate.future);

    await tapSignOut(tester);
    await tester.pump();

    expect(find.byType(SeedlyBusyOverlay), findsOneWidget);
    expect(find.text('Cerrando sesión…'), findsOneWidget);
    expect(auth.signOutCalls, 1);
    final screen = tester.getRect(find.byType(SeedlyHomeScreen));
    expect(tester.getRect(find.byType(SeedlyBusyOverlay)), screen);

    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('while signing out nothing behind the veil can be used', (
    tester,
  ) async {
    final gate = Completer<void>();
    // Short enough that the profile has something to scroll.
    await _openProfile(
      tester,
      size: const Size(440, 640),
      signOutGate: gate.future,
    );
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    expect(scroll.position.maxScrollExtent, greaterThan(100));

    await tapSignOut(tester);
    await tester.pump();
    // The button is at the bottom, so the profile is scrolled to its end and
    // dragging back up would move it if nothing blocked the drag.
    final before = scroll.position.pixels;
    expect(before, scroll.position.maxScrollExtent);

    await tester.drag(
      find.byType(SeedlyProfileView),
      const Offset(0, 300),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(scroll.position.pixels, before);

    // The menu cannot be used to leave the profile.
    await tester.tap(
      find.descendant(
        of: find.byType(SeedlyMenu),
        matching: find.text('Inicio'),
      ),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(find.byType(SeedlyProfileView), findsOneWidget);

    // Nor can the system back button.
    final pop = find.descendant(
      of: find.byType(SeedlyHomeScreen),
      matching: find.byType(PopScope),
    );
    expect(tester.widget<PopScope>(pop.first).canPop, isFalse);

    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('once signed out the login shows and the veil is gone', (
    tester,
  ) async {
    final gate = Completer<void>();
    await _openProfile(tester, signOutGate: gate.future);

    await tapSignOut(tester);
    await tester.pump();
    gate.complete();
    await tester.pumpAndSettle();

    expect(find.byType(SeedlyLoginScreen), findsOneWidget);
    expect(find.byType(SeedlyBusyOverlay), findsNothing);
  });

  testWidgets('a failed sign-out lifts the veil and says why', (tester) async {
    final gate = Completer<void>();
    final auth = await _openProfile(
      tester,
      signOutGate: gate.future,
      signOutError: const SeedlyAuthException(SeedlyAuthError.network),
    );

    await tapSignOut(tester);
    await tester.pump();
    expect(find.byType(SeedlyBusyOverlay), findsOneWidget);

    gate.complete();
    await tester.pump();
    await tester.pump();

    expect(find.byType(SeedlyBusyOverlay), findsNothing);
    expect(find.text('No se pudo cerrar sesión'), findsOneWidget);
    expect(find.byType(SeedlyProfileView), findsOneWidget);
    expect(auth.isSignedIn, isTrue);
  });

  testWidgets('after a failure the person can try again', (tester) async {
    final auth = await _openProfile(
      tester,
      signOutError: const SeedlyAuthException(SeedlyAuthError.network),
    );

    await tapSignOut(tester);
    await tester.pump();
    await tester.pump();
    expect(find.byType(SeedlyBusyOverlay), findsNothing);

    auth.signOutError = null;
    await tapSignOut(tester);
    await tester.pumpAndSettle();

    expect(auth.signOutCalls, 2);
    expect(find.byType(SeedlyLoginScreen), findsOneWidget);
  });
}
