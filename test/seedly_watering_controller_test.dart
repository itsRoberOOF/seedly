import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/models/seedly_errors.dart';
import 'package:seedly/models/seedly_project.dart';
import 'package:seedly/models/seedly_watering.dart';
import 'package:seedly/services/seedly_watering_controller.dart';

import 'support/fake_seedly_drops_repository.dart';
import 'support/fake_seedly_notification_service.dart';
import 'support/fake_seedly_watering_store.dart';

void main() {
  late DateTime now;
  late FakeSeedlyDropsRepository drops;
  late FakeSeedlyWateringStore store;
  late FakeSeedlyNotificationService notifications;
  late bool foreground;
  late SeedlyWateringController controller;

  SeedlyWateringController build({String? ownerId = 'ana'}) =>
      SeedlyWateringController(
        drops: drops,
        store: store,
        ownerId: ownerId,
        notifications: notifications,
        clock: () => now,
        inForeground: () => foreground,
      );

  void wait(Duration duration) => now = now.add(duration);

  /// Una sesión guardada que empezó hace [minutesAgo] minutos.
  SeedlyWateringSession saved({required int minutesAgo, int minutes = 25}) =>
      SeedlyWateringSession(
        id: 's1',
        ownerId: 'ana',
        minutes: minutes,
        startedAt: now.subtract(Duration(minutes: minutesAgo)),
      );

  /// Un controlador listo para empezar.
  Future<SeedlyWateringController> ready() async {
    await controller.restore();
    return controller;
  }

  const saveFailed = SeedlyDropsException(SeedlyDropsError.saveFailed);

  setUp(() {
    now = DateTime(2026, 11, 2, 10);
    drops = FakeSeedlyDropsRepository();
    store = FakeSeedlyWateringStore();
    notifications = FakeSeedlyNotificationService();
    foreground = true;
    controller = build();
  });

  tearDown(() => controller.dispose());

  group('restore', () {
    test('sin nada guardado queda lista para empezar', () async {
      await controller.restore();

      expect(controller.stage, SeedlyWateringStage.ready);
      expect(controller.session, isNull);
    });

    test('retoma una sesión en curso y sus avisos', () async {
      final session = saved(minutesAgo: 10);
      store.saved['ana'] = session;

      await controller.restore();

      expect(controller.stage, SeedlyWateringStage.watering);
      expect(controller.session, session);
      expect(notifications.wateringNotices['s1']?.title, 'Regando tu Seedly');
      expect(notifications.wateringNotices['s1']?.endsAt, session.endsAt);
      expect(notifications.wateringEnds['s1']?.at, session.endsAt);
    });

    test('paga una sesión que terminó con la app cerrada', () async {
      store.saved['ana'] = saved(minutesAgo: 40);

      await controller.restore();

      expect(controller.stage, SeedlyWateringStage.done);
      expect(
        controller.result,
        const SeedlyWateringResult(drops: 25, minutes: 25),
      );
      expect(drops.paid, {'watering_s1': 25});
      expect(store.saved, isEmpty);
    });

    test('si no puede leer lo guardado, empieza de cero', () async {
      store.error = StateError('sin almacenamiento');

      await controller.restore();

      expect(controller.stage, SeedlyWateringStage.ready);
    });

    test('nunca retoma la sesión de otra persona', () async {
      store.saved['beto'] = saved(minutesAgo: 10);

      await controller.restore();

      expect(controller.stage, SeedlyWateringStage.ready);
    });
  });

  group('start', () {
    test('inicia la sesión con el servidor y la guarda', () async {
      await (await ready()).start(minutes: 25);

      final session = controller.session!;
      expect(controller.stage, SeedlyWateringStage.watering);
      expect(drops.sessions, ['session1']);
      expect(session.id, 'session1');
      expect(session.minutes, 25);
      expect(session.startedAt, now);
      expect(store.saved['ana'], session);
      expect(notifications.wateringPermissionRequests, 1);
    });

    test('muestra el aviso fijo y programa el de fin', () async {
      await (await ready()).start(minutes: 25);

      final endsAt = now.add(const Duration(minutes: 25));
      expect(notifications.wateringNotices['session1'], (
        title: 'Regando tu Seedly',
        body: 'Sesión libre · termina a las 10:25 AM',
        endsAt: endsAt,
      ));
      expect(notifications.wateringEnds['session1'], (
        at: endsAt,
        title: '¡Buen trabajo!',
        body: SeedlyWateringController.endBody,
      ));
    });

    test('guarda la tarea elegida como enfoque', () async {
      const task = SeedlyTask(
        id: 't1',
        projectId: 'p1',
        title: 'Estudiar',
        done: false,
        order: 0,
      );

      await (await ready()).start(minutes: 10, focus: task);

      expect(controller.session?.focusTaskId, 't1');
      expect(controller.session?.focusTitle, 'Estudiar');
      expect(
        notifications.wateringNotices['session1']?.body,
        startsWith('Estudiar · '),
      );
    });

    test('una sesión a la vez', () async {
      await (await ready()).start(minutes: 25);
      await controller.start(minutes: 10);

      expect(drops.sessions, hasLength(1));
      expect(controller.session?.minutes, 25);
    });

    test('si el servidor falla, queda lista y no guarda nada', () async {
      await ready();
      drops.error = saveFailed;

      await expectLater(
        controller.start(minutes: 25),
        throwsA(isA<SeedlyDropsException>()),
      );

      expect(controller.stage, SeedlyWateringStage.ready);
      expect(controller.busy, isFalse);
      expect(store.saved, isEmpty);
    });

    test('rechaza duraciones fuera de 1 a 120 minutos', () async {
      await ready();

      expect(() => controller.start(minutes: 0), throwsArgumentError);
      expect(() => controller.start(minutes: 121), throwsArgumentError);
    });

    test('funciona aunque fallen las notificaciones y el guardado', () async {
      notifications.wateringError = Exception('sin permiso');
      store.error = Exception('sin espacio');
      await ready();

      await controller.start(minutes: 25);

      expect(controller.stage, SeedlyWateringStage.watering);
    });

    test('sin una persona con sesión iniciada no empieza', () async {
      controller.dispose();
      controller = build(ownerId: null);
      await controller.restore();

      await expectLater(
        controller.start(minutes: 25),
        throwsA(
          isA<SeedlyDropsException>().having(
            (error) => error.reason,
            'reason',
            SeedlyDropsError.sessionExpired,
          ),
        ),
      );
      expect(drops.sessions, isEmpty);
    });
  });

  group('pause y resume', () {
    test('pausar congela la cuenta y cancela el aviso de fin', () async {
      await (await ready()).start(minutes: 25);
      wait(const Duration(minutes: 10));

      await controller.pause();
      wait(const Duration(minutes: 30));

      final session = controller.session!;
      expect(session.isPaused, isTrue);
      expect(session.wateredAt(now), const Duration(minutes: 10));
      expect(store.saved['ana'], session);
      expect(
        notifications.wateringNotices['session1']?.title,
        'Riego en pausa',
      );
      expect(notifications.wateringNotices['session1']?.endsAt, isNull);
      expect(notifications.wateringEnds, isEmpty);
    });

    test('reanudar corre el final lo que duró la pausa', () async {
      final start = now;
      await (await ready()).start(minutes: 25);
      wait(const Duration(minutes: 10));
      await controller.pause();
      wait(const Duration(minutes: 5));

      await controller.resume();

      final endsAt = start.add(const Duration(minutes: 30));
      expect(controller.session?.endsAt, endsAt);
      expect(notifications.wateringEnds['session1']?.at, endsAt);
      expect(
        notifications.wateringNotices['session1']?.title,
        'Regando tu Seedly',
      );
    });
  });

  group('finish', () {
    test('paga los minutos completos regados', () async {
      await (await ready()).start(minutes: 25);
      wait(const Duration(minutes: 12, seconds: 30));

      final outcome = await controller.finish();

      expect(outcome, SeedlyWateringOutcome.paid);
      expect(controller.stage, SeedlyWateringStage.done);
      expect(
        controller.result,
        const SeedlyWateringResult(drops: 12, minutes: 12),
      );
      expect(drops.paid, {'watering_session1': 12});
      expect(store.saved, isEmpty);
      expect(notifications.wateringNotices, isEmpty);
      expect(notifications.wateringEnds, isEmpty);
    });

    test('menos de un minuto no paga nada', () async {
      await (await ready()).start(minutes: 25);
      wait(const Duration(seconds: 59));

      final outcome = await controller.finish();

      expect(outcome, SeedlyWateringOutcome.tooShort);
      expect(controller.stage, SeedlyWateringStage.ready);
      expect(drops.paid, isEmpty);
      expect(store.saved, isEmpty);
      expect(notifications.wateringNotices, isEmpty);
    });

    test('el tiempo en pausa no se paga', () async {
      await (await ready()).start(minutes: 25);
      wait(const Duration(minutes: 10));
      await controller.pause();
      wait(const Duration(minutes: 30));

      await controller.finish();

      expect(drops.paid, {'watering_session1': 10});
    });

    test(
      'si el pago falla, la sesión queda en pausa para reintentar',
      () async {
        await (await ready()).start(minutes: 25);
        wait(const Duration(minutes: 10));
        drops.error = saveFailed;

        await expectLater(
          controller.finish(),
          throwsA(isA<SeedlyDropsException>()),
        );

        expect(controller.stage, SeedlyWateringStage.watering);
        expect(controller.session?.isPaused, isTrue);
        expect(controller.failedPayments, 1);
        expect(store.saved['ana'], controller.session);

        drops.error = null;
        wait(const Duration(minutes: 5));
        expect(await controller.finish(), SeedlyWateringOutcome.paid);
        expect(drops.paid, {'watering_session1': 10});
        expect(controller.failedPayments, 0);
      },
    );

    test('una sesión ya pagada no vuelve a pagar', () async {
      await (await ready()).start(minutes: 25);
      drops.paid['watering_session1'] = 10;
      wait(const Duration(minutes: 10));

      final outcome = await controller.finish();

      expect(outcome, SeedlyWateringOutcome.alreadyPaid);
      expect(controller.stage, SeedlyWateringStage.ready);
      expect(store.saved, isEmpty);
    });

    test('descartar deja empezar otra sesión', () async {
      await (await ready()).start(minutes: 25);
      wait(const Duration(minutes: 10));
      drops.error = saveFailed;
      await expectLater(controller.finish(), throwsA(anything));

      await controller.discard();

      expect(controller.stage, SeedlyWateringStage.ready);
      expect(controller.session, isNull);
      expect(store.saved, isEmpty);
      expect(notifications.wateringNotices, isEmpty);
      expect(notifications.wateringEnds, isEmpty);
    });

    test('cerrar "Fin de riego" vuelve a empezar', () async {
      await (await ready()).start(minutes: 25);
      wait(const Duration(minutes: 10));
      await controller.finish();

      controller.dismissResult();

      expect(controller.stage, SeedlyWateringStage.ready);
      expect(controller.result, isNull);
    });
  });

  test('al cerrar sesión se van los avisos pero no la sesión', () async {
    await (await ready()).start(minutes: 25);

    await controller.suspend();

    expect(notifications.wateringNotices, isEmpty);
    expect(notifications.wateringEnds, isEmpty);
    expect(store.saved['ana'], isNotNull);
  });

  group('al llegar a cero', () {
    testWidgets('termina sola y paga la sesión entera', (tester) async {
      await (await ready()).start(minutes: 10);

      wait(const Duration(minutes: 10));
      await tester.pump(const Duration(minutes: 10));

      expect(controller.stage, SeedlyWateringStage.done);
      expect(
        controller.result,
        const SeedlyWateringResult(drops: 10, minutes: 10),
      );
      // Con la app abierta, la pantalla ya lo dice: sin aviso de fin.
      expect(notifications.wateringEnds, isEmpty);
    });

    testWidgets('fuera de la app deja el aviso de fin', (tester) async {
      foreground = false;
      await (await ready()).start(minutes: 10);

      wait(const Duration(minutes: 10));
      await tester.pump(const Duration(minutes: 10));

      expect(controller.stage, SeedlyWateringStage.done);
      expect(notifications.wateringEnds['session1'], isNotNull);
      expect(notifications.wateringNotices, isEmpty);
    });

    testWidgets('en pausa no termina', (tester) async {
      await (await ready()).start(minutes: 10);
      await controller.pause();

      wait(const Duration(minutes: 30));
      await tester.pump(const Duration(minutes: 30));

      expect(controller.stage, SeedlyWateringStage.watering);
      expect(drops.paid, isEmpty);
    });
  });

  test('una sesión guardada respeta los límites de SeedlyWatering', () {
    expect(SeedlyWatering.presets, [10, 15, 25, 30, 40]);
    expect(SeedlyWatering.defaultMinutes, 25);
    expect(SeedlyWatering.maxMinutes, 120);
  });
}
