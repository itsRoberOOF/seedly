import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

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
  Stream<List<SeedlyTask>> watchTasksOn(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return _watchTasks(
      _tasks
          .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('dueDate', isLessThan: Timestamp.fromDate(end)),
    );
  }

  @override
  Stream<List<SeedlyTask>> watchTasksFrom(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    return _watchTasks(
      _tasks.where(
        'dueDate',
        isGreaterThanOrEqualTo: Timestamp.fromDate(start),
      ),
    );
  }

  Query<Map<String, dynamic>> get _tasks => _firestore
      .collection('tasks')
      .where('ownerId', isEqualTo: _auth.currentUserId);

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
