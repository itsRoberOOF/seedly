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

  CollectionReference<Map<String, dynamic>> get _drops =>
      _firestore.collection('drops');

  @override
  Future<int> addTaskDrops(String taskId) async {
    final uid = _requireUser();
    // Firestore rejects an empty document path; nothing to pay for anyway.
    if (taskId.isEmpty) return 0;
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
    if (taskId.isEmpty) return;
    final ref = _drops.doc(_dropId(SeedlyDropSource.task, taskId));
    if (await _read(ref) == null) return;
    await _commit(ref.delete());
  }

  @override
  Future<int> addProjectDrops(String projectId) async {
    final uid = _requireUser();
    if (projectId.isEmpty) return 0;
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
  Future<String> startWateringSession() async {
    final uid = _requireUser();
    final ref = _firestore.collection('sessions').doc();
    // The server stamps the start, so nobody can claim minutes they didn't
    // water. Started offline, it is stamped when it syncs.
    await _commit(
      ref.set({'ownerId': uid, 'startedAt': FieldValue.serverTimestamp()}),
    );
    return ref.id;
  }

  @override
  Future<int> payWateringSession(String sessionId, int minutes) async {
    final uid = _requireUser();
    final amount =
        minutes.clamp(0, SeedlyDrops.maxWateringMinutes) *
        SeedlyDrops.perWateringMinute;
    if (amount == 0) return 0;
    return _pay(uid, SeedlyDropSource.watering, sessionId, amount);
  }

  @override
  Stream<SeedlyPlantState> watchPlantState() {
    final uid = _requireUser();
    // A plain controller rather than async*: cancelling an async* stream
    // waits for its loop to end, and this loop never ends on its own.
    final states = StreamController<SeedlyPlantState>();
    final subscriptions = <StreamSubscription<void>>[];
    int? phase;
    int? total;

    void emit() {
      final (current, sum) = (phase, total);
      if (current == null || sum == null || states.isClosed) return;
      states.add(SeedlyPlantState(phase: current, totalDrops: sum));
    }

    states
      ..onListen = () async {
        try {
          await _ensureProgress(uid);
        } on SeedlyDropsException {
          // Offline with nothing cached; the next visit creates it.
        }
        subscriptions
          ..add(
            _progress(uid).snapshots().listen((snapshot) {
              phase = snapshot.data()?['phase'] as int? ?? 1;
              emit();
            }, onError: states.addError),
          )
          // Summed here rather than by the server: live, so a drop paid
          // anywhere — a tick, another device — shows at once, and one
          // written on this device counts before the server answers.
          ..add(
            _drops.where('ownerId', isEqualTo: uid).snapshots().listen((
              snapshot,
            ) {
              total = snapshot.docs.fold<int>(
                0,
                (drops, doc) => drops + (doc.data()['amount'] as int? ?? 0),
              );
              emit();
            }, onError: states.addError),
          );
      }
      ..onCancel = () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      };
    return states.stream.distinct();
  }

  @override
  Future<void> growPlant() async {
    final uid = _requireUser();
    await _ensureProgress(uid);
    final phase = (await _read(_progress(uid)))?['phase'] as int? ?? 1;
    final int total;
    try {
      total = await _total(uid);
    } on FirebaseException {
      throw const SeedlyDropsException(SeedlyDropsError.saveFailed);
    }
    if (!SeedlyPlantState(phase: phase, totalDrops: total).canGrow) {
      throw const SeedlyDropsException(SeedlyDropsError.notEnoughDrops);
    }
    // The rules only let the phase go up by one.
    await _commit(
      _progress(uid)
          .set({'phase': phase + 1, 'updatedAt': FieldValue.serverTimestamp()}),
    );
  }

  DocumentReference<Map<String, dynamic>> _progress(String uid) =>
      _firestore.collection('progress').doc(uid);

  /// The rules only accept phase 1 for a new progress document.
  Future<void> _ensureProgress(String uid) async {
    if (await _read(_progress(uid)) != null) return;
    await _commit(
      _progress(uid)
          .set({'phase': 1, 'updatedAt': FieldValue.serverTimestamp()}),
    );
  }

  /// Every drop the user has, summed by the server without reading them.
  Future<int> _total(String uid) async {
    final snapshot = await _drops
        .where('ownerId', isEqualTo: uid)
        .aggregate(sum('amount'))
        .get();
    return (snapshot.getSum('amount') ?? 0).round();
  }

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
  }

  String _requireUser() =>
      _auth.currentUserId ??
      (throw const SeedlyDropsException(SeedlyDropsError.sessionExpired));

  static String _dropId(SeedlyDropSource source, String refId) =>
      '${source.name}_$refId';
}
