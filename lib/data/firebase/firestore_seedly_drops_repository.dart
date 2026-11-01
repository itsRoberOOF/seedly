import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/seedly_drops.dart';
import '../../models/seedly_errors.dart';
import '../../repositories/seedly_auth_repository.dart';
import '../../repositories/seedly_drops_repository.dart';

/// Keeps one document per payment in the root `drops` collection, named
/// `source_refId` so nothing pays twice; the total is a sum over them. The
/// plant's phase lives in `progress/{uid}` and watering sessions in
/// `sessions`. There are no Cloud Functions, so firestore.rules checks every
/// amount; the daily task cap and the growth check live only here because
/// rules can't count or add.
class FirestoreSeedlyDropsRepository implements SeedlyDropsRepository {
  FirestoreSeedlyDropsRepository({
    required this._auth,
    FirebaseFirestore? firestore,
    DateTime Function()? clock,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _clock = clock ?? DateTime.now;

  final SeedlyAuthRepository _auth;
  final FirebaseFirestore _firestore;
  final DateTime Function() _clock;

  /// How long to wait for the server before trusting the offline queue.
  static const _serverWait = Duration(seconds: 8);

  /// Pinged after every write, so [watchPlantState] sums again.
  final _changed = StreamController<void>.broadcast();

  CollectionReference<Map<String, dynamic>> get _drops =>
      _firestore.collection('drops');

  @override
  Future<int> addTaskDrops(String taskId) async {
    final uid = _requireUser();
    final task = await _read(_firestore.collection('tasks').doc(taskId));
    if (task?['ownerId'] != uid || task?['done'] != true) return 0;
    if (await _tasksPaidToday(uid) >= SeedlyDrops.maxRewardedTasksPerDay) {
      return 0;
    }
    return _pay(uid, SeedlyDropSource.task, taskId, SeedlyDrops.perTask);
  }

  @override
  Future<void> removeTaskDrops(String taskId) async {
    _requireUser();
    final ref = _drops.doc(_dropId(SeedlyDropSource.task, taskId));
    if (await _read(ref) == null) return;
    await _commit(ref.delete());
  }

  @override
  Future<int> addProjectDrops(String projectId) async {
    final uid = _requireUser();
    final project = await _read(
      _firestore.collection('projects').doc(projectId),
    );
    if (project == null || project['ownerId'] != uid) return 0;
    final taskCount = project['taskCount'] as int;
    if (taskCount < SeedlyDrops.minProjectTasks ||
        project['doneCount'] != taskCount) {
      return 0;
    }
    return _pay(
      uid,
      SeedlyDropSource.project,
      projectId,
      SeedlyDrops.perProject,
    );
  }

  @override
  Future<String> startWateringSession() => throw UnimplementedError();

  @override
  Future<int> payWateringSession(String sessionId, int minutes) =>
      throw UnimplementedError();

  @override
  Stream<SeedlyPlantState> watchPlantState() => throw UnimplementedError();

  @override
  Future<void> growPlant() => throw UnimplementedError();

  /// Writes the payment unless it already exists. The rules reject a second
  /// write anyway (it would be an update); checking first keeps that from
  /// surfacing as an error.
  Future<int> _pay(
    String uid,
    SeedlyDropSource source,
    String refId,
    int amount,
  ) async {
    final ref = _drops.doc(_dropId(source, refId));
    if (await _read(ref) != null) return 0;
    await _commit(
      ref.set({
        'ownerId': uid,
        'source': source.name,
        'refId': refId,
        'amount': amount,
        'createdAt': FieldValue.serverTimestamp(),
      }),
    );
    return amount;
  }

  /// Tasks paid since local midnight. Counting needs the server, so offline
  /// the cap is skipped; the rules still pay each task at most once.
  Future<int> _tasksPaidToday(String uid) async {
    final now = _clock();
    final midnight = DateTime(now.year, now.month, now.day);
    try {
      final snapshot = await _drops
          .where('ownerId', isEqualTo: uid)
          .where('source', isEqualTo: SeedlyDropSource.task.name)
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(midnight),
          )
          .count()
          .get();
      return snapshot.count ?? 0;
    } on FirebaseException {
      return 0;
    }
  }

  /// The document's data, or null when it doesn't exist.
  Future<Map<String, dynamic>?> _read(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    try {
      return (await ref.get()).data();
    } on FirebaseException {
      throw const SeedlyDropsException(SeedlyDropsError.saveFailed);
    }
  }

  /// Offline, the write is already in the local cache and syncs later, but
  /// it only completes once the server answers.
  Future<void> _commit(Future<void> write) async {
    try {
      await write.timeout(_serverWait);
    } on TimeoutException {
      // Queued; it syncs when the connection returns.
    } on FirebaseException {
      throw const SeedlyDropsException(SeedlyDropsError.saveFailed);
    }
    _changed.add(null);
  }

  String _requireUser() =>
      _auth.currentUserId ??
      (throw const SeedlyDropsException(SeedlyDropsError.sessionExpired));

  static String _dropId(SeedlyDropSource source, String refId) =>
      '${source.name}_$refId';
}
