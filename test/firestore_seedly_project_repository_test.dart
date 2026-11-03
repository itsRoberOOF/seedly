import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/data/firebase/firestore_seedly_project_repository.dart';
import 'package:seedly/models/seedly_drops.dart';
import 'package:seedly/models/seedly_errors.dart';
import 'package:seedly/models/seedly_project.dart';

import 'support/fake_seedly_auth_repository.dart';

/// A Firestore whose batches take effect at once, as offline writes do in the
/// local cache, but only report done when [gate] completes, like a server
/// that is slow to answer.
class _SlowServerFirestore extends FakeFirebaseFirestore {
  _SlowServerFirestore(this.gate);

  final Future<void> gate;

  @override
  WriteBatch batch() => _SlowBatch(super.batch(), gate);
}

class _SlowBatch implements WriteBatch {
  _SlowBatch(this._inner, this._gate);

  final WriteBatch _inner;
  final Future<void> _gate;

  @override
  Future<void> commit() {
    final applied = _inner.commit();
    return _gate.then((_) => applied);
  }

  @override
  void delete(DocumentReference document) => _inner.delete(document);

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) =>
      _inner.set(document, data, options);

  @override
  void update<T>(DocumentReference<T> document, T data) =>
      _inner.update(document, data);
}

/// A Firestore whose server refuses every batch, as firestore.rules would.
class _RefusingServerFirestore extends FakeFirebaseFirestore {
  @override
  WriteBatch batch() => _RefusedBatch(super.batch());
}

class _RefusedBatch implements WriteBatch {
  _RefusedBatch(this._inner);

  final WriteBatch _inner;

  @override
  Future<void> commit() => Future.error(
    FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
  );

  @override
  void delete(DocumentReference document) => _inner.delete(document);

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) =>
      _inner.set(document, data, options);

  @override
  void update<T>(DocumentReference<T> document, T data) =>
      _inner.update(document, data);
}

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreSeedlyProjectRepository projects;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    projects = FirestoreSeedlyProjectRepository(
      auth: FakeSeedlyAuthRepository(isSignedIn: true, uid: 'ana'),
      firestore: firestore,
    );
  });

  test('writes the project to the root collection with its owner', () async {
    final save = await projects.create(
      NewSeedlyProject(
        name: 'Huerto',
        kind: SeedlyProjectKind.full,
        description: 'Tomates',
        icon: SeedlyProjectIcon.hogar,
        photo: Uint8List.fromList([1, 2, 3]),
        startDate: DateTime(2026, 10, 13),
        endDate: DateTime(2026, 10, 30),
        tasks: const [
          NewSeedlyTask('Sembrar', done: true),
          NewSeedlyTask('Regar'),
        ],
      ),
    );
    expect(save, SeedlyProjectSave.saved);

    final project = (await firestore.collection('projects').get()).docs.single;
    final data = project.data();
    expect(data['ownerId'], 'ana');
    expect(data['name'], 'Huerto');
    expect(data['description'], 'Tomates');
    expect(data['icon'], 'hogar');
    expect(data['kind'], 'full');
    expect((data['photo'] as Blob).bytes, [1, 2, 3]);
    expect((data['startDate'] as Timestamp).toDate(), DateTime(2026, 10, 13));
    expect((data['endDate'] as Timestamp).toDate(), DateTime(2026, 10, 30));
    // Progress for the project list.
    expect(data['taskCount'], 2);
    expect(data['doneCount'], 1);
    // Nothing lands under the user any more.
    expect(
      (await firestore
              .collection('users')
              .doc('ana')
              .collection('projects')
              .get())
          .docs,
      isEmpty,
    );
  });

  test('writes tasks to the root collection linked to the project', () async {
    await projects.create(
      NewSeedlyProject(
        name: 'Huerto',
        kind: SeedlyProjectKind.full,
        tasks: [
          const NewSeedlyTask('Sembrar'),
          NewSeedlyTask(
            'Regar',
            done: true,
            dueDate: DateTime(2026, 10, 14),
            dueMinutes: 9 * 60,
            reminderMinutes: 30,
          ),
        ],
      ),
    );
    final projectId =
        (await firestore.collection('projects').get()).docs.single.id;
    final tasks =
        (await firestore
                .collection('tasks')
                .where('ownerId', isEqualTo: 'ana')
                .where('projectId', isEqualTo: projectId)
                .orderBy('order')
                .get())
            .docs
            .map((doc) => doc.data())
            .toList();

    expect(tasks, hasLength(2));
    expect(tasks[0]['title'], 'Sembrar');
    expect(tasks[0]['done'], isFalse);
    expect(tasks[0]['dueDate'], isNull);
    expect(tasks[1]['title'], 'Regar');
    expect(tasks[1]['done'], isTrue);
    expect(tasks[1]['order'], 1);
    expect((tasks[1]['dueDate'] as Timestamp).toDate(), DateTime(2026, 10, 14));
    expect(tasks[1]['dueMinutes'], 540);
    expect(tasks[1]['reminderMinutes'], 30);
  });

  test('without a session it refuses to write', () async {
    final signedOut = FirestoreSeedlyProjectRepository(
      auth: FakeSeedlyAuthRepository(),
      firestore: firestore,
    );
    await expectLater(
      signedOut.create(
        NewSeedlyProject(name: 'Huerto', kind: SeedlyProjectKind.express),
      ),
      throwsA(
        isA<SeedlyProjectException>().having(
          (error) => error.reason,
          'reason',
          SeedlyProjectError.sessionExpired,
        ),
      ),
    );
    expect((await firestore.collection('projects').get()).docs, isEmpty);
  });

  test('watchProjects reads only the owner\'s, newest first', () async {
    Future<void> add(String id, String owner, DateTime? createdAt, int done) =>
        firestore.collection('projects').doc(id).set({
          'ownerId': owner,
          'name': id,
          'description': null,
          'icon': 'hogar',
          'kind': 'full',
          'startDate': null,
          'endDate': null,
          'taskCount': 4,
          'doneCount': done,
          'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt),
        });
    await add('viejo', 'ana', DateTime(2026, 10, 1), 1);
    await add('nuevo', 'ana', DateTime(2026, 11, 1), 4);
    await add('pendiente', 'ana', null, 0);
    await add('ajeno', 'luis', DateTime(2026, 11, 2), 0);

    final list = await projects.watchProjects().first;

    expect(list.map((project) => project.id), ['pendiente', 'nuevo', 'viejo']);
    final nuevo = list[1];
    expect(nuevo.name, 'nuevo');
    expect(nuevo.icon, SeedlyProjectIcon.hogar);
    expect(nuevo.kind, SeedlyProjectKind.full);
    expect(nuevo.taskCount, 4);
    expect(nuevo.isComplete, isTrue);
  });

  test(
    'watchProjects falls back to the default icon it does not know',
    () async {
      await firestore.collection('projects').doc('raro').set({
        'ownerId': 'ana',
        'name': 'Raro',
        'icon': 'de-otra-version',
        'kind': 'express',
        'taskCount': 0,
        'doneCount': 0,
      });

      final list = await projects.watchProjects().first;

      expect(list.single.icon, SeedlyProjectIcon.planta);
      expect(list.single.description, isNull);
      expect(list.single.startDate, isNull);
    },
  );

  test('watchProjects is empty without a session', () async {
    final signedOut = FirestoreSeedlyProjectRepository(
      auth: FakeSeedlyAuthRepository(),
      firestore: firestore,
    );

    expect(await signedOut.watchProjects().toList(), isEmpty);
  });

  test('watchTasksOn filters by owner and uses an exclusive day end', () async {
    await firestore.collection('tasks').doc('today').set({
      'ownerId': 'ana',
      'projectId': 'project-1',
      'title': 'Sembrar',
      'done': false,
      'order': 1,
      'dueDate': Timestamp.fromDate(DateTime(2026, 11, 2, 8)),
      'dueMinutes': 8 * 60,
      'reminderMinutes': 30,
    });
    await firestore.collection('tasks').doc('today-first').set({
      'ownerId': 'ana',
      'projectId': 'project-1',
      'title': 'Preparar',
      'done': false,
      'order': 0,
      'dueDate': Timestamp.fromDate(DateTime(2026, 11, 2, 7)),
      'dueMinutes': 7 * 60,
      'reminderMinutes': null,
    });
    await firestore.collection('tasks').doc('tomorrow').set({
      'ownerId': 'ana',
      'projectId': 'project-1',
      'title': 'Regar',
      'done': false,
      'order': 0,
      'dueDate': Timestamp.fromDate(DateTime(2026, 11, 3)),
      'dueMinutes': null,
      'reminderMinutes': null,
    });
    await firestore.collection('tasks').doc('other-owner').set({
      'ownerId': 'luis',
      'projectId': 'project-2',
      'title': 'No mostrar',
      'done': false,
      'order': 0,
      'dueDate': Timestamp.fromDate(DateTime(2026, 11, 2, 9)),
      'dueMinutes': 9 * 60,
      'reminderMinutes': null,
    });
    await firestore.collection('tasks').doc('no-date').set({
      'ownerId': 'ana',
      'projectId': 'project-1',
      'title': 'Sin fecha',
      'done': false,
      'order': 3,
      'dueDate': null,
      'dueMinutes': null,
      'reminderMinutes': null,
    });

    final tasks = await projects.watchTasksOn(DateTime(2026, 11, 2)).first;

    expect(tasks.map((task) => task.id), ['today-first', 'today']);
    expect(tasks.first.dueDate, DateTime(2026, 11, 2, 7));
  });

  test(
    'watchTasksFrom includes only owned tasks on or after the day',
    () async {
      await firestore.collection('tasks').doc('past').set({
        'ownerId': 'ana',
        'projectId': 'project-1',
        'title': 'Pasada',
        'done': false,
        'order': 0,
        'dueDate': Timestamp.fromDate(DateTime(2026, 11, 1)),
        'dueMinutes': null,
        'reminderMinutes': null,
      });
      await firestore.collection('tasks').doc('future').set({
        'ownerId': 'ana',
        'projectId': 'project-1',
        'title': 'Futura',
        'done': false,
        'order': 0,
        'dueDate': Timestamp.fromDate(DateTime(2026, 11, 3)),
        'dueMinutes': 9 * 60,
        'reminderMinutes': 30,
      });
      await firestore.collection('tasks').doc('other-future').set({
        'ownerId': 'luis',
        'projectId': 'project-2',
        'title': 'No mostrar',
        'done': false,
        'order': 0,
        'dueDate': Timestamp.fromDate(DateTime(2026, 11, 4)),
        'dueMinutes': 9 * 60,
        'reminderMinutes': null,
      });

      final tasks = await projects.watchTasksFrom(DateTime(2026, 11, 2)).first;

      expect(tasks.map((task) => task.id), ['future']);
    },
  );

  group('reading', () {
    Future<void> seedProject(
      String id, {
      String owner = 'ana',
      int tasks = 0,
    }) => firestore.collection('projects').doc(id).set({
      'ownerId': owner,
      'name': 'Proyecto $id',
      'kind': 'full',
      'icon': 'hogar',
      'taskCount': tasks,
      'doneCount': 0,
    });

    test('watchProjects lists only the owner\'s projects', () async {
      await seedProject('a');
      await seedProject('b', owner: 'luis');
      final list = await projects.watchProjects().first;
      expect(list.map((project) => project.id), ['a']);
      expect(list.single.name, 'Proyecto a');
      expect(list.single.icon, SeedlyProjectIcon.hogar);
      expect(list.single.kind, SeedlyProjectKind.full);
    });

    test('watchProject emits null when the project is missing', () async {
      await seedProject('b', owner: 'luis');
      expect(await projects.watchProject('b').first, isNull);
      expect(await projects.watchProject('nope').first, isNull);
    });

    test('watchProject emits the project', () async {
      await seedProject('a', tasks: 3);
      final project = await projects.watchProject('a').first;
      expect(project?.taskCount, 3);
      expect(project?.progress, 0);
    });

    test('watchTasks returns the project\'s tasks in order', () async {
      Future<void> task(String id, int order, {String project = 'p'}) =>
          firestore.collection('tasks').doc(id).set({
            'ownerId': 'ana',
            'projectId': project,
            'title': id,
            'done': false,
            'order': order,
          });
      await task('second', 1);
      await task('first', 0);
      await task('elsewhere', 0, project: 'other');
      final tasks = await projects.watchTasks('p').first;
      expect(tasks.map((task) => task.id), ['first', 'second']);
    });
  });

  group('writing', () {
    Future<String> seed({int tasks = 3, int done = 1}) async {
      await firestore.collection('projects').doc('p').set({
        'ownerId': 'ana',
        'name': 'Huerto',
        'kind': 'full',
        'icon': 'planta',
        'taskCount': tasks,
        'doneCount': done,
      });
      for (var i = 0; i < tasks; i++) {
        await firestore.collection('tasks').doc('t$i').set({
          'ownerId': 'ana',
          'projectId': 'p',
          'title': 'Tarea $i',
          'done': i < done,
          'order': i,
        });
      }
      return 'p';
    }

    Future<Map<String, dynamic>> project() async =>
        (await firestore.collection('projects').doc('p').get()).data()!;

    test('setTaskDone marks the task and bumps doneCount', () async {
      await seed();
      await projects.setTaskDone('t1', true);
      final task = (await firestore.collection('tasks').doc('t1').get());
      expect(task.data()!['done'], isTrue);
      expect((await project())['doneCount'], 2);
    });

    test('setTaskDone unmarks and lowers doneCount', () async {
      await seed();
      await projects.setTaskDone('t0', false);
      expect((await project())['doneCount'], 0);
    });

    test('setTaskDone with the same state changes nothing', () async {
      await seed();
      await projects.setTaskDone('t0', true);
      expect((await project())['doneCount'], 1);
    });

    test('addTask appends with the next order and bumps taskCount', () async {
      await seed();
      await projects.addTask(
        'p',
        NewSeedlyTask(
          'Cosechar',
          dueDate: DateTime(2026, 11, 5),
          dueMinutes: 600,
          reminderMinutes: 10,
        ),
      );
      final added =
          (await firestore
                  .collection('tasks')
                  .where('title', isEqualTo: 'Cosechar')
                  .get())
              .docs
              .single
              .data();
      expect(added['ownerId'], 'ana');
      expect(added['projectId'], 'p');
      expect(added['order'], 3);
      expect(added['done'], isFalse);
      expect(added['reminderMinutes'], 10);
      expect((await project())['taskCount'], 4);
      expect((await project())['doneCount'], 1);
    });

    test('addTask of a done task also bumps doneCount', () async {
      await seed();
      await projects.addTask('p', const NewSeedlyTask('Listo', done: true));
      expect((await project())['taskCount'], 4);
      expect((await project())['doneCount'], 2);
    });

    test('updateTask edits the fields but not done or the project', () async {
      await seed();
      await projects.updateTask(
        't0',
        NewSeedlyTask(
          'Nuevo título',
          dueDate: DateTime(2026, 11, 6),
          dueMinutes: 480,
          reminderMinutes: 30,
        ),
      );
      final data = (await firestore.collection('tasks').doc('t0').get())
          .data()!;
      expect(data['title'], 'Nuevo título');
      expect(data['done'], isTrue);
      expect(data['projectId'], 'p');
      expect(data['dueMinutes'], 480);
      expect(data['reminderMinutes'], 30);
    });

    group('moveTask', () {
      Future<void> seedTarget({int tasks = 1, int done = 0}) async {
        await firestore.collection('projects').doc('p2').set({
          'ownerId': 'ana',
          'name': 'Jardín',
          'kind': 'full',
          'icon': 'flor',
          'taskCount': tasks,
          'doneCount': done,
        });
        for (var i = 0; i < tasks; i++) {
          await firestore.collection('tasks').doc('q$i').set({
            'ownerId': 'ana',
            'projectId': 'p2',
            'title': 'Otra $i',
            'done': i < done,
            'order': i,
          });
        }
      }

      Future<Map<String, dynamic>> target() async =>
          (await firestore.collection('projects').doc('p2').get()).data()!;

      Future<QueryDocumentSnapshot<Map<String, dynamic>>> movedTask() async =>
          (await firestore
                  .collection('tasks')
                  .where('projectId', isEqualTo: 'p2')
                  .where('title', isEqualTo: 'Reubicada')
                  .get())
              .docs
              .single;

      test('relocates a done task and fixes both projects', () async {
        await seed(); // p: 3 tasks, t0 done
        await seedTarget(); // p2: 1 task
        await projects.moveTask('t0', 'p2', const NewSeedlyTask('Reubicada'));

        // Gone from its old project, recreated at the end of the new one.
        expect(
          (await firestore.collection('tasks').doc('t0').get()).exists,
          isFalse,
        );
        final moved = (await movedTask()).data();
        expect(moved['done'], isTrue);
        expect(moved['order'], 1);
        expect(moved['ownerId'], 'ana');

        expect((await project())['taskCount'], 2);
        expect((await project())['doneCount'], 0);
        expect((await target())['taskCount'], 2);
        expect((await target())['doneCount'], 1);
      });

      test('carries the reward drop over to the new id', () async {
        await seed();
        await seedTarget();
        await firestore.collection('drops').doc('task_t0').set({
          'ownerId': 'ana',
          'source': 'task',
          'refId': 't0',
          'amount': 3,
        });
        await projects.moveTask('t0', 'p2', const NewSeedlyTask('Reubicada'));

        final newId = (await movedTask()).id;
        expect(
          (await firestore.collection('drops').doc('task_t0').get()).exists,
          isFalse,
        );
        final drop = (await firestore
            .collection('drops')
            .doc('task_$newId')
            .get());
        expect(drop.data()!['amount'], 3);
        expect(drop.data()!['refId'], newId);
      });

      test('a pending task moves without any drop', () async {
        await seed();
        await seedTarget();
        await projects.moveTask('t2', 'p2', const NewSeedlyTask('Reubicada'));

        expect((await target())['doneCount'], 0);
        expect((await firestore.collection('drops').get()).docs, isEmpty);
      });

      test('to the same project just edits in place', () async {
        await seed();
        await projects.moveTask(
          't0',
          'p',
          NewSeedlyTask('Reubicada', dueDate: DateTime(2026, 11, 9)),
        );

        final data = (await firestore.collection('tasks').doc('t0').get())
            .data()!;
        expect(data['title'], 'Reubicada');
        expect(data['done'], isTrue); // unchanged
        expect(data['projectId'], 'p');
        expect((await project())['taskCount'], 3);
      });
    });

    test('deleteTask lowers both counters when the task was done', () async {
      await seed();
      await projects.deleteTask('t0');
      expect(
        (await firestore.collection('tasks').doc('t0').get()).exists,
        isFalse,
      );
      expect((await project())['taskCount'], 2);
      expect((await project())['doneCount'], 0);
    });

    test('deleteTask of a pending task keeps doneCount', () async {
      await seed();
      await projects.deleteTask('t2');
      expect((await project())['taskCount'], 2);
      expect((await project())['doneCount'], 1);
    });

    group('the same task at once', () {
      Future<Object?> outcome(Future<void> write) =>
          write.then<Object?>((_) => null, onError: (Object error) => error);

      Matcher notFound() => isA<SeedlyProjectException>().having(
        (error) => error.reason,
        'reason',
        SeedlyProjectError.notFound,
      );

      Future<bool> done(String id) async =>
          (await firestore.collection('tasks').doc(id).get()).data()!['done']
              as bool;

      test('two ticks count once', () async {
        await seed(tasks: 4, done: 0);

        await Future.wait([
          projects.setTaskDone('t1', true),
          projects.setTaskDone('t1', true),
        ]);

        expect(await done('t1'), isTrue);
        expect((await project())['doneCount'], 1);
      });

      test('two unticks count once', () async {
        await seed(tasks: 4, done: 2);

        await Future.wait([
          projects.setTaskDone('t0', false),
          projects.setTaskDone('t0', false),
        ]);

        expect(await done('t0'), isFalse);
        expect((await project())['doneCount'], 1);
      });

      test('five quick taps on a pending task count once', () async {
        await seed(tasks: 4, done: 0);

        await Future.wait([
          for (var tap = 0; tap < 5; tap++) projects.setTaskDone('t1', true),
        ]);

        expect((await project())['doneCount'], 1);
      });

      test('a tick and an untick together end unticked and even', () async {
        await seed(tasks: 4, done: 0);

        await Future.wait([
          projects.setTaskDone('t1', true),
          projects.setTaskDone('t1', false),
        ]);

        expect(await done('t1'), isFalse);
        expect((await project())['doneCount'], 0);
      });

      test(
        'two deletes lower taskCount once and the second finds nothing',
        () async {
          await seed(tasks: 4, done: 0);

          final outcomes = await Future.wait([
            outcome(projects.deleteTask('t1')),
            outcome(projects.deleteTask('t1')),
          ]);

          expect(outcomes.whereType<SeedlyProjectException>(), hasLength(1));
          expect(
            outcomes.whereType<SeedlyProjectException>().single,
            notFound(),
          );
          expect((await project())['taskCount'], 3);
        },
      );

      test('a tick and a delete together keep the counters even', () async {
        await seed(tasks: 4, done: 0);

        await Future.wait([
          projects.setTaskDone('t1', true),
          projects.deleteTask('t1'),
        ]);

        expect((await project())['taskCount'], 3);
        expect((await project())['doneCount'], 0);
      });

      test('different tasks both count', () async {
        await seed(tasks: 4, done: 0);

        await Future.wait([
          projects.setTaskDone('t1', true),
          projects.setTaskDone('t2', true),
        ]);

        expect((await project())['doneCount'], 2);
      });

      test('a failed write does not block the next on that task', () async {
        await seed(tasks: 4, done: 0);
        await projects.deleteTask('t1');

        await expectLater(projects.deleteTask('t1'), throwsA(notFound()));
        await expectLater(
          projects.setTaskDone('t1', true),
          throwsA(notFound()),
        );
        // Others are untouched by that task's failures.
        await projects.setTaskDone('t2', true);
        expect((await project())['doneCount'], 1);
      });

      test('the next tap waits for the write, not for the server', () async {
        final server = Completer<void>();
        final slow = _SlowServerFirestore(server.future);
        final repository = FirestoreSeedlyProjectRepository(
          auth: FakeSeedlyAuthRepository(isSignedIn: true, uid: 'ana'),
          firestore: slow,
        );
        await slow.collection('projects').doc('p').set({
          'ownerId': 'ana',
          'name': 'Huerto',
          'kind': 'full',
          'icon': 'planta',
          'taskCount': 3,
          'doneCount': 0,
        });
        await slow.collection('tasks').doc('t1').set({
          'ownerId': 'ana',
          'projectId': 'p',
          'title': 'Tarea',
          'done': false,
          'order': 0,
        });

        // Tick, then untick, while the server has not answered the first.
        final first = repository.setTaskDone('t1', true);
        final second = repository.setTaskDone('t1', false);
        await pumpEventQueue();

        // The second already ran: it saw the first's write and undid it, so
        // it did not wait for the server to reply.
        expect(
          (await slow.collection('tasks').doc('t1').get())['done'],
          isFalse,
        );
        expect(
          (await slow.collection('projects').doc('p').get())['doneCount'],
          0,
        );

        server.complete();
        await Future.wait([first, second]);
        expect(
          (await slow.collection('projects').doc('p').get())['doneCount'],
          0,
        );
      });
    });

    group('settleTaskDone', () {
      final now = DateTime(2026, 10, 31, 15);

      SeedlyTask task(String id) =>
          SeedlyTask(id: id, projectId: 'p', title: id, done: false, order: 0);

      Future<Map<String, dynamic>?> drop(String id) async =>
          (await firestore.collection('drops').doc(id).get()).data();

      Future<List<String>> drops() async => [
        for (final doc in (await firestore.collection('drops').get()).docs)
          doc.id,
      ];

      Future<void> seedPaidTasks(int count, DateTime at) async {
        for (var i = 0; i < count; i++) {
          await firestore.collection('drops').doc('task_old$i').set({
            'ownerId': 'ana',
            'source': 'task',
            'refId': 'old$i',
            'amount': 3,
            'createdAt': Timestamp.fromDate(at),
          });
        }
      }

      /// A repository over a server that hasn't answered: as on a phone,
      /// each batch is in the local view at once while `saved` waits for
      /// [server]. The fake applies a batch over a few microtasks, so
      /// [settled] lets it land, as the phone does within the same tap.
      FirestoreSeedlyProjectRepository slowServer(Completer<void> server) {
        firestore = _SlowServerFirestore(server.future);
        return FirestoreSeedlyProjectRepository(
          auth: FakeSeedlyAuthRepository(isSignedIn: true, uid: 'ana'),
          firestore: firestore,
          clock: () => now,
        );
      }

      Future<SeedlyTaskToggle> settled(Future<SeedlyTaskToggle> tick) async {
        final toggle = await tick;
        await pumpEventQueue();
        return toggle;
      }

      test('ticks the task and pays it in the same write', () async {
        await seed(tasks: 4, done: 1);

        final toggle = await projects.settleTaskDone(task('t1'), true);
        await toggle.saved;

        expect(toggle.drops, const SeedlyDropsChange(task: 3));
        expect(
          (await firestore.collection('tasks').doc('t1').get())['done'],
          isTrue,
        );
        expect((await project())['doneCount'], 2);
        final paid = (await drop('task_t1'))!;
        // firestore.rules rejects any other key.
        expect(
          paid.keys,
          unorderedEquals([
            'ownerId',
            'source',
            'refId',
            'amount',
            'createdAt',
          ]),
        );
        expect(paid['amount'], 3);
        expect(paid['source'], 'task');
      });

      test('the tick that finishes the project pays it too', () async {
        await seed(tasks: 3, done: 2);

        final toggle = await projects.settleTaskDone(task('t2'), true);
        await toggle.saved;

        expect(toggle.drops, const SeedlyDropsChange(task: 3, project: 10));
        expect(await drops(), unorderedEquals(['task_t2', 'project_p']));
        expect((await drop('project_p'))!['amount'], 10);
      });

      test(
        'unticking takes the task drop back and keeps the project one',
        () async {
          await seed(tasks: 3, done: 2);
          await (await projects.settleTaskDone(task('t2'), true)).saved;

          final untick = await projects.settleTaskDone(task('t2'), false);
          await untick.saved;
          expect(untick.drops, const SeedlyDropsChange(task: -3));
          expect(await drops(), ['project_p']);
          expect((await project())['doneCount'], 2);

          // Finishing it again pays the task, but the project only once.
          final tick = await projects.settleTaskDone(task('t2'), true);
          await tick.saved;
          expect(tick.drops, const SeedlyDropsChange(task: 3));
          expect(await drops(), unorderedEquals(['task_t2', 'project_p']));
        },
      );

      test('stops paying tasks at the daily cap', () async {
        final capped = FirestoreSeedlyProjectRepository(
          auth: FakeSeedlyAuthRepository(isSignedIn: true, uid: 'ana'),
          firestore: firestore,
          clock: () => now,
        );
        await seed(tasks: 4, done: 0);
        await seedPaidTasks(20, now);

        final toggle = await capped.settleTaskDone(task('t1'), true);
        await toggle.saved;

        expect(toggle.drops, const SeedlyDropsChange(capped: true));
        expect(await drop('task_t1'), isNull);
        expect((await project())['doneCount'], 1);
      });

      test('tasks paid yesterday do not count toward the cap', () async {
        final capped = FirestoreSeedlyProjectRepository(
          auth: FakeSeedlyAuthRepository(isSignedIn: true, uid: 'ana'),
          firestore: firestore,
          clock: () => now,
        );
        await seed(tasks: 4, done: 0);
        await seedPaidTasks(20, now.subtract(const Duration(days: 1)));

        final toggle = await capped.settleTaskDone(task('t1'), true);

        expect(toggle.drops, const SeedlyDropsChange(task: 3));
      });

      test('the same state changes nothing', () async {
        await seed();

        final toggle = await projects.settleTaskDone(task('t0'), true);

        expect(toggle.drops, SeedlyDropsChange.none);
        expect((await project())['doneCount'], 1);
        expect(await drops(), isEmpty);
      });

      test('answers and writes before the server does', () async {
        final server = Completer<void>();
        final repository = slowServer(server);
        await seed(tasks: 3, done: 0);

        final toggle = await settled(
          repository.settleTaskDone(task('t1'), true),
        );

        // Known and in the local view while the server hasn't answered.
        expect(toggle.drops, const SeedlyDropsChange(task: 3));
        expect(await drop('task_t1'), isNotNull);
        var saved = false;
        unawaited(toggle.saved.then((_) => saved = true));
        await pumpEventQueue();
        expect(saved, isFalse);

        server.complete();
        await toggle.saved;
        expect(saved, isTrue);
      });

      test('a quick second tick in the project sees the first', () async {
        final server = Completer<void>();
        final repository = slowServer(server);
        await seed(tasks: 3, done: 1);

        final first = await settled(
          repository.settleTaskDone(task('t1'), true),
        );
        final second = await settled(
          repository.settleTaskDone(task('t2'), true),
        );

        // Neither waited for the server, yet the second finished the project.
        expect(first.drops, const SeedlyDropsChange(task: 3));
        expect(second.drops, const SeedlyDropsChange(task: 3, project: 10));
        expect((await project())['doneCount'], 3);
        expect(
          await drops(),
          unorderedEquals(['task_t1', 'task_t2', 'project_p']),
        );
        server.complete();
      });

      test('a quick untick takes back the tick it follows', () async {
        final server = Completer<void>();
        final repository = slowServer(server);
        await seed(tasks: 4, done: 0);

        final tick = await settled(repository.settleTaskDone(task('t1'), true));
        final untick = await settled(
          repository.settleTaskDone(task('t1'), false),
        );

        expect(tick.drops, const SeedlyDropsChange(task: 3));
        expect(untick.drops, const SeedlyDropsChange(task: -3));
        expect(await drops(), isEmpty);
        expect((await project())['doneCount'], 0);
        server.complete();
      });

      test('two taps at once settle the task once', () async {
        await seed(tasks: 4, done: 0);

        final toggles = await Future.wait([
          projects.settleTaskDone(task('t1'), true),
          projects.settleTaskDone(task('t1'), true),
        ]);
        await Future.wait([for (final toggle in toggles) toggle.saved]);

        expect(
          toggles.where((toggle) => toggle.drops != SeedlyDropsChange.none),
          hasLength(1),
        );
        expect((await project())['doneCount'], 1);
        expect(await drops(), ['task_t1']);
      });

      test('a write the server refuses is reported through saved', () async {
        final refusing = _RefusingServerFirestore();
        final repository = FirestoreSeedlyProjectRepository(
          auth: FakeSeedlyAuthRepository(isSignedIn: true, uid: 'ana'),
          firestore: refusing,
        );
        await refusing.collection('projects').doc('p').set({
          'ownerId': 'ana',
          'taskCount': 3,
          'doneCount': 0,
        });
        await refusing.collection('tasks').doc('t1').set({
          'ownerId': 'ana',
          'projectId': 'p',
          'done': false,
        });

        final toggle = await repository.settleTaskDone(task('t1'), true);

        await expectLater(
          toggle.saved,
          throwsA(
            isA<SeedlyProjectException>().having(
              (error) => error.reason,
              'reason',
              SeedlyProjectError.saveFailed,
            ),
          ),
        );
      });
    });

    test('updateProject edits the project\'s own fields', () async {
      await seed();
      await projects.updateProject(
        'p',
        SeedlyProjectChanges(
          name: 'Jardín',
          description: 'Más grande',
          icon: SeedlyProjectIcon.flor,
        ),
      );
      final data = await project();
      expect(data['name'], 'Jardín');
      expect(data['description'], 'Más grande');
      expect(data['icon'], 'flor');
      expect(data['taskCount'], 3);
      expect(data['kind'], 'full');
    });

    test('deleteProject removes the project and all its tasks', () async {
      await seed();
      await firestore.collection('tasks').doc('mine-elsewhere').set({
        'ownerId': 'ana',
        'projectId': 'other',
        'title': 'No tocar',
        'done': false,
        'order': 0,
      });
      await projects.deleteProject('p');
      expect((await firestore.collection('projects').get()).docs, isEmpty);
      expect(
        (await firestore.collection('tasks').get()).docs.map((d) => d.id),
        ['mine-elsewhere'],
      );
    });

    test('someone else\'s task is not found', () async {
      await firestore.collection('tasks').doc('theirs').set({
        'ownerId': 'luis',
        'projectId': 'p',
        'title': 'Ajena',
        'done': false,
        'order': 0,
      });
      await expectLater(
        projects.setTaskDone('theirs', true),
        throwsA(
          isA<SeedlyProjectException>().having(
            (error) => error.reason,
            'reason',
            SeedlyProjectError.notFound,
          ),
        ),
      );
    });

    test('without a session every write refuses', () async {
      final signedOut = FirestoreSeedlyProjectRepository(
        auth: FakeSeedlyAuthRepository(),
        firestore: firestore,
      );
      for (final write in <Future<void> Function()>[
        () => signedOut.setTaskDone('t', true),
        () => signedOut.deleteTask('t'),
        () => signedOut.deleteProject('p'),
        () => signedOut.addTask('p', const NewSeedlyTask('x')),
        () => signedOut.updateTask('t', const NewSeedlyTask('x')),
        () => signedOut.moveTask('t', 'p2', const NewSeedlyTask('x')),
        () => signedOut.updateProject('p', SeedlyProjectChanges(name: 'x')),
      ]) {
        await expectLater(
          write(),
          throwsA(
            isA<SeedlyProjectException>().having(
              (error) => error.reason,
              'reason',
              SeedlyProjectError.sessionExpired,
            ),
          ),
        );
      }
    });
  });
}
