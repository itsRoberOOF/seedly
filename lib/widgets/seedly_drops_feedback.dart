import 'package:flutter/widgets.dart';

import '../models/seedly_drops.dart';
import '../models/seedly_errors.dart';
import '../models/seedly_project.dart';
import '../services/seedly_task_completion.dart';
import 'seedly_alert.dart';

/// Marks [task] done/undone and gives instant drop feedback.
///
/// The success toast shows the moment the task is tapped, so it never waits on
/// the network. When the write settles it is reconciled with the drops actually
/// paid: hidden when nothing was (the daily cap, or a task already rewarded) and
/// upgraded when the task also finished its project. A failed save replaces it
/// with an error toast via [onError]. Toasts always replace each other, and
/// unmarking shows none.
Future<void> completeSeedlyTask(
  BuildContext context,
  SeedlyTaskCompletion completion,
  SeedlyTask task, {
  required bool done,
  required void Function(Object error) onError,
}) async {
  const optimistic = (task: SeedlyDrops.perTask, project: 0);
  if (done) {
    _showEarned(context, optimistic);
  } else {
    // Unmarking earns nothing; clear any toast still on screen.
    hideSeedlyAlert();
  }
  try {
    final earned = await completion.setDone(task, done);
    // Nothing to correct when we're unmarking or the guess was already right.
    if (!context.mounted || !done || earned == optimistic) return;
    _showEarned(context, earned);
  } on SeedlyProjectException catch (error) {
    if (!context.mounted) return;
    onError(error);
  }
}

void _showEarned(BuildContext context, SeedlyDropsEarned earned) {
  final toast = seedlyDropsEarnedToast(earned);
  if (toast == null) {
    hideSeedlyAlert();
    return;
  }
  showSeedlyAlert(
    context,
    style: SeedlyAlertStyle.success,
    title: toast.title,
    message: toast.message,
  );
}
