import '../models/seedly_errors.dart';
import '../models/seedly_project.dart';
import '../repositories/seedly_drops_repository.dart';
import '../repositories/seedly_project_repository.dart';

/// Drops paid by marking a task done: [task] for the task itself and
/// [project] for finishing its project. Both are zero when nothing was paid —
/// the daily cap was reached, the project isn't complete, or the task was
/// unmarked.
typedef SeedlyDropsEarned = ({int task, int project});

/// A success toast for [earned], or null when nothing was paid, so callers
/// stay silent at the daily cap and when unmarking.
({String title, String message})? seedlyDropsEarnedToast(
  SeedlyDropsEarned earned,
) {
  final total = earned.task + earned.project;
  if (total <= 0) return null;
  if (earned.project > 0) {
    final breakdown = earned.task > 0
        ? ' (+${earned.task} de la tarea y +${earned.project} del proyecto)'
        : '';
    return (
      title: '¡Proyecto completado!',
      message: 'Conseguiste $total ${_gotas(total)}$breakdown.',
    );
  }
  return (
    title: '¡Buen trabajo!',
    message: 'Conseguiste ${earned.task} ${_gotas(earned.task)} por tu tarea.',
  );
}

String _gotas(int n) => n == 1 ? 'gota' : 'gotas';

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
  /// Returns the drops actually paid, so callers can celebrate them; unmarking
  /// and a drops failure both report none.
  /// Throws [SeedlyProjectException] if the task itself can't be saved.
  Future<SeedlyDropsEarned> setDone(SeedlyTask task, bool done) async {
    await projects.setTaskDone(task.id, done);
    final drops = this.drops;
    if (drops == null) return (task: 0, project: 0);
    try {
      if (done) {
        final taskDrops = await drops.addTaskDrops(task.id);
        // Pays only if every task is done and there are enough of them.
        final projectDrops = await drops.addProjectDrops(task.projectId);
        return (task: taskDrops, project: projectDrops);
      } else {
        await drops.removeTaskDrops(task.id);
      }
    } on SeedlyDropsException {
      // The task is saved; the drops can be settled by toggling it again.
    }
    return (task: 0, project: 0);
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
