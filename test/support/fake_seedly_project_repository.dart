import 'package:seedly/models/seedly_errors.dart';
import 'package:seedly/models/seedly_project.dart';
import 'package:seedly/repositories/seedly_project_repository.dart';

/// In-memory [SeedlyProjectRepository] so widget tests never reach Firestore.
class FakeSeedlyProjectRepository implements SeedlyProjectRepository {
  FakeSeedlyProjectRepository({
    this.error,
    this.save = SeedlyProjectSave.saved,
  });

  /// Thrown by [create] when set.
  SeedlyProjectException? error;

  /// What [create] reports when it succeeds.
  SeedlyProjectSave save;

  final created = <NewSeedlyProject>[];

  @override
  Future<SeedlyProjectSave> create(NewSeedlyProject project) async {
    if (error != null) throw error!;
    created.add(project);
    return save;
  }
}
