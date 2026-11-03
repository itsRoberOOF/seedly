import 'dart:async';
import 'dart:math' as math;

import '../repositories/seedly_auth_repository.dart';
import '../repositories/seedly_drops_repository.dart';
import '../repositories/seedly_project_repository.dart';
import '../repositories/seedly_user_repository.dart';
import '../utils/seedly_dates.dart';

/// One piece of work the app does behind its loading screen.
typedef SeedlyStartupStep = Future<Object?> Function();

/// The steps for whoever is signed in: the first thing each part of Inicio
/// reads, so it opens with data instead of "Cargando…". Nobody signed in has
/// nothing to load.
///
/// Each step only waits for the first value of a stream, which also leaves it
/// in Firestore's cache for the screen that follows.
List<SeedlyStartupStep> seedlyStartupSteps({
  required SeedlyAuthRepository auth,
  required SeedlyProjectRepository projects,
  required SeedlyUserRepository users,
  SeedlyDropsRepository? drops,
  DateTime? today,
}) {
  final uid = auth.currentUserId;
  if (uid == null) return const [];
  final day = SeedlyDates.day(today ?? DateTime.now());
  return [
    () => users.watchProfile(uid).first,
    if (drops != null) () => drops.watchPlantState().first,
    () => projects.watchTasksFrom(day).first,
    () => projects.watchProjects().first,
  ];
}

/// Runs the [steps] of the loading screen and reports how far they are, from
/// 0 to 1.
///
/// The steps run together. Loading never gets stuck on one: a step that fails
/// or takes longer than [stepTimeout] counts as done, since the next screen
/// works with what Firestore has stored. It lasts at least [minDuration], so
/// the logo and the bar are seen even when everything is already cached.
///
/// Time is counted in its own ticks, not read from a clock, so it behaves the
/// same on a phone and under a test's fake time.
class SeedlyStartup {
  SeedlyStartup({
    required this.steps,
    this.minDuration = const Duration(milliseconds: 900),
    this.stepTimeout = const Duration(seconds: 4),
    this.settle = const Duration(milliseconds: 250),
  });

  final List<SeedlyStartupStep> steps;
  final Duration minDuration;
  final Duration stepTimeout;

  /// How long the full bar stays before leaving.
  final Duration settle;

  static const _tick = Duration(milliseconds: 50);

  /// While a step is pending the bar keeps creeping toward the next one, so
  /// a slow step never looks frozen. This is how fast it slows down.
  static const _creepSeconds = 1.2;

  final _timers = <Timer>[];
  Completer<void>? _over;
  var _cancelled = false;

  /// Completes when the loading is over, or after [cancel].
  Future<void> run(void Function(double progress) onProgress) {
    final over = _over = Completer<void>();
    final count = steps.length;
    var done = 0;
    var elapsed = Duration.zero;
    var sinceStep = Duration.zero;
    var shown = 0.0;

    double target() {
      final paced = elapsed.inMilliseconds / minDuration.inMilliseconds;
      if (count == 0) return paced.clamp(0.0, 1.0);
      final slice = 1 / count;
      final creep =
          slice *
          0.9 *
          (1 - math.exp(-sinceStep.inMilliseconds / 1000 / _creepSeconds));
      final real = done == count ? 1.0 : done * slice + creep;
      // Whichever is slower: the work, or the minimum time.
      return math.min(real, paced).clamp(0.0, 1.0);
    }

    onProgress(0);
    for (var i = 0; i < count; i++) {
      _runStep(steps[i]).then((_) {
        if (_cancelled) return;
        done++;
        sinceStep = Duration.zero;
      });
    }
    _timers.add(
      Timer.periodic(_tick, (timer) {
        elapsed += _tick;
        sinceStep += _tick;
        shown = math.max(shown, target());
        final complete = done == count && elapsed >= minDuration;
        if (complete) {
          timer.cancel();
          onProgress(1);
          _timers.add(
            Timer(settle, () {
              if (!over.isCompleted) over.complete();
            }),
          );
        } else {
          onProgress(shown);
        }
      }),
    );
    return over.future;
  }

  /// Stops everything, such as when the loading screen goes away first.
  void cancel() {
    _cancelled = true;
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    final over = _over;
    if (over != null && !over.isCompleted) over.complete();
  }

  Future<void> _runStep(SeedlyStartupStep step) {
    final finished = Completer<void>();
    void finish() {
      if (!finished.isCompleted) finished.complete();
    }

    final timeout = Timer(stepTimeout, finish);
    _timers.add(timeout);
    Future<Object?>.sync(step).then<void>(
      (_) => finish(),
      // A step that fails never blocks the app.
      onError: (Object _) => finish(),
    );
    return finished.future.whenComplete(timeout.cancel);
  }
}
