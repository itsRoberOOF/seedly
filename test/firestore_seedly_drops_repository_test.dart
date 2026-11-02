import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/data/firebase/firestore_seedly_drops_repository.dart';
import 'package:seedly/models/seedly_drops.dart';
import 'package:seedly/models/seedly_errors.dart';

import 'support/fake_seedly_auth_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FakeSeedlyAuthRepository auth;
  late FirestoreSeedlyDropsRepository drops;
  final now = DateTime(2026, 10, 31, 15);

  setUp(() {
    firestore = FakeFirebaseFirestore();
    auth = FakeSeedlyAuthRepository(isSignedIn: true, uid: 'ana');
    drops = FirestoreSeedlyDropsRepository(
      auth: auth,
      firestore: firestore,
      clock: () => now,
    );
  });

  Future<void> seedTask(String id, {bool done = true, String owner = 'ana'}) =>
      firestore.collection('tasks').doc(id).set({
        'ownerId': owner,
        'done': done,
      });

  Future<void> seedProject(
    String id, {
    required int tasks,
    required int done,
  }) => firestore.collection('projects').doc(id).set({
    'ownerId': 'ana',
    'taskCount': tasks,
    'doneCount': done,
  });

  Future<Map<String, dynamic>?> drop(String id) async =>
      (await firestore.collection('drops').doc(id).get()).data();

  group('tasks', () {
    test('pays a done task under a fixed id', () async {
      await seedTask('t1');

      expect(await drops.addTaskDrops('t1'), 3);

      final data = (await drop('task_t1'))!;
      // firestore.rules rejects any other key.
      expect(
        data.keys,
        unorderedEquals(['ownerId', 'source', 'refId', 'amount', 'createdAt']),
      );
      expect(data['ownerId'], 'ana');
      expect(data['source'], 'task');
      expect(data['refId'], 't1');
      expect(data['amount'], 3);
    });

    test('pays each task once', () async {
      await seedTask('t1');
      await drops.addTaskDrops('t1');

      expect(await drops.addTaskDrops('t1'), 0);
      expect((await firestore.collection('drops').get()).docs, hasLength(1));
    });

    test('does not pay an undone or foreign task', () async {
      await seedTask('t1', done: false);
      await seedTask('t2', owner: 'beto');

      expect(await drops.addTaskDrops('t1'), 0);
      expect(await drops.addTaskDrops('t2'), 0);
      expect(await drops.addTaskDrops('missing'), 0);
      expect((await firestore.collection('drops').get()).docs, isEmpty);
    });

    test('stops paying after 20 tasks in a day', () async {
      for (var i = 0; i < 20; i++) {
        await firestore.collection('drops').doc('task_old$i').set({
          'ownerId': 'ana',
          'source': 'task',
          'refId': 'old$i',
          'amount': 3,
          'createdAt': Timestamp.fromDate(now.subtract(Duration(minutes: i))),
        });
      }
      await seedTask('t1');

      expect(await drops.addTaskDrops('t1'), 0);
    });

    test('tasks paid yesterday do not count toward the cap', () async {
      for (var i = 0; i < 20; i++) {
        await firestore.collection('drops').doc('task_old$i').set({
          'ownerId': 'ana',
          'source': 'task',
          'refId': 'old$i',
          'amount': 3,
          'createdAt': Timestamp.fromDate(DateTime(2026, 10, 30, 23)),
        });
      }
      await seedTask('t1');

      expect(await drops.addTaskDrops('t1'), 3);
    });

    test('removing takes the drops back and tolerates unpaid tasks', () async {
      await seedTask('t1');
      await drops.addTaskDrops('t1');

      await drops.removeTaskDrops('t1');
      await drops.removeTaskDrops('never-paid');

      expect(await drop('task_t1'), isNull);
    });
  });

  group('projects', () {
    test('pays a complete project of three or more tasks once', () async {
      await seedProject('p1', tasks: 3, done: 3);

      expect(await drops.addProjectDrops('p1'), 10);
      expect(await drops.addProjectDrops('p1'), 0);
      expect((await drop('project_p1'))!['amount'], 10);
    });

    test('does not pay small or unfinished projects', () async {
      await seedProject('small', tasks: 2, done: 2);
      await seedProject('open', tasks: 4, done: 3);

      expect(await drops.addProjectDrops('small'), 0);
      expect(await drops.addProjectDrops('open'), 0);
      expect(await drops.addProjectDrops('missing'), 0);
    });
  });

  group('watering', () {
    test('starts a session stamped by the server', () async {
      final id = await drops.startWateringSession();

      final data = (await firestore.collection('sessions').doc(id).get())
          .data()!;
      // firestore.rules rejects any other key.
      expect(data.keys, unorderedEquals(['ownerId', 'startedAt']));
      expect(data['ownerId'], 'ana');
    });

    test('pays whole minutes once per session', () async {
      final id = await drops.startWateringSession();

      expect(await drops.payWateringSession(id, 45), 45);
      expect(await drops.payWateringSession(id, 45), 0);
      expect((await drop('watering_$id'))!['amount'], 45);
    });

    test('caps a session at 120 minutes and skips empty ones', () async {
      final long = await drops.startWateringSession();
      final empty = await drops.startWateringSession();

      expect(await drops.payWateringSession(long, 500), 120);
      expect(await drops.payWateringSession(empty, 0), 0);
      expect(await drop('watering_$empty'), isNull);
    });
  });

  group('plant', () {
    Future<void> seedDrops(int amount) =>
        firestore.collection('drops').doc('watering_seed').set({
          'ownerId': 'ana',
          'source': 'watering',
          'refId': 'seed',
          'amount': amount,
          'createdAt': Timestamp.fromDate(now),
        });

    test('a new user starts in phase 1 with no drops', () async {
      expect(
        await drops.watchPlantState().first,
        const SeedlyPlantState(phase: 1, totalDrops: 0),
      );
      final progress = (await firestore.collection('progress').doc('ana').get())
          .data()!;
      // firestore.rules rejects any other key.
      expect(progress.keys, unorderedEquals(['phase', 'updatedAt']));
      expect(progress['phase'], 1);
    });

    test('sums only the user drops and updates after paying', () async {
      await seedDrops(20);
      await firestore.collection('drops').doc('task_x').set({
        'ownerId': 'beto',
        'amount': 999,
      });
      await seedTask('t1');
      final states = <SeedlyPlantState>[];
      final subscription = drops.watchPlantState().listen(states.add);
      // Lets the fake's snapshot and sum resolve.
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await drops.addTaskDrops('t1');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(states.first.totalDrops, 20);
      expect(states.last.totalDrops, 23);
      await subscription.cancel();
    });

    test('grows one phase when the goal is reached', () async {
      await seedDrops(600);

      await drops.growPlant();

      expect(
        await drops.watchPlantState().first,
        const SeedlyPlantState(phase: 2, totalDrops: 600),
      );
    });

    test('refuses to grow without enough drops', () async {
      await seedDrops(149);

      expect(
        drops.growPlant,
        throwsA(
          isA<SeedlyDropsException>().having(
            (e) => e.reason,
            'reason',
            SeedlyDropsError.notEnoughDrops,
          ),
        ),
      );
    });
  });

  test('an empty id pays nothing and does not throw', () async {
    expect(await drops.addTaskDrops(''), 0);
    expect(await drops.addProjectDrops(''), 0);
    await drops.removeTaskDrops('');
    expect((await firestore.collection('drops').get()).docs, isEmpty);
  });

  test('signed out, every call reports an expired session', () async {
    auth.isSignedIn = false;

    expect(
      () => drops.addTaskDrops('t1'),
      throwsA(
        isA<SeedlyDropsException>().having(
          (e) => e.reason,
          'reason',
          SeedlyDropsError.sessionExpired,
        ),
      ),
    );
  });
}
