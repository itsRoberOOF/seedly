import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/services/seedly_startup.dart';

import 'support/fake_seedly_auth_repository.dart';
import 'support/fake_seedly_drops_repository.dart';
import 'support/fake_seedly_project_repository.dart';
import 'support/fake_seedly_user_repository.dart';

/// Time is faked in these tests: pump moves it forward.
class _Run {
  _Run(this.startup) {
    startup.run(progress.add).then((_) => over = true);
  }

  final SeedlyStartup startup;
  final progress = <double>[];
  var over = false;

  double get value => progress.last;
}

/// A step; [description] is only there to read the test by.
SeedlyStartupStep _step(String description, Future<Object?> Function() run) =>
    run;

Future<void> _elapse(WidgetTester tester, int milliseconds) async {
  // In 50ms ticks, as the startup counts them.
  for (var spent = 0; spent < milliseconds; spent += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  group('without anything to load', () {
    testWidgets('the bar fills over the minimum time, then leaves', (
      tester,
    ) async {
      final run = _Run(SeedlyStartup(steps: const []));

      await _elapse(tester, 450);
      expect(run.value, closeTo(0.5, 0.06));
      expect(run.over, isFalse);

      await _elapse(tester, 500);
      expect(run.value, 1);
      expect(run.over, isFalse); // the full bar stays a moment

      await _elapse(tester, 300);
      expect(run.over, isTrue);
    });
  });

  group('with steps', () {
    testWidgets('starts at zero', (tester) async {
      final gate = Completer<void>();
      final run = _Run(
        SeedlyStartup(steps: [_step('Cargando tu perfil', () => gate.future)]),
      );

      expect(run.progress.first, 0);
      gate.complete();
      await _elapse(tester, 2000);
    });

    testWidgets('each finished step moves the bar on', (tester) async {
      final gates = List.generate(3, (_) => Completer<void>());
      final run = _Run(
        SeedlyStartup(
          steps: [
            for (final (i, gate) in gates.indexed)
              _step('Paso ${i + 1}', () => gate.future),
          ],
        ),
      );
      await _elapse(tester, 100);

      gates[0].complete();
      await _elapse(tester, 700);
      expect(run.value, inInclusiveRange(1 / 3, 2 / 3));

      gates[1].complete();
      await _elapse(tester, 700);
      expect(run.value, inInclusiveRange(2 / 3, 1.0));

      gates[2].complete();
      await _elapse(tester, 600);
      expect(run.value, 1);
    });

    testWidgets('the steps run together, not one after another', (
      tester,
    ) async {
      var started = 0;
      final gate = Completer<void>();
      _Run(
        SeedlyStartup(
          steps: [
            for (var i = 0; i < 4; i++)
              _step('Paso $i', () {
                started++;
                return gate.future;
              }),
          ],
        ),
      );

      expect(started, 4);
      gate.complete();
      await _elapse(tester, 2000);
    });

    testWidgets('the bar never goes backwards', (tester) async {
      final gates = List.generate(2, (_) => Completer<void>());
      final run = _Run(
        SeedlyStartup(
          steps: [
            for (final (i, gate) in gates.indexed)
              _step('Paso $i', () => gate.future),
          ],
        ),
      );

      await _elapse(tester, 600);
      gates[0].complete();
      await _elapse(tester, 600);
      gates[1].complete();
      await _elapse(tester, 1500);

      final values = run.progress;
      for (var i = 1; i < values.length; i++) {
        expect(values[i], greaterThanOrEqualTo(values[i - 1]));
      }
    });

    testWidgets('a slow step never leaves the bar frozen', (tester) async {
      final gate = Completer<void>();
      final run = _Run(
        SeedlyStartup(
          steps: [_step('Lento', () => gate.future)],
          stepTimeout: const Duration(seconds: 30),
        ),
      );

      await _elapse(tester, 1000);
      final early = run.value;
      await _elapse(tester, 2000);

      expect(run.value, greaterThan(early));
      expect(run.value, lessThan(1)); // it only creeps; the step has not ended
      gate.complete();
      await _elapse(tester, 2000);
    });

    testWidgets('nothing fills the bar faster than the minimum time', (
      tester,
    ) async {
      final run = _Run(SeedlyStartup(steps: [_step('Rápido', () async => 1)]));

      await _elapse(tester, 450);
      expect(run.value, lessThan(0.6));
      expect(run.over, isFalse);

      await _elapse(tester, 500);
      expect(run.value, 1);
      await _elapse(tester, 300);
      expect(run.over, isTrue);
    });

    testWidgets('a step that fails counts as done and does not stop the app', (
      tester,
    ) async {
      final run = _Run(
        SeedlyStartup(
          steps: [
            _step('Falla', () async => throw StateError('no element')),
            _step('Falla de otra forma', () => Future.error('offline')),
          ],
        ),
      );

      await _elapse(tester, 1300);

      expect(run.over, isTrue);
      expect(run.value, 1);
    });

    testWidgets('a step that throws before returning also counts as done', (
      tester,
    ) async {
      final run = _Run(
        SeedlyStartup(
          steps: [_step('Lanza', () => throw StateError('al instante'))],
        ),
      );

      await _elapse(tester, 1300);

      expect(run.over, isTrue);
    });

    testWidgets('a step that never answers is given up after the timeout', (
      tester,
    ) async {
      final run = _Run(
        SeedlyStartup(
          steps: [_step('Sin conexión', () => Completer<void>().future)],
          stepTimeout: const Duration(seconds: 2),
        ),
      );

      await _elapse(tester, 1900);
      expect(run.over, isFalse);

      await _elapse(tester, 600);
      expect(run.over, isTrue);
      expect(run.value, 1);
    });
  });

  group('cancel', () {
    testWidgets('ends the run and stops reporting', (tester) async {
      final run = _Run(
        SeedlyStartup(
          steps: [_step('Pendiente', () => Completer<void>().future)],
        ),
      );
      await _elapse(tester, 200);
      final reported = run.progress.length;

      run.startup.cancel();
      await tester.pump();
      await _elapse(tester, 3000);

      expect(run.over, isTrue);
      expect(run.progress, hasLength(reported));
    });

    testWidgets('leaves no timer behind', (tester) async {
      final run = _Run(
        SeedlyStartup(
          steps: [_step('Pendiente', () => Completer<void>().future)],
        ),
      );
      await _elapse(tester, 100);

      run.startup.cancel();
      // testWidgets fails the test if any timer is still pending at its end.
    });
  });

  group('seedlyStartupSteps', () {
    test('nobody signed in has nothing to load', () {
      final steps = seedlyStartupSteps(
        auth: FakeSeedlyAuthRepository(),
        projects: FakeSeedlyProjectRepository(),
        users: FakeSeedlyUserRepository(),
        drops: FakeSeedlyDropsRepository(),
      );

      expect(steps, isEmpty);
    });

    test('a signed-in person loads what Inicio reads first', () {
      final steps = seedlyStartupSteps(
        auth: FakeSeedlyAuthRepository(isSignedIn: true),
        projects: FakeSeedlyProjectRepository(),
        users: FakeSeedlyUserRepository(),
        drops: FakeSeedlyDropsRepository(),
      );

      // The profile, the plant, today's tasks and the projects.
      expect(steps, hasLength(4));
    });

    test('without the drops there is no plant to load', () {
      final steps = seedlyStartupSteps(
        auth: FakeSeedlyAuthRepository(isSignedIn: true),
        projects: FakeSeedlyProjectRepository(),
        users: FakeSeedlyUserRepository(),
      );

      expect(steps, hasLength(3));
    });

    test('each step waits for the first value of its stream', () async {
      final users = FakeSeedlyUserRepository();
      final steps = seedlyStartupSteps(
        auth: FakeSeedlyAuthRepository(isSignedIn: true),
        projects: FakeSeedlyProjectRepository(
          projects: Stream.value([]),
          tasksFrom: Stream.value([]),
        ),
        users: users,
        drops: FakeSeedlyDropsRepository(),
      );

      final profile = steps.first();
      expect(users.watchCalls, 1);
      users.emit(null);
      await expectLater(profile, completes);
      for (final step in steps.skip(1)) {
        await expectLater(step(), completes);
      }
    });
  });
}
