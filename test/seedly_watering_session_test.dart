import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/models/seedly_watering.dart';

void main() {
  final start = DateTime(2026, 11, 2, 10);

  DateTime at(int minutes, [int seconds = 0]) =>
      start.add(Duration(minutes: minutes, seconds: seconds));

  SeedlyWateringSession session({int minutes = 25}) => SeedlyWateringSession(
    id: 's1',
    ownerId: 'ana',
    minutes: minutes,
    startedAt: start,
  );

  group('la cuenta regresiva', () {
    test('cuenta el reloj desde el inicio', () {
      final running = session();

      expect(
        running.wateredAt(at(10, 30)),
        const Duration(minutes: 10, seconds: 30),
      );
      expect(
        running.remainingAt(at(10, 30)),
        const Duration(minutes: 14, seconds: 30),
      );
      expect(running.progressAt(at(10, 30)), closeTo(0.42, 0.001));
      expect(running.paidMinutesAt(at(10, 30)), 10);
      expect(running.isDoneAt(at(10, 30)), isFalse);
    });

    test('se detiene en su duración', () {
      final running = session();

      expect(running.wateredAt(at(40)), const Duration(minutes: 25));
      expect(running.remainingAt(at(40)), Duration.zero);
      expect(running.progressAt(at(40)), 1);
      expect(running.paidMinutesAt(at(40)), 25);
      expect(running.isDoneAt(at(25)), isTrue);
    });

    test('con el reloj antes del inicio no cuenta nada', () {
      expect(session().wateredAt(at(-5)), Duration.zero);
    });

    test('termina al inicio más su duración', () {
      expect(session().endsAt, at(25));
    });
  });

  group('la pausa', () {
    test('congela el tiempo regado y quita el final', () {
      final paused = session().pause(at(10));

      expect(paused.isPaused, isTrue);
      expect(paused.wateredAt(at(20)), const Duration(minutes: 10));
      expect(paused.endsAt, isNull);
    });

    test('al reanudar, el final se corre lo que duró la pausa', () {
      final resumed = session().pause(at(10)).resume(at(15));

      expect(resumed.isPaused, isFalse);
      expect(resumed.pausedFor, const Duration(minutes: 5));
      expect(resumed.endsAt, at(30));
      expect(resumed.wateredAt(at(20)), const Duration(minutes: 15));
    });

    test('pausar dos veces conserva la primera pausa', () {
      final paused = session().pause(at(10));

      expect(paused.pause(at(12)), paused);
      expect(session().resume(at(12)), session());
    });

    test('atrasar el reloj durante la pausa no suma tiempo', () {
      final resumed = session().pause(at(10)).resume(at(8));

      expect(resumed.pausedFor, Duration.zero);
    });
  });

  group('json', () {
    test('ida y vuelta con pausa y enfoque', () {
      final saved = SeedlyWateringSession(
        id: 's1',
        ownerId: 'ana',
        minutes: 40,
        startedAt: start,
        pausedFor: const Duration(minutes: 3),
        pausedAt: at(20),
        focusTaskId: 't1',
        focusTitle: 'Estudiar',
      );

      expect(SeedlyWateringSession.fromJson(saved.toJson()), saved);
      expect(SeedlyWateringSession.fromJson(session().toJson()), session());
    });

    test('lo que no es una sesión lanza FormatException', () {
      expect(
        () => SeedlyWateringSession.fromJson({'id': 's1'}),
        throwsFormatException,
      );
    });
  });
}
