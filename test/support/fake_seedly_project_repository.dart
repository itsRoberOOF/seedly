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

  final created = <NewSeedlyProject>[];

  @override
  Future<SeedlyProjectSave> create(NewSeedlyProject project) async {
    if (error != null) throw error!;
    created.add(project);
    return save;
  }

  final _projectsWatch = _Watch<List<SeedlyProject>>();
  final _tasksOnWatch = _Watch<List<SeedlyTask>>();
  final _tasksFromWatch = _Watch<List<SeedlyTask>>();

  @override
  Stream<List<SeedlyProject>> watchProjects() => _projectsWatch.of(projects);

  @override
  Stream<List<SeedlyTask>> watchTasksOn(DateTime day) =>
      _tasksOnWatch.of(tasksOn);

  @override
  Stream<List<SeedlyTask>> watchTasksFrom(DateTime day) =>
      _tasksFromWatch.of(tasksFrom);
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

  Stream<T> get stream => Stream.multi((listener) {
    final last = _last;
    if (last != null) listener.add(last.$1);
    final subscription = _controller.stream.listen(
      listener.add,
      onError: listener.addError,
      onDone: listener.close,
    );
    listener.onCancel = subscription.cancel;
  });
}
