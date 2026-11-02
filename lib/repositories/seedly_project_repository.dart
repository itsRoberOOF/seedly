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
}
