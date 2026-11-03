import '../models/seedly_errors.dart';
import '../models/seedly_project.dart';

/// Project storage used by the screens; they never see the database.
abstract interface class SeedlyProjectRepository {
  /// Saves the project together with its initial tasks, all or nothing.
  /// Throws [SeedlyProjectException].
  Future<SeedlyProjectSave> create(NewSeedlyProject project);

  /// Watches this owner's projects, newest first.
  Stream<List<SeedlyProject>> watchProjects();

  /// Watches this owner's tasks whose due date is inside the local day.
  Stream<List<SeedlyTask>> watchTasksOn(DateTime day);

  /// Watches this owner's tasks due on or after the local day.
  Stream<List<SeedlyTask>> watchTasksFrom(DateTime day);

  /// Watches one project; emits null when it doesn't exist (or was deleted).
  Stream<SeedlyProject?> watchProject(String projectId);

  /// Watches a project's tasks in their `order`.
  Stream<List<SeedlyTask>> watchTasks(String projectId);

  /// Edits the project's own fields. Throws [SeedlyProjectException].
  Future<void> updateProject(String projectId, SeedlyProjectChanges changes);

  /// Deletes the project and all its tasks, all or nothing.
  /// Throws [SeedlyProjectException].
  Future<void> deleteProject(String projectId);

  /// Appends a task to the end of the project and keeps its counters in
  /// step. Throws [SeedlyProjectException].
  Future<void> addTask(String projectId, NewSeedlyTask task);

  /// Edits the task's title and due date, time and reminder; whether it is
  /// done is left to [setTaskDone]. Throws [SeedlyProjectException].
  Future<void> updateTask(String taskId, NewSeedlyTask task);

  /// Moves the task to another project, applying [task]'s edited fields and
  /// keeping its done state. The database can't change a task's project in
  /// place, so this recreates it under [newProjectId] and keeps both projects'
  /// counters (and the task's reward drop, if any) in step, all or nothing.
  /// When [newProjectId] is the task's current project it just edits in place.
  /// Throws [SeedlyProjectException].
  Future<void> moveTask(String taskId, String newProjectId, NewSeedlyTask task);

  /// Deletes the task and keeps its project's counters in step.
  /// Throws [SeedlyProjectException].
  Future<void> deleteTask(String taskId);

  /// Marks or unmarks the task and keeps its project's `doneCount` in step.
  /// Does nothing when it already has that state.
  /// Throws [SeedlyProjectException].
  Future<void> setTaskDone(String taskId, bool done);
}
