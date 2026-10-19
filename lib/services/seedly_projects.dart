import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/seedly_errors.dart';
import '../models/seedly_project.dart';

/// Project storage used by the screens, so tests can swap Firestore out.
abstract interface class SeedlyProjects {
  /// Throws [SeedlyProjectException].
  Future<SeedlyProjectSave> create(NewSeedlyProject project);
}

/// Stores projects in the root `projects` collection and their tasks in the
/// root `tasks` collection, so tasks from every project can be queried
/// together (today's tasks, the calendar). Both carry `ownerId`, which every
/// query must filter on; tasks also carry `projectId`. A project and its
/// tasks are written together in one batch.
class FirebaseSeedlyProjects implements SeedlyProjects {
  FirebaseSeedlyProjects({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// How long to wait for the server before trusting the offline queue.
  static const _serverWait = Duration(seconds: 8);

  @override
  Future<SeedlyProjectSave> create(NewSeedlyProject project) async {
    final uid = _auth.currentUser?.uid;
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

  static Timestamp? _timestamp(DateTime? date) =>
      date == null ? null : Timestamp.fromDate(date);
}
