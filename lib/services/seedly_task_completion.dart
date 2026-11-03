import '../models/seedly_errors.dart';
import '../models/seedly_project.dart';
import '../repositories/seedly_drops_repository.dart';
import '../repositories/seedly_project_repository.dart';

/// Marks and deletes tasks and settles their drops, so Inicio and the
/// project detail behave the same. The task is saved first; drops are a
/// reward on top, so a failure paying them never undoes the task.
class SeedlyTaskCompletion {
  const SeedlyTaskCompletion({required this.projects, this.drops});

  final SeedlyProjectRepository projects;

  /// Omitted in screens that don't deal with the plant.
  final SeedlyDropsRepository? drops;

  /// Marks or unmarks [task]. Marking pays its drops and, when that
  /// completes the project, the project's too; unmarking takes them back.
  /// Throws [SeedlyProjectException] if the task itself can't be saved.
  Future<void> setDone(SeedlyTask task, bool done) async {
    await projects.setTaskDone(task.id, done);
    final drops = this.drops;
    if (drops == null) return;
    try {
      if (done) {
        await drops.addTaskDrops(task.id);
        // Pays only if every task is done and there are enough of them.
        await drops.addProjectDrops(task.projectId);
      } else {
        await drops.removeTaskDrops(task.id);
      }
    } on SeedlyDropsException {
      // The task is saved; the drops can be settled by toggling it again.
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
