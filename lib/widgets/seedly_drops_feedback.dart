import 'package:flutter/widgets.dart';

import '../models/seedly_drops.dart';
import '../models/seedly_errors.dart';
import '../models/seedly_project.dart';
import '../services/seedly_task_completion.dart';
import 'seedly_alert.dart';

/// Ticks a task and says what it did to the drops, the moment it's tapped.
///
/// The task and its drops are written together and this device shows the
/// write at once, so the toast states exactly what was paid or taken back,
/// with no wait and nothing to correct later. Quick ticks add up in the toast
/// already on screen instead of replacing it; unticking says the drops went
/// back; a tick at the daily cap says why it paid nothing. If the server then
/// refuses the write, this device undoes it and [onError] reports it.
///
/// One screen keeps one [SeedlyDropsToaster].
class SeedlyDropsToaster {
  var _streak = const SeedlyDropsStreak();
  Object? _toast;

  Future<void> complete(
    BuildContext context,
    SeedlyTaskCompletion completion,
    SeedlyTask task, {
    required bool done,
    required void Function(Object error) onError,
  }) async {
    final SeedlyTaskToggle toggle;
    try {
      toggle = await completion.setDone(task, done);
    } on SeedlyProjectException catch (error) {
      if (context.mounted) onError(error);
      return;
    }
    if (!context.mounted) return;
    _announce(context, toggle.drops);
    try {
      await toggle.saved;
    } on SeedlyProjectException catch (error) {
      if (!context.mounted) return;
      _streak = const SeedlyDropsStreak();
      onError(error);
    }
  }

  void _announce(BuildContext context, SeedlyDropsChange change) {
    final shown = _toast;
    final adding =
        change.total > 0 && shown != null && isSeedlyAlertVisible(shown);
    final streak = adding ? _streak : const SeedlyDropsStreak();
    final toast = seedlyDropsToast(change, streak: streak);
    if (toast == null) return;
    _streak = change.total > 0 ? streak.add(change) : const SeedlyDropsStreak();
    _toast = showSeedlyAlert(
      context,
      style: toast.style,
      title: toast.title,
      message: toast.message,
    );
  }
}

/// Drops gained by the ticks that one toast adds up.
class SeedlyDropsStreak {
  const SeedlyDropsStreak({
    this.tasks = 0,
    this.taskDrops = 0,
    this.projects = 0,
    this.projectDrops = 0,
  });

  /// Tasks that paid, and what they paid.
  final int tasks;
  final int taskDrops;

  /// Projects finished, and what they paid.
  final int projects;
  final int projectDrops;

  int get total => taskDrops + projectDrops;

  SeedlyDropsStreak add(SeedlyDropsChange change) => SeedlyDropsStreak(
    tasks: tasks + (change.task > 0 ? 1 : 0),
    taskDrops: taskDrops + (change.task > 0 ? change.task : 0),
    projects: projects + (change.project > 0 ? 1 : 0),
    projectDrops: projectDrops + change.project,
  );
}

typedef SeedlyDropsToast = ({
  SeedlyAlertStyle style,
  String title,
  String message,
});

/// What to say about a tick's [change]: the gains so far, adding it to
/// [streak]; drops taken back; a tick that paid nothing at the daily cap; or
/// null when nothing moved worth saying.
SeedlyDropsToast? seedlyDropsToast(
  SeedlyDropsChange change, {
  SeedlyDropsStreak streak = const SeedlyDropsStreak(),
}) {
  if (change.total > 0) return _gained(streak.add(change));
  if (change.task < 0) {
    final taken = -change.task;
    return (
      style: SeedlyAlertStyle.warning,
      title: 'Tarea desmarcada',
      message: 'Se descontaron $taken ${_gotas(taken)} de tu planta.',
    );
  }
  if (change.capped) {
    return (
      style: SeedlyAlertStyle.info,
      title: 'Llegaste al tope de hoy',
      message:
          'Ya sumaste gotas por ${SeedlyDrops.maxRewardedTasksPerDay} '
          'tareas hoy; esta no suma más.',
    );
  }
  return null;
}

SeedlyDropsToast _gained(SeedlyDropsStreak streak) {
  final total = streak.total;
  final gotas = '$total ${_gotas(total)}';
  if (streak.projects == 0) {
    return (
      style: SeedlyAlertStyle.success,
      title: '¡Buen trabajo!',
      message: streak.tasks == 1
          ? 'Conseguiste $gotas por tu tarea.'
          : 'Conseguiste $gotas por ${streak.tasks} tareas.',
    );
  }
  final one = streak.projects == 1;
  final title = one
      ? '¡Proyecto completado!'
      : '¡Completaste ${streak.projects} proyectos!';
  if (streak.taskDrops == 0) {
    return (
      style: SeedlyAlertStyle.success,
      title: title,
      message:
          'Conseguiste $gotas por completar '
          '${one ? 'el proyecto' : 'los proyectos'}.',
    );
  }
  return (
    style: SeedlyAlertStyle.success,
    title: title,
    message:
        'Conseguiste $gotas (+${streak.taskDrops} '
        '${streak.tasks == 1 ? 'de la tarea' : 'de las tareas'} y '
        '+${streak.projectDrops} ${one ? 'del proyecto' : 'de los proyectos'}).',
  );
}

String _gotas(int n) => n == 1 ? 'gota' : 'gotas';
