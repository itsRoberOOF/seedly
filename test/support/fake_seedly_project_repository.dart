import 'dart:async';

import 'package:seedly/models/seedly_errors.dart';
import 'package:seedly/models/seedly_project.dart';
import 'package:seedly/repositories/seedly_project_repository.dart';

/// In-memory [SeedlyProjectRepository] so widget tests never reach Firestore.
class FakeSeedlyProjectRepository implements SeedlyProjectRepository {
  FakeSeedlyProjectRepository({
    this.error,
    this.save = SeedlyProjectSave.saved,
    this.projects = const Stream.empty(),
    this.tasksOn = const Stream.empty(),
    this.tasksFrom = const Stream.empty(),
    this.projectById = const Stream.empty(),
    this.tasksOfProject = const Stream.empty(),
  });

  /// Thrown by [create] when set.
  SeedlyProjectException? error;

  /// What [create] reports when it succeeds.
  SeedlyProjectSave save;

  /// Projects emitted by [watchProjects] in screen tests.
  Stream<List<SeedlyProject>> projects;

  /// Tasks emitted by [watchTasksOn] in screen tests.
  Stream<List<SeedlyTask>> tasksOn;

  /// Tasks emitted by [watchTasksFrom] in screen tests.
  Stream<List<SeedlyTask>> tasksFrom;

  /// Emitted by [watchProject] and [watchTasks] in screen tests.
  Stream<SeedlyProject?> projectById;
  Stream<List<SeedlyTask>> tasksOfProject;

  final created = <NewSeedlyProject>[];

  /// Every call of the write methods below, in order, for tests to assert.
  final updatedProjects = <(String, SeedlyProjectChanges)>[];
  final deletedProjects = <String>[];
  final addedTasks = <(String, NewSeedlyTask)>[];
  final updatedTasks = <(String, NewSeedlyTask)>[];
  final deletedTasks = <String>[];
  final doneChanges = <(String, bool)>[];

  @override
  Future<SeedlyProjectSave> create(NewSeedlyProject project) async {
    if (error != null) throw error!;
    created.add(project);
    return save;
  }

  final _projectsWatch = _Watch<List<SeedlyProject>>();
  final _tasksOnWatch = _Watch<List<SeedlyTask>>();
  final _tasksFromWatch = _Watch<List<SeedlyTask>>();
  final _projectWatch = _Watch<SeedlyProject?>();
  final _tasksOfProjectWatch = _Watch<List<SeedlyTask>>();

  @override
  Stream<List<SeedlyProject>> watchProjects() => _projectsWatch.of(projects);

  @override
  Stream<List<SeedlyTask>> watchTasksOn(DateTime day) =>
      _tasksOnWatch.of(tasksOn);

  @override
  Stream<List<SeedlyTask>> watchTasksFrom(DateTime day) =>
      _tasksFromWatch.of(tasksFrom);

  @override
  Stream<SeedlyProject?> watchProject(String projectId) =>
      _projectWatch.of(projectById);

  @override
  Stream<List<SeedlyTask>> watchTasks(String projectId) =>
      _tasksOfProjectWatch.of(tasksOfProject);

  @override
  Future<void> updateProject(
    String projectId,
    SeedlyProjectChanges changes,
  ) async {
    if (error != null) throw error!;
    updatedProjects.add((projectId, changes));
  }

  @override
  Future<void> deleteProject(String projectId) async {
    if (error != null) throw error!;
    deletedProjects.add(projectId);
  }

  @override
  Future<void> addTask(String projectId, NewSeedlyTask task) async {
    if (error != null) throw error!;
    addedTasks.add((projectId, task));
  }

  @override
  Future<void> updateTask(String taskId, NewSeedlyTask task) async {
    if (error != null) throw error!;
    updatedTasks.add((taskId, task));
  }

  @override
  Future<void> deleteTask(String taskId) async {
    if (error != null) throw error!;
    deletedTasks.add(taskId);
  }

  @override
  Future<void> setTaskDone(String taskId, bool done) async {
    if (error != null) throw error!;
    doneChanges.add((taskId, done));
  }
}

/// Firestore gives every listener the current value, so each call replays
/// the source to its own listener instead of handing out one
/// single-subscription stream that a second screen could not listen to.
class _Watch<T> {
  Stream<T>? _source;
  _Replay<T>? _replay;

  Stream<T> of(Stream<T> source) {
    if (!identical(source, _source)) {
      _source = source;
      _replay = _Replay(source);
    }
    return _replay!.stream;
  }
}

/// Listens to a stream once and replays its last value to later listeners.
class _Replay<T> {
  _Replay(Stream<T> source) {
    source.listen(
      (value) {
        _last = (value,);
        _controller.add(value);
      },
      onError: _controller.addError,
      onDone: _controller.close,
    );
  }

  final _controller = StreamController<T>.broadcast();
  (T,)? _last;

  /// A new broadcast stream each time, like Firestore's: every listener,
  /// including one that comes after another left, starts with the last
  /// value. (Not `Stream.multi`: under a test's fake time a closed source
  /// never reached its listeners as done.)
  Stream<T> get stream {
    late final StreamController<T> out;
    StreamSubscription<T>? subscription;
    out = StreamController<T>.broadcast(
      onListen: () {
        final last = _last;
        if (last != null) out.add(last.$1);
        subscription = _controller.stream.listen(
          out.add,
          onError: out.addError,
          onDone: out.close,
        );
      },
      onCancel: () {
        subscription?.cancel();
        subscription = null;
      },
    );
    return out.stream;
  }
}
