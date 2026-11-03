import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/models/seedly_errors.dart';
import 'package:seedly/models/seedly_project.dart';
import 'package:seedly/screens/seedly_watering_view.dart';
import 'package:seedly/services/seedly_watering_controller.dart';
import 'package:seedly/theme/seedly_theme.dart';
import 'package:seedly/widgets/seedly_alert.dart';
import 'package:seedly/widgets/seedly_button.dart';
import 'package:seedly/widgets/seedly_plant_blob.dart';

import 'support/fake_seedly_drops_repository.dart';
import 'support/fake_seedly_notification_service.dart';
import 'support/fake_seedly_project_repository.dart';
import 'support/fake_seedly_watering_store.dart';
import 'support/keep_plant_still.dart';

void main() {
  keepPlantStill();
  tearDown(hideSeedlyAlert);

  late DateTime now;
  late FakeSeedlyDropsRepository drops;
  late FakeSeedlyProjectRepository projects;
  late SeedlyWateringController controller;
  late int homeCalls;

  const saveFailed = SeedlyDropsException(SeedlyDropsError.saveFailed);

  void wait(Duration duration) => now = now.add(duration);

  setUp(() {
    now = DateTime(2026, 11, 2, 10);
    drops = FakeSeedlyDropsRepository(phase: 2, startingDrops: 340);
    projects = FakeSeedlyProjectRepository();
    homeCalls = 0;
  });

  Future<void> pumpView(WidgetTester tester) async {
    // Un teléfono del tamaño de Figma.
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    controller = SeedlyWateringController(
      drops: drops,
      store: FakeSeedlyWateringStore(),
      ownerId: 'ana',
      notifications: FakeSeedlyNotificationService(),
      clock: () => now,
      inForeground: () => true,
    );
    await controller.restore();
    await tester.pumpWidget(
      MaterialApp(
        theme: SeedlyTheme.light,
        home: Scaffold(
          body: SeedlyWateringView(
            controller: controller,
            projects: projects,
            drops: drops,
            onHome: () => homeCalls++,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Desmonta la vista y suelta el controlador, para que no quede ningún
  /// timer de la sesión pendiente al terminar el test.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  }

  Future<void> tapButton(WidgetTester tester, String label) async {
    final button = find.widgetWithText(SeedlyButton, label);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
  }

  SeedlyButtonVariant variantOf(WidgetTester tester, String label) => tester
      .widget<SeedlyButton>(find.widgetWithText(SeedlyButton, label))
      .variant;

  Future<void> begin(WidgetTester tester) async {
    await tapButton(tester, 'Comenzar sesión');
    await tester.pump();
  }

  group('Empezar riego', () {
    testWidgets('muestra la pantalla de Figma', (tester) async {
      await pumpView(tester);

      for (final text in [
        'Sesión de Riego',
        'Concéntrate en una tarea mientras tu planta recibe agua',
        'DURACIÓN DE LA SESIÓN',
        '10 min',
        '15 min',
        '25 min',
        '30 min',
        '40 min',
        'Tiempo personalizado',
        'ENFOQUE DE HOY',
        'Sesión libre',
        'Elegir tarea',
        'Comenzar sesión',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.byType(SeedlyPlantBlob), findsOneWidget);
      // 25 minutos viene elegido, como en Figma.
      expect(variantOf(tester, '25 min'), SeedlyButtonVariant.filled);
      expect(variantOf(tester, '10 min'), SeedlyButtonVariant.outline);
      await close(tester);
    });

    testWidgets('elegir una duración y comenzar', (tester) async {
      await pumpView(tester);

      await tapButton(tester, '10 min');
      expect(variantOf(tester, '10 min'), SeedlyButtonVariant.filled);
      expect(variantOf(tester, '25 min'), SeedlyButtonVariant.outline);
      await begin(tester);

      expect(controller.session?.minutes, 10);
      expect(find.text('Regando tu Seedly'), findsOneWidget);
      expect(find.text('10:00'), findsOneWidget);
      expect(
        find.text('Enfoque actual: Sesión libre', findRichText: true),
        findsOneWidget,
      );
      await close(tester);
    });

    testWidgets('tiempo personalizado con la rueda de minutos', (tester) async {
      await pumpView(tester);

      await tapButton(tester, 'Tiempo personalizado');
      await tester.pumpAndSettle();
      // La fila 0 es 1 minuto: la 49 es 50.
      final wheel = tester.widget<ListWheelScrollView>(
        find.byType(ListWheelScrollView),
      );
      (wheel.controller! as FixedExtentScrollController).jumpToItem(49);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Minutos'), findsOneWidget);
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(find.text('Tiempo personalizado: 50 min'), findsOneWidget);
      for (final preset in ['10 min', '15 min', '25 min', '30 min', '40 min']) {
        expect(variantOf(tester, preset), SeedlyButtonVariant.outline);
      }
      await begin(tester);
      expect(controller.session?.minutes, 50);
      await close(tester);
    });

    testWidgets('cancelar el tiempo personalizado deja la duración', (
      tester,
    ) async {
      await pumpView(tester);

      await tapButton(tester, 'Tiempo personalizado');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(variantOf(tester, '25 min'), SeedlyButtonVariant.filled);
      await close(tester);
    });

    testWidgets('elegir una tarea de hoy como enfoque', (tester) async {
      projects.tasksOn = Stream.value(const [
        SeedlyTask(
          id: 't1',
          projectId: 'p1',
          title: 'Estudiar',
          done: false,
          order: 0,
        ),
        SeedlyTask(
          id: 't2',
          projectId: 'p1',
          title: 'Lavar la ropa',
          done: true,
          order: 1,
        ),
      ]);
      await pumpView(tester);

      await tapButton(tester, 'Elegir tarea');
      await tester.pumpAndSettle();
      expect(find.text('Estudiar'), findsOneWidget);
      // Las tareas hechas no se ofrecen.
      expect(find.text('Lavar la ropa'), findsNothing);
      await tester.tap(find.text('Estudiar'));
      await tester.pumpAndSettle();

      expect(find.text('Estudiar'), findsOneWidget);
      expect(find.text('Cambiar'), findsOneWidget);
      await begin(tester);
      expect(controller.session?.focusTaskId, 't1');
      expect(
        find.text('Enfoque actual: Estudiar', findRichText: true),
        findsOneWidget,
      );
      await close(tester);
    });

    testWidgets('volver a "Sesión libre" desde la lista', (tester) async {
      projects.tasksOn = Stream.value(const [
        SeedlyTask(
          id: 't1',
          projectId: 'p1',
          title: 'Estudiar',
          done: false,
          order: 0,
        ),
      ]);
      await pumpView(tester);
      await tapButton(tester, 'Elegir tarea');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Estudiar'));
      await tester.pumpAndSettle();

      await tapButton(tester, 'Cambiar');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sesión libre').last);
      await tester.pumpAndSettle();

      expect(find.text('Elegir tarea'), findsOneWidget);
      await begin(tester);
      expect(controller.session?.focusTaskId, isNull);
      await close(tester);
    });

    testWidgets('sin tareas pendientes lo dice', (tester) async {
      projects.tasksOn = Stream.value(const []);
      await pumpView(tester);

      await tapButton(tester, 'Elegir tarea');
      await tester.pumpAndSettle();

      expect(
        find.text('No tienes tareas pendientes para hoy.'),
        findsOneWidget,
      );
      await close(tester);
    });

    testWidgets('si no puede empezar, avisa', (tester) async {
      await pumpView(tester);
      drops.error = saveFailed;

      await begin(tester);

      expect(find.text('No se pudo empezar el riego'), findsOneWidget);
      expect(find.text('Sesión de Riego'), findsOneWidget);
      await close(tester);
    });

    testWidgets('la flecha atrás vuelve a Inicio', (tester) async {
      await pumpView(tester);

      await tester.tap(find.byTooltip('Volver'));

      expect(homeCalls, 1);
      await close(tester);
    });
  });

  group('Regando', () {
    testWidgets('la cuenta baja y muestra el progreso', (tester) async {
      await pumpView(tester);
      await begin(tester);

      expect(find.text('25:00'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      wait(const Duration(minutes: 10));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('15:00'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
      expect(find.text('PROGRESO DE LA SESIÓN'), findsOneWidget);
      expect(
        tester.widget<SeedlyPlantBlob>(find.byType(SeedlyPlantBlob)).watering,
        isTrue,
      );
      await close(tester);
    });

    testWidgets('pausar y reanudar', (tester) async {
      await pumpView(tester);
      await begin(tester);

      await tapButton(tester, 'Pausar');
      expect(find.text('Reanudar'), findsOneWidget);
      expect(find.text('En pausa'), findsOneWidget);
      expect(
        tester.widget<SeedlyPlantBlob>(find.byType(SeedlyPlantBlob)).watering,
        isFalse,
      );
      wait(const Duration(minutes: 5));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('25:00'), findsOneWidget);

      await tapButton(tester, 'Reanudar');
      expect(find.text('Pausar'), findsOneWidget);
      expect(find.text('En pausa'), findsNothing);
      await close(tester);
    });

    testWidgets('la flecha atrás vuelve a Inicio sin cortar la sesión', (
      tester,
    ) async {
      await pumpView(tester);
      await begin(tester);

      await tester.tap(find.byTooltip('Volver'));

      expect(homeCalls, 1);
      expect(controller.stage, SeedlyWateringStage.watering);
      await close(tester);
    });

    testWidgets('menos de un minuto avisa y vuelve a empezar', (tester) async {
      await pumpView(tester);
      await begin(tester);
      wait(const Duration(seconds: 30));

      await tapButton(tester, 'Terminar');
      await tester.pump();

      expect(find.text('Sesión muy corta'), findsOneWidget);
      expect(find.text('Sesión de Riego'), findsOneWidget);
      expect(drops.paid, isEmpty);
      await close(tester);
    });

    testWidgets('si el pago falla avisa, y a la segunda ofrece descartar', (
      tester,
    ) async {
      await pumpView(tester);
      await begin(tester);
      wait(const Duration(minutes: 10));
      drops.error = saveFailed;

      await tapButton(tester, 'Terminar');
      await tester.pump();
      expect(find.text('No se pudo terminar el riego'), findsOneWidget);
      expect(find.text('Regando tu Seedly'), findsOneWidget);

      await tapButton(tester, 'Terminar');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('¿Descartar la sesión?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Descartar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(controller.stage, SeedlyWateringStage.ready);
      expect(find.text('Sesión de Riego'), findsOneWidget);
      await close(tester);
    });
  });

  group('Fin de riego', () {
    testWidgets('terminar paga y muestra las gotas y el total', (tester) async {
      await pumpView(tester);
      await begin(tester);
      wait(const Duration(minutes: 10));

      await tapButton(tester, 'Terminar');
      await tester.pump();

      expect(find.text('¡Buen trabajo!'), findsOneWidget);
      expect(
        find.text(
          'Gracias a tu esfuerzo y tiempo de enfoque, tu planta ha recibido '
          'agua',
        ),
        findsOneWidget,
      );
      expect(find.text('+10 gotas'), findsOneWidget);
      expect(find.text('Total: 350'), findsOneWidget);
      expect(drops.paid, {'watering_session1': 10});
      await close(tester);
    });

    testWidgets('al llegar a cero termina sola', (tester) async {
      await pumpView(tester);
      await tapButton(tester, '10 min');
      await begin(tester);

      wait(const Duration(minutes: 10));
      await tester.pump(const Duration(minutes: 10));
      await tester.pump();

      expect(find.text('¡Buen trabajo!'), findsOneWidget);
      expect(find.text('+10 gotas'), findsOneWidget);
      await close(tester);
    });

    testWidgets('"Volver al inicio" deja Riego listo para otra sesión', (
      tester,
    ) async {
      await pumpView(tester);
      await begin(tester);
      wait(const Duration(minutes: 10));
      await tapButton(tester, 'Terminar');
      await tester.pump();

      await tapButton(tester, 'Volver al inicio');

      expect(homeCalls, 1);
      expect(controller.stage, SeedlyWateringStage.ready);
      expect(find.text('Sesión de Riego'), findsOneWidget);
      await close(tester);
    });
  });

  testWidgets('salir de "Fin de riego" por el menú también la cierra', (
    tester,
  ) async {
    await pumpView(tester);
    await begin(tester);
    wait(const Duration(minutes: 10));
    await tapButton(tester, 'Terminar');
    await tester.pump();
    expect(controller.stage, SeedlyWateringStage.done);

    await tester.pumpWidget(const SizedBox());

    expect(controller.stage, SeedlyWateringStage.ready);
    controller.dispose();
  });

  testWidgets('cada pantalla entra en un teléfono de 360px sin desbordar', (
    tester,
  ) async {
    await pumpView(tester);
    tester.view.physicalSize = const Size(360, 740);
    await tester.pump();
    expect(tester.takeException(), isNull);

    await begin(tester);
    expect(tester.takeException(), isNull);

    wait(const Duration(minutes: 10));
    await tapButton(tester, 'Terminar');
    await tester.pump();
    expect(tester.takeException(), isNull);
    await close(tester);
  });
}
