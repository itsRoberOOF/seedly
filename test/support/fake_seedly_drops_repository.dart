import 'dart:async';

import 'package:seedly/models/seedly_drops.dart';
import 'package:seedly/models/seedly_errors.dart';
import 'package:seedly/models/seedly_project.dart';
import 'package:seedly/repositories/seedly_drops_repository.dart';

/// In-memory [SeedlyDropsRepository] so screen tests never reach Firestore.
/// It trusts the caller about tasks and projects being done, and its daily
/// cap counts every task ever paid.
class FakeSeedlyDropsRepository implements SeedlyDropsRepository {
  FakeSeedlyDropsRepository({this.phase = 1, this.startingDrops = 0});

  int phase;

  /// Drops the user already had, on top of [paid].
  int startingDrops;

  /// Thrown by every method when set.
  SeedlyDropsException? error;

  /// Drops paid, by the `source_refId` key Firestore uses.
  final paid = <String, int>{};

  final sessions = <String>[];
  final _changes = StreamController<void>.broadcast();

  SeedlyPlantState get state => SeedlyPlantState(
    phase: phase,
    totalDrops: paid.values.fold(startingDrops, (sum, amount) => sum + amount),
  );

  @override
  Future<int> addTaskDrops(String taskId) async {
    final tasksPaid = paid.keys.where((key) => key.startsWith('task_'));
    if (tasksPaid.length >= SeedlyDrops.maxRewardedTasksPerDay) return 0;
    return _pay('task_$taskId', SeedlyDrops.perTask);
  }

  @override
  Future<void> removeTaskDrops(String taskId) async {
    _check();
    if (paid.remove('task_$taskId') != null) _changes.add(null);
  }

  @override
  Future<int> addProjectDrops(String projectId) =>
      _pay('project_$projectId', SeedlyDrops.perProject);

  /// Settles a tick as FirestoreSeedlyProjectRepository.settleTaskDone does,
  /// for FakeSeedlyProjectRepository: pays or takes back the task's drops,
  /// and pays its project too when [finishesProject].
  SeedlyDropsChange settle(
    SeedlyTask task,
    bool done, {
    required bool finishesProject,
  }) {
    _check();
    final finished = finishesProject ? SeedlyDrops.minProjectTasks : 0;
    final change = SeedlyDropsChange.ofTaskToggle(
      done: done,
      taskPaid: paid.containsKey('task_${task.id}'),
      tasksPaidToday: paid.keys.where((key) => key.startsWith('task_')).length,
      projectPaid: paid.containsKey('project_${task.projectId}'),
      projectTasks: finished,
      projectDoneAfter: finished,
    );
    if (change.task > 0) paid['task_${task.id}'] = change.task;
    if (change.task < 0) paid.remove('task_${task.id}');
    if (change.project > 0) paid['project_${task.projectId}'] = change.project;
    _changes.add(null);
    return change;
  }

  @override
  Future<String> startWateringSession() async {
    _check();
    sessions.add('session${sessions.length + 1}');
    return sessions.last;
  }

  @override
  Future<int> payWateringSession(String sessionId, int minutes) async {
    final amount = minutes.clamp(0, SeedlyDrops.maxWateringMinutes);
    if (amount == 0) return 0;
    return _pay('watering_$sessionId', amount);
  }

  @override
  Stream<SeedlyPlantState> watchPlantState() async* {
    _check();
    yield state;
    await for (final _ in _changes.stream) {
      yield state;
    }
  }

  @override
  Future<void> growPlant() async {
    _check();
    if (!state.canGrow) {
      throw const SeedlyDropsException(SeedlyDropsError.notEnoughDrops);
    }
    phase++;
    _changes.add(null);
  }

  Future<int> _pay(String key, int amount) async {
    _check();
    if (paid.containsKey(key)) return 0;
    paid[key] = amount;
    _changes.add(null);
    return amount;
  }

  void _check() {
    if (error != null) throw error!;
  }
}
