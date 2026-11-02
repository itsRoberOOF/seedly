import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/modals/seedly_add_modal.dart';
import 'package:seedly/screens/seedly_home_screen.dart';
import 'package:seedly/theme/seedly_theme.dart';
import 'package:seedly/widgets/seedly_modal.dart';
import 'package:seedly/widgets/seedly_option_card.dart';

import 'support/fake_seedly_auth_repository.dart';
import 'support/fake_seedly_project_repository.dart';
import 'support/fake_seedly_user_repository.dart';
import 'support/keep_plant_still.dart';

/// A screen whose button opens [open] and records what it completes with.
Widget _launcher(
  Future<Object?> Function(BuildContext) open,
  List<Object?> results,
) => MaterialApp(
  theme: SeedlyTheme.light,
  home: Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: TextButton(
          onPressed: () async => results.add(await open(context)),
          child: const Text('abrir'),
        ),
      ),
    ),
  ),
);

void main() {
  keepPlantStill();
  testWidgets('base modal completes with the value it is popped with', (
    tester,
  ) async {
    final results = <Object?>[];
    await tester.pumpWidget(
      _launcher(
        (context) => showSeedlyModal<String>(
          context,
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).pop('elegido'),
            child: const Text('elegir'),
          ),
        ),
        results,
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.byType(SeedlyModal), findsOneWidget);
    // Only Figma's handle, not Material's.
    expect(
      find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_DragHandle',
      ),
      findsNothing,
    );

    await tester.tap(find.text('elegir'));
    await tester.pumpAndSettle();
    expect(find.byType(SeedlyModal), findsNothing);
    expect(results, ['elegido']);
  });

  testWidgets('the close button dismisses the modal without a result', (
    tester,
  ) async {
    final results = <Object?>[];
    await tester.pumpWidget(
      _launcher(
        (context) => showSeedlyModal<String>(
          context,
          builder: (_) => const Text('contenido'),
        ),
        results,
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.byType(SeedlyModal), findsNothing);
    expect(results, [null]);
  });

  testWidgets('showClose: false hides the close button', (tester) async {
    await tester.pumpWidget(
      _launcher(
        (context) => showSeedlyModal<void>(
          context,
          showClose: false,
          builder: (_) => const Text('contenido'),
        ),
        [],
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('contenido'), findsOneWidget);
    expect(find.byTooltip('Cerrar'), findsNothing);
  });

  testWidgets('long content scrolls within 90% of the screen', (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _launcher(
        (context) => showSeedlyModal<void>(
          context,
          builder: (_) => Column(
            children: [
              for (var i = 0; i < 30; i++)
                SizedBox(height: 60, child: Text('fila $i')),
            ],
          ),
        ),
        [],
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(SeedlyModal)).height,
      lessThanOrEqualTo(630),
    );
    expect(find.byTooltip('Cerrar'), findsOneWidget);
  });

  testWidgets('scrolled content stops short of the close button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _launcher(
        (context) => showSeedlyModal<void>(
          context,
          builder: (_) => Column(
            children: [
              for (var i = 0; i < 30; i++)
                SizedBox(height: 60, child: Text('fila $i')),
            ],
          ),
        ),
        [],
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.descendant(
        of: find.byType(SeedlyModal),
        matching: find.byType(Scrollable),
      ),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    final viewport = tester.getRect(
      find.descendant(
        of: find.byType(SeedlyModal),
        matching: find.byType(Scrollable),
      ),
    );
    final close = tester.getRect(find.byTooltip('Cerrar'));
    // 20px slot bottom padding + 10px gap stay clear while scrolled.
    expect(close.top - viewport.bottom, greaterThanOrEqualTo(30));
  });

  testWidgets('add modal lists the three Figma options in order', (
    tester,
  ) async {
    final results = <Object?>[];
    await tester.pumpWidget(_launcher(showSeedlyAddModal, results));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    final cards = tester
        .widgetList<SeedlyOptionCard>(find.byType(SeedlyOptionCard))
        .toList();
    expect(
      [for (final card in cards) card.title],
      ['Crear tarea', 'Proyecto Express', 'Proyecto completo'],
    );
    expect(
      find.text('Ideal para proyectos de pocas tareas o ideas rápidas'),
      findsOneWidget,
    );

    await tester.tap(find.text('Proyecto Express'));
    await tester.pumpAndSettle();
    expect(results, [SeedlyAddOption.expressProject]);
  });

  testWidgets('the + button opens the add modal from home', (tester) async {
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
    await tester.tap(find.bySemanticsLabel('Agregar'));
    await tester.pumpAndSettle();
    expect(find.text('Crear tarea'), findsOneWidget);

    await tester.tap(find.text('Crear tarea'));
    await tester.pumpAndSettle();
    expect(find.byType(SeedlyModal), findsNothing);
    expect(find.text('Crear tarea aún no disponible'), findsOneWidget);
  });

  testWidgets('closing the add modal shows no notice', (tester) async {
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
    await tester.tap(find.bySemanticsLabel('Agregar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.byType(SeedlyModal), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });
}
