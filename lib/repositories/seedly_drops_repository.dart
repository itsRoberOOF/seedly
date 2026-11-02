import '../models/seedly_drops.dart';
import '../models/seedly_errors.dart';

/// Drops paid for tasks, projects and watering, and the plant they grow.
/// Every method throws [SeedlyDropsException].
abstract interface class SeedlyDropsRepository {
  /// Pays a task the caller has just marked done. Returns the drops paid:
  /// 0 when the task isn't done, was already paid, or today's cap of
  /// [SeedlyDrops.maxRewardedTasksPerDay] tasks is reached.
  Future<int> addTaskDrops(String taskId);

  /// Takes back a task's drops after it is unmarked or deleted; does
  /// nothing when it was never paid.
  Future<void> removeTaskDrops(String taskId);

  /// Pays a project once, when it has at least
  /// [SeedlyDrops.minProjectTasks] tasks and all are done. Returns the
  /// drops paid, 0 otherwise.
  Future<int> addProjectDrops(String projectId);

  /// Starts a watering session stamped with the server's clock and returns
  /// its id.
  Future<String> startWateringSession();

  /// Pays the whole [minutes] watered, at most
  /// [SeedlyDrops.maxWateringMinutes]; once per session. Returns the drops
  /// paid.
  Future<int> payWateringSession(String sessionId, int minutes);

  /// The plant's phase and drop total, starting with the current values.
  Stream<SeedlyPlantState> watchPlantState();

  /// Moves the plant to its next phase. Throws
  /// [SeedlyDropsError.notEnoughDrops] unless [SeedlyPlantState.canGrow].
  Future<void> growPlant();
}
