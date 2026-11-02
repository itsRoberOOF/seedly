import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/screens/seedly_drops_debug_view.dart';

import 'support/fake_seedly_auth_repository.dart';
import 'support/fake_seedly_drops_repository.dart';

Future<FakeSeedlyDropsRepository> _open(
  WidgetTester tester, {
  bool signedIn = true,
  int startingDrops = 0,
}) async {
  final drops = FakeSeedlyDropsRepository(startingDrops: startingDrops);
  await tester.pumpWidget(
    MaterialApp(
      home: SeedlyDropsDebugView(
        auth: FakeSeedlyAuthRepository(isSignedIn: signedIn),
        drops: drops,
        app: const Text('La app'),
      ),
    ),
  );
  await tester.pump();
  return drops;
}

void main() {
  testWidgets('asks to sign in first', (tester) async {
    await _open(tester, signedIn: false);

    expect(find.text('Iniciar sesión'), findsWidgets);
    expect(find.textContaining('Fase'), findsNothing);
  });

  testWidgets('shows the plant and pays a task', (tester) async {
    await _open(tester);
    await tester.pump();
    expect(find.text('Fase 1 · 0 gotas · meta 150'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('drops-id')), 't1');
    await tester.tap(find.text('Pagar tarea'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Pagar tarea: 3'), findsOneWidget);
    expect(find.text('Fase 1 · 3 gotas · meta 150'), findsOneWidget);
  });

  testWidgets('shows why the plant cannot grow', (tester) async {
    await _open(tester);

    await tester.tap(find.text('Crecer'));
    await tester.pump();

    expect(
      find.text('Crecer: Aún no tienes gotas suficientes para crecer.'),
      findsOneWidget,
    );
  });

  testWidgets('grows once there are enough drops', (tester) async {
    await _open(tester, startingDrops: 150);

    await tester.tap(find.text('Crecer'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Fase 2 · 150 gotas · meta 500'), findsOneWidget);
  });
}
