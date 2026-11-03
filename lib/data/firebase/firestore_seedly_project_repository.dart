import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/seedly_drops.dart';
import '../../models/seedly_errors.dart';
import '../../models/seedly_project.dart';
import '../../repositories/seedly_auth_repository.dart';
import '../../repositories/seedly_project_repository.dart';

/// Stores projects in the root `projects` collection and their tasks in the
/// root `tasks` collection, so tasks from every project can be queried
/// together (today's tasks, the calendar). Both carry `ownerId`, which every
/// query must filter on; tasks also carry `projectId`. A project and its
/// tasks are written together in one batch.
class FirestoreSeedlyProjectRepository implements SeedlyProjectRepository {
  FirestoreSeedlyProjectRepository({
    required this._auth,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final SeedlyAuthRepository _auth;
  final FirebaseFirestore _firestore;

  /// How long to wait for the server before trusting the offline queue.
  static const _serverWait = Duration(seconds: 8);

  @override
  Future<SeedlyProjectSave> create(NewSeedlyProject project) async {
    final uid = _auth.currentUserId;
    if (uid == null) {
      throw const SeedlyProjectException(SeedlyProjectError.sessionExpired);
    }
    final projectRef = _firestore.collection('projects').doc();
    final batch = _firestore.batch()
      ..set(projectRef, {
        'ownerId': uid,
        'name': project.name,
        'description': project.description,
        'icon': project.icon.name,
        // Avatar-sized, so it fits in the document; Storage needs Blaze.
        'photo': project.photo == null ? null : Blob(project.photo!),
        'kind': project.kind.name,
        'startDate': _timestamp(project.startDate),
        'endDate': _timestamp(project.endDate),
        // Progress for the project list without reading every task; kept
        // in step whenever tasks are written.
        'taskCount': project.tasks.length,
        'doneCount': project.tasks.where((task) => task.done).length,
        'createdAt': FieldValue.serverTimestamp(),
      });
    for (final (order, task) in project.tasks.indexed) {
      batch.set(_firestore.collection('tasks').doc(), {
        'ownerId': uid,
        'projectId': projectRef.id,
        'title': task.title,
        'done': task.done,
        'order': order,
        'dueDate': _timestamp(task.dueDate),
        'dueMinutes': task.dueMinutes,
        'reminderMinutes': task.reminderMinutes,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    // Offline, the batch is already in the local cache and syncs later, but
    // commit() only completes once the server answers.
    try {
      await batch.commit().timeout(_serverWait);
      return SeedlyProjectSave.saved;
    } on TimeoutException {
      return SeedlyProjectSave.pendingSync;
    } on FirebaseException {
      throw const SeedlyProjectException(SeedlyProjectError.saveFailed);
    }
  }

  @override
  Stream<List<SeedlyProject>> watchProjects() {
    final ownerId = _auth.currentUserId;
    if (ownerId == null) return const Stream.empty();
    return _firestore
        .collection('projects')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snapshot) {
          // No orderBy: it would need a composite index with ownerId. A
          // project still waiting for its server time is the newest.
          final entries = [
            for (final doc in snapshot.docs)
              (
                project: _projectOf(doc),
                createdAt: (doc.data()['createdAt'] as Timestamp?)?.toDate(),
              ),
          ];
          entries.sort((a, b) {
            final (x, y) = (a.createdAt, b.createdAt);
            if (x == null || y == null) {
              return x == y ? 0 : (x == null ? -1 : 1);
            }
            return y.compareTo(x);
          });
          return [for (final entry in entries) entry.project];
        })
        .handleError(_asLoadFailure);
  }

  @override
  Stream<List<SeedlyTask>> watchTasksOn(DateTime day) {
    final ownerId = _auth.currentUserId;
    if (ownerId == null) return const Stream.empty();
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return _watchTasks(
      _tasks(ownerId)
          .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('dueDate', isLessThan: Timestamp.fromDate(end)),
    );
  }

  @override
  Stream<List<SeedlyTask>> watchTasksFrom(DateTime day) {
    final ownerId = _auth.currentUserId;
    if (ownerId == null) return const Stream.empty();
    final start = DateTime(day.year, day.month, day.day);
    return _watchTasks(
      _tasks(ownerId)
          .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start)),
    );
  }

  @override
  Stream<SeedlyProject?> watchProject(String projectId) {
    final ownerId = _auth.currentUserId;
    if (ownerId == null) return const Stream.empty();
    return _firestore
        .collection('projects')
        .where('ownerId', isEqualTo: ownerId)
        .where(FieldPath.documentId, isEqualTo: projectId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.isEmpty ? null : _projectOf(snapshot.docs.single),
        )
        .handleError(_asLoadFailure);
  }

  @override
  Stream<List<SeedlyTask>> watchTasks(String projectId) {
    final ownerId = _auth.currentUserId;
    if (ownerId == null) return const Stream.empty();
    return _watchTasks(_tasks(ownerId).where('projectId', isEqualTo: projectId))
        .handleError(_asLoadFailure);
  }

  @override
  Future<void> updateProject(
    String projectId,
    SeedlyProjectChanges changes,
  ) async {
    final uid = _requireUser();
    final ref = _firestore.collection('projects').doc(projectId);
    await _readOwned(ref, uid);
    final batch = _firestore.batch()
      ..update(ref, {
        'name': changes.name,
        'description': changes.description,
        'icon': changes.icon.name,
        'photo': changes.photo == null ? null : Blob(changes.photo!),
        'startDate': _timestamp(changes.startDate),
        'endDate': _timestamp(changes.endDate),
      });
    await _commit(batch);
  }

  @override
  Future<void> deleteProject(String projectId) async {
    final uid = _requireUser();
    final ref = _firestore.collection('projects').doc(projectId);
    await _readOwned(ref, uid);
    final tasks = await _guard(
      () => _tasks(uid).where('projectId', isEqualTo: projectId).get(),
    );
    final batch = _firestore.batch();
    for (final task in tasks.docs) {
      batch.delete(task.reference);
    }
    batch.delete(ref);
    await _commit(batch);
  }

  @override
  Future<void> addTask(String projectId, NewSeedlyTask task) async {
    final uid = _requireUser();
    final projectRef = _firestore.collection('projects').doc(projectId);
    await _readOwned(projectRef, uid);
    final siblings = await _guard(
      () => _tasks(uid).where('projectId', isEqualTo: projectId).get(),
    );
    final order = siblings.docs.fold<int>(-1, (highest, doc) {
      final value = doc.data()['order'] as int;
      return value > highest ? value : highest;
    });
    final batch = _firestore.batch()
      ..set(_firestore.collection('tasks').doc(), {
        'ownerId': uid,
        'projectId': projectId,
        'title': task.title,
        'done': task.done,
        'order': order + 1,
        'dueDate': _timestamp(task.dueDate),
        'dueMinutes': task.dueMinutes,
        'reminderMinutes': task.reminderMinutes,
        'createdAt': FieldValue.serverTimestamp(),
      })
      ..update(projectRef, {
        'taskCount': FieldValue.increment(1),
        if (task.done) 'doneCount': FieldValue.increment(1),
      });
    await _commit(batch);
  }

  @override
  Future<void> updateTask(String taskId, NewSeedlyTask task) async {
    final uid = _requireUser();
    final ref = _firestore.collection('tasks').doc(taskId);
    await _readOwned(ref, uid);
    final batch = _firestore.batch()
      ..update(ref, {
        'title': task.title,
        'dueDate': _timestamp(task.dueDate),
        'dueMinutes': task.dueMinutes,
        'reminderMinutes': task.reminderMinutes,
      });
    await _commit(batch);
  }

  @override
  Future<void> moveTask(
    String taskId,
    String newProjectId,
    NewSeedlyTask task,
  ) async {
    final uid = _requireUser();
    final oldRef = _firestore.collection('tasks').doc(taskId);
    final old = await _readOwned(oldRef, uid);
    final oldProjectId = old['projectId'] as String;
    // Same project: nothing to move, just apply the edited fields.
    if (oldProjectId == newProjectId) {
      await updateTask(taskId, task);
      return;
    }
    final newProjectRef = _firestore.collection('projects').doc(newProjectId);
    await _readOwned(newProjectRef, uid);
    final oldProjectRef = _firestore.collection('projects').doc(oldProjectId);

    // Append to the end of the destination, like addTask.
    final siblings = await _guard(
      () => _tasks(uid).where('projectId', isEqualTo: newProjectId).get(),
    );
    final order =
        siblings.docs.fold<int>(-1, (highest, doc) {
          final value = doc.data()['order'] as int;
          return value > highest ? value : highest;
        }) +
        1;

    // The database won't let a task change project in place, so recreate it.
    final done = old['done'] == true;
    final newRef = _firestore.collection('tasks').doc();

    // Carry the reward drop over only if it was actually paid, so the total
    // stays the same. Its id is `task_<taskId>`.
    final oldDropRef = _firestore.collection('drops').doc('task_$taskId');
    final hasDrop = done && (await _guard(oldDropRef.get)).exists;

    final batch = _firestore.batch()
      ..set(newRef, {
        'ownerId': uid,
        'projectId': newProjectId,
        'title': task.title,
        'done': done,
        'order': order,
        'dueDate': _timestamp(task.dueDate),
        'dueMinutes': task.dueMinutes,
        'reminderMinutes': task.reminderMinutes,
        'createdAt': FieldValue.serverTimestamp(),
      })
      ..delete(oldRef)
      ..update(oldProjectRef, {
        'taskCount': FieldValue.increment(-1),
        if (done) 'doneCount': FieldValue.increment(-1),
      })
      ..update(newProjectRef, {
        'taskCount': FieldValue.increment(1),
        if (done) 'doneCount': FieldValue.increment(1),
      });
    if (hasDrop) {
      // The rules read the new task (done, in this same batch) and the old
      // one's absence through getAfter, so both drop writes are allowed.
      batch
        ..delete(oldDropRef)
        ..set(_firestore.collection('drops').doc('task_${newRef.id}'), {
          'ownerId': uid,
          'source': SeedlyDropSource.task.name,
          'refId': newRef.id,
          'amount': SeedlyDrops.perTask,
          'createdAt': FieldValue.serverTimestamp(),
        });
    }
    await _commit(batch);
  }

  @override
  Future<void> deleteTask(String taskId) async {
    final uid = _requireUser();
    final ref = _firestore.collection('tasks').doc(taskId);
    await _inTurn(taskId, () async {
      final data = await _readOwned(ref, uid);
      return _firestore.batch()
        ..delete(ref)
        ..update(
          _firestore.collection('projects').doc(data['projectId'] as String),
          {
            'taskCount': FieldValue.increment(-1),
            if (data['done'] == true) 'doneCount': FieldValue.increment(-1),
          },
        );
    });
  }

  @override
  Future<void> setTaskDone(String taskId, bool done) async {
    final uid = _requireUser();
    final ref = _firestore.collection('tasks').doc(taskId);
    await _inTurn(taskId, () async {
      final data = await _readOwned(ref, uid);
      if (data['done'] == done) return null;
      return _firestore.batch()
        ..update(ref, {'done': done})
        ..update(
          _firestore.collection('projects').doc(data['projectId'] as String),
          {'doneCount': FieldValue.increment(done ? 1 : -1)},
        );
    });
  }

  String _requireUser() {
    final uid = _auth.currentUserId;
    if (uid == null) {
      throw const SeedlyProjectException(SeedlyProjectError.sessionExpired);
    }
    return uid;
  }

  /// Reads a document of this owner; a missing one, or someone else's, is
  /// [SeedlyProjectError.notFound]. Offline it answers from the local cache.
  Future<Map<String, dynamic>> _readOwned(
    DocumentReference<Map<String, dynamic>> ref,
    String uid,
  ) async {
    final snapshot = await _guard(ref.get);
    final data = snapshot.data();
    if (data == null || data['ownerId'] != uid) {
      throw const SeedlyProjectException(SeedlyProjectError.notFound);
    }
    return data;
  }

  Future<T> _guard<T>(Future<T> Function() read) async {
    try {
      return await read();
    } on FirebaseException {
      throw const SeedlyProjectException(SeedlyProjectError.saveFailed);
    }
  }

  /// For each task, the end of the last operation on it that read it and
  /// handed its write to Firestore. See [_inTurn].
  final _turns = <String, Future<void>>{};

  /// Runs [prepare] once every earlier operation on [taskId] has handed its
  /// write to Firestore, so that it reads what they wrote. [prepare] reads
  /// the task and returns the batch to send, or null when there is nothing
  /// to write.
  ///
  /// [setTaskDone] and [deleteTask] read the task and then raise or lower its
  /// project's counters by what they saw. Two at once, such as a double tap,
  /// both saw the same state and counted twice. The wait lasts only until the
  /// write is handed over, not until the server answers, which offline can
  /// take [_serverWait]: Firestore's local view already shows a handed-over
  /// write to the next read.
  Future<void> _inTurn(
    String taskId,
    Future<WriteBatch?> Function() prepare,
  ) async {
    final previous = _turns[taskId];
    final released = Completer<void>();
    final mine = _turns[taskId] = released.future;
    Future<void>? sending;
    try {
      await previous;
      final batch = await prepare();
      // commit() is called now, so the next turn already sees the write.
      if (batch != null) sending = _commit(batch);
    } finally {
      released.complete();
      if (identical(_turns[taskId], mine)) _turns.remove(taskId);
    }
    await sending;
  }

  /// Offline the batch is already in the local cache and syncs later, but
  /// commit() only completes once the server answers; waiting longer
  /// than [_serverWait] counts as saved.
  Future<void> _commit(WriteBatch batch) async {
    try {
      await batch.commit().timeout(_serverWait);
    } on TimeoutException {
      // Queued locally; Firestore syncs it when the connection returns.
    } on FirebaseException {
      throw const SeedlyProjectException(SeedlyProjectError.saveFailed);
    }
  }

  static Never _asLoadFailure(Object error) =>
      throw const SeedlyProjectException(SeedlyProjectError.loadFailed);

  static SeedlyProject _projectOf(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return SeedlyProject(
      id: document.id,
      name: data['name'] as String,
      kind: SeedlyProjectKind.values.byName(data['kind'] as String),
      description: data['description'] as String?,
      icon:
          SeedlyProjectIcon.values.asNameMap()[data['icon']] ??
          SeedlyProjectIcon.planta,
      photo: (data['photo'] as Blob?)?.bytes,
      startDate: (data['startDate'] as Timestamp?)?.toDate().toLocal(),
      endDate: (data['endDate'] as Timestamp?)?.toDate().toLocal(),
      taskCount: data['taskCount'] as int,
      doneCount: data['doneCount'] as int,
    );
  }

  Query<Map<String, dynamic>> _tasks(String ownerId) =>
      _firestore.collection('tasks').where('ownerId', isEqualTo: ownerId);

  Stream<List<SeedlyTask>> _watchTasks(Query<Map<String, dynamic>> query) =>
      query.snapshots().map((snapshot) {
        final tasks = [for (final doc in snapshot.docs) _taskOf(doc)];
        tasks.sort(_compareTasks);
        return tasks;
      });

  static SeedlyTask _taskOf(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final dueDate = (data['dueDate'] as Timestamp?)?.toDate().toLocal();
    return SeedlyTask(
      id: document.id,
      projectId: data['projectId'] as String,
      title: data['title'] as String,
      done: data['done'] as bool,
      order: data['order'] as int,
      dueDate: dueDate,
      dueMinutes: data['dueMinutes'] as int?,
      reminderMinutes: data['reminderMinutes'] as int?,
    );
  }

  static int _compareTasks(SeedlyTask a, SeedlyTask b) {
    final date = (a.dueDate ?? DateTime(0)).compareTo(b.dueDate ?? DateTime(0));
    if (date != 0) return date;
    final time = (a.dueMinutes ?? -1).compareTo(b.dueMinutes ?? -1);
    if (time != 0) return time;
    final order = a.order.compareTo(b.order);
    return order != 0 ? order : a.id.compareTo(b.id);
  }

  static Timestamp? _timestamp(DateTime? date) =>
      date == null ? null : Timestamp.fromDate(date);
}
