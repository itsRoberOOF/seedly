import 'package:seedly/services/seedly_projects.dart';

/// In-memory [SeedlyProjects] so widget tests never reach Firestore.
class FakeSeedlyProjects implements SeedlyProjects {
  FakeSeedlyProjects({this.error, this.save = SeedlyProjectSave.saved});

  /// Thrown by [create] when set.
  SeedlyProjectsException? error;

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
