import '../models/seedly_drops.dart';
import '../models/seedly_errors.dart';
import '../models/seedly_project.dart';
import '../repositories/seedly_drops_repository.dart';
import '../repositories/seedly_project_repository.dart';

/// Marks and deletes tasks and settles their drops, so Inicio and the
/// project detail behave the same. Ticking saves the task and its drops in
/// one write; moving and deleting save the task first, with the drops as a
/// reward on top, so a failure paying them never undoes the task.
class SeedlyTaskCompletion {
  const SeedlyTaskCompletion({required this.projects, this.drops});

  final SeedlyProjectRepository projects;

  /// Omitted in screens that don't deal with the plant.
  final SeedlyDropsRepository? drops;

  /// Marks or unmarks [task] and settles its drops with it; see
  /// [SeedlyProjectRepository.settleTaskDone]. Returns as soon as this device
  /// shows it, with the drops moved; a refused save comes through
  /// [SeedlyTaskToggle.saved]. Without the plant there is nothing to settle,
  /// so it returns once the task is saved.
  /// Throws [SeedlyProjectException] if the task can't be read or saved.
  Future<SeedlyTaskToggle> setDone(SeedlyTask task, bool done) async {
    if (drops == null) {
      await projects.setTaskDone(task.id, done);
      return SeedlyTaskToggle.unchanged();
    }
    return projects.settleTaskDone(task, done);
  }

  /// Moves [task] to [newProjectId], applying [changes] and keeping its done
  /// state. Its own reward drop travels with it (inside the repository's
  /// batch); here, if the move completes the destination project, that
  /// project's reward is paid too, as marking its last task done would.
  /// Throws [SeedlyProjectException] if the task itself can't be moved.
  Future<void> move(
    SeedlyTask task,
    String newProjectId,
    NewSeedlyTask changes,
  ) async {
    await projects.moveTask(task.id, newProjectId, changes);
    final drops = this.drops;
    if (drops == null) return;
    try {
      // Pays only if the destination now has 3+ tasks, all done, and once.
      await drops.addProjectDrops(newProjectId);
    } on SeedlyDropsException {
      // The task moved; its project reward can be settled by toggling a task.
    }
  }

  /// Deletes [task], taking back the drops it had earned.
  /// Throws [SeedlyProjectException] if the task can't be deleted.
  Future<void> delete(SeedlyTask task) async {
    await projects.deleteTask(task.id);
    final drops = this.drops;
    if (drops == null || !task.done) return;
    try {
      await drops.removeTaskDrops(task.id);
    } on SeedlyDropsException {
      // The task is gone; nothing else can be done about its drops here.
    }
  }
}
