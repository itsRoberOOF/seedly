import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/data/notifications/flutter_seedly_notification_service.dart';
import 'package:timezone/timezone.dart' as tz;

/// El plugin nativo sin canales de plataforma: guarda lo que se muestra, se
/// programa y se cancela, y deja simular el toque de un aviso.
class _FakePlugin extends Fake implements FlutterLocalNotificationsPlugin {
  DidReceiveNotificationResponseCallback? onResponse;
  NotificationAppLaunchDetails? launch;

  final shown =
      <int, ({String? title, String? payload, NotificationDetails? details})>{};
  final scheduled =
      <int, ({tz.TZDateTime at, String? payload, AndroidScheduleMode mode})>{};

  void tap(String payload) => onResponse!(
    NotificationResponse(
      notificationResponseType: NotificationResponseType.selectedNotification,
      payload: payload,
    ),
  );

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    onResponse = onDidReceiveNotificationResponse;
    return true;
  }

  @override
  Future<NotificationAppLaunchDetails?>
  getNotificationAppLaunchDetails() async => launch;

  @override
  T? resolvePlatformSpecificImplementation<
    T extends FlutterLocalNotificationsPlatform
  >() => null;

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails,
    String? payload,
  }) async {
    shown[id] = (title: title, payload: payload, details: notificationDetails);
  }

  @override
  Future<void> zonedSchedule({
    required int id,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? title,
    String? body,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    scheduled[id] = (
      at: scheduledDate,
      payload: payload,
      mode: androidScheduleMode,
    );
  }

  @override
  Future<void> cancel({required int id, String? tag}) async {
    shown.remove(id);
    scheduled.remove(id);
  }

  @override
  Future<List<PendingNotificationRequest>>
  pendingNotificationRequests() async => [
    for (final MapEntry(:key, :value) in scheduled.entries)
      PendingNotificationRequest(key, null, null, value.payload),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const timezone = MethodChannel('flutter_timezone');

  late _FakePlugin plugin;
  late FlutterSeedlyNotificationService service;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(timezone, (_) async => 'America/El_Salvador');
    plugin = _FakePlugin();
    service = FlutterSeedlyNotificationService(plugin: plugin);
  });

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(timezone, null),
  );

  group('toques', () {
    test('el handler de tareas sobrevive a las llamadas internas', () async {
      final tapped = <String>[];
      await service.initialize(onTaskReminderTap: tapped.add);

      // Antes, cada llamada interna volvía a llamar a initialize() sin
      // handlers y los dejaba en null.
      await service.cancelTaskReminder('t9');
      await service.cancelAllTaskReminders();
      plugin.tap('task:t1');

      expect(tapped, ['t1']);
    });

    test('un aviso de riego llega a su handler y no al de tareas', () async {
      final tasks = <String>[];
      final sessions = <String>[];
      await service.initialize(
        onTaskReminderTap: tasks.add,
        onWateringSessionTap: sessions.add,
      );

      await service.cancelWateringSessionEnd('s0');
      plugin.tap('watering:s1');

      expect(sessions, ['s1']);
      expect(tasks, isEmpty);
    });

    test('el aviso que abrió la app espera a que haya handler', () async {
      plugin.launch = const NotificationAppLaunchDetails(
        true,
        notificationResponse: NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: 'watering:s1',
        ),
      );
      final sessions = <String>[];

      // Como main(): primero sin handlers, después Inicio los registra.
      await service.initialize();
      await service.initialize(onWateringSessionTap: sessions.add);

      expect(sessions, ['s1']);
    });
  });

  group('riego', () {
    test(
      'el aviso de sesión es fijo, silencioso y se quita al final',
      () async {
        final endsAt = DateTime.now().add(const Duration(minutes: 25));

        await service.showWateringSessionNotification(
          sessionId: 's1',
          title: 'Regando tu Seedly',
          body: 'Sesión libre · termina a las 10:25 AM',
          endsAt: endsAt,
        );

        final notice = plugin.shown.values.single;
        final android = notice.details!.android!;
        expect(notice.payload, 'watering:s1');
        expect(android.channelId, 'seedly_watering');
        expect(android.ongoing, isTrue);
        expect(android.autoCancel, isFalse);
        expect(android.silent, isTrue);
        expect(android.onlyAlertOnce, isTrue);
        expect(
          android.timeoutAfter,
          closeTo(const Duration(minutes: 25).inMilliseconds, 5000),
        );
      },
    );

    test('en pausa el aviso no tiene final', () async {
      await service.showWateringSessionNotification(
        sessionId: 's1',
        title: 'Riego en pausa',
        body: 'Vuelve a Seedly para reanudar tu sesión.',
      );

      expect(plugin.shown.values.single.details!.android!.timeoutAfter, isNull);
    });

    test('programa el fin y lo cancela sin tocar el aviso fijo', () async {
      final at = DateTime.now().add(const Duration(minutes: 25));
      await service.showWateringSessionNotification(
        sessionId: 's1',
        title: 'Regando tu Seedly',
        body: '…',
        endsAt: at,
      );

      await service.scheduleWateringSessionEnd(
        sessionId: 's1',
        at: at,
        title: '¡Buen trabajo!',
        body: 'Tu sesión de riego terminó.',
      );

      final end = plugin.scheduled.values.single;
      expect(end.at.millisecondsSinceEpoch, at.millisecondsSinceEpoch);
      expect(end.payload, 'watering:s1');
      // Sin permiso de alarmas exactas, se programa inexacta.
      expect(end.mode, AndroidScheduleMode.inexactAllowWhileIdle);

      await service.cancelWateringSessionEnd('s1');

      expect(plugin.scheduled, isEmpty);
      expect(plugin.shown, hasLength(1));
    });

    test('cancelar los recordatorios de tareas no toca el riego', () async {
      await service.scheduleWateringSessionEnd(
        sessionId: 's1',
        at: DateTime.now().add(const Duration(minutes: 25)),
        title: '¡Buen trabajo!',
        body: 'Tu sesión de riego terminó.',
      );

      await service.cancelAllTaskReminders();

      expect(plugin.scheduled, hasLength(1));
    });

    test('sin zona horaria no programa el fin', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(timezone, (_) async => null);

      await service.scheduleWateringSessionEnd(
        sessionId: 's1',
        at: DateTime.now().add(const Duration(minutes: 25)),
        title: '¡Buen trabajo!',
        body: 'Tu sesión de riego terminó.',
      );

      expect(plugin.scheduled, isEmpty);
    });
  });
}
