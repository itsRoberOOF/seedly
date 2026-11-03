import 'package:flutter/widgets.dart';

import '../models/seedly_errors.dart';
import '../models/seedly_project.dart';
import '../services/seedly_task_completion.dart';
import 'seedly_alert.dart';

/// Shows a single, accurate drops toast when a task is completed.
///
/// The toast reflects the drops that were actually paid, so it never shows a
/// figure that then changes (a task that also finishes its project reads "+13"
/// once, not "+3" then "+13"), and it stays silent when nothing was earned: the
/// daily cap, an already-rewarded task, or an already-paid project. Toggling the
/// same task again before the write settles cancels the pending toast, so
/// marking and quickly unmarking never leaves a reward that wasn't given.
///
/// One screen keeps one [SeedlyDropsToaster].
class SeedlyDropsToaster {
  int _token = 0;

  Future<void> complete(
    BuildContext context,
    SeedlyTaskCompletion completion,
    SeedlyTask task, {
    required bool done,
    required void Function(Object error) onError,
  }) async {
    final token = ++_token;
    // Unmarking earns nothing; drop any toast still on screen right away.
    if (!done) hideSeedlyAlert();
    try {
      final earned = await completion.setDone(task, done);
      // A newer toggle has taken over, or the screen is gone.
      if (!context.mounted || token != _token) return;
      if (done) _show(context, earned);
    } on SeedlyProjectException catch (error) {
      if (!context.mounted || token != _token) return;
      onError(error);
    }
  }
}

void _show(BuildContext context, SeedlyDropsEarned earned) {
  final toast = seedlyDropsEarnedToast(earned);
  if (toast == null) return;
  showSeedlyAlert(
    context,
    style: SeedlyAlertStyle.success,
    title: toast.title,
    message: toast.message,
  );
}
