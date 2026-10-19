import '../models/seedly_errors.dart';
import '../models/seedly_project.dart';

/// Project storage used by the screens; they never see the database.
abstract interface class SeedlyProjectRepository {
  /// Saves the project together with its initial tasks, all or nothing.
  /// Throws [SeedlyProjectException].
  Future<SeedlyProjectSave> create(NewSeedlyProject project);
}
