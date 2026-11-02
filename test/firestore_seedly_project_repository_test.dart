import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/data/firebase/firestore_seedly_project_repository.dart';
import 'package:seedly/models/seedly_errors.dart';
import 'package:seedly/models/seedly_project.dart';

import 'support/fake_seedly_auth_repository.dart';

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
}
