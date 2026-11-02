import 'package:seedly/models/seedly_errors.dart';
import 'package:seedly/models/seedly_project.dart';
import 'package:seedly/repositories/seedly_project_repository.dart';

/// In-memory [SeedlyProjectRepository] so widget tests never reach Firestore.
class FakeSeedlyProjectRepository implements SeedlyProjectRepository {
  FakeSeedlyProjectRepository({
    this.error,
    this.save = SeedlyProjectSave.saved,
    this.tasksOn = const Stream.empty(),
    this.tasksFrom = const Stream.empty(),
  });

  /// Thrown by [create] when set.
  SeedlyProjectException? error;

  /// What [create] reports when it succeeds.
  SeedlyProjectSave save;

  /// Tasks emitted by [watchTasksOn] in screen tests.
  Stream<List<SeedlyTask>> tasksOn;

  /// Tasks emitted by [watchTasksFrom] in screen tests.
  Stream<List<SeedlyTask>> tasksFrom;

  final created = <NewSeedlyProject>[];

  @override
  Future<SeedlyProjectSave> create(NewSeedlyProject project) async {
    if (error != null) throw error!;
    created.add(project);
    return save;
  }

  @override
  Stream<List<SeedlyTask>> watchTasksOn(DateTime day) => tasksOn;

  @override
  Stream<List<SeedlyTask>> watchTasksFrom(DateTime day) => tasksFrom;
}
