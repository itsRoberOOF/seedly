/// Every number of the drops game. firestore.rules repeats the amounts and
/// phases it checks; change both together.
abstract final class SeedlyDrops {
  static const perWateringMinute = 1;
  static const maxWateringMinutes = 120;
  static const perTask = 3;
  static const maxRewardedTasksPerDay = 20;
  static const perProject = 10;

  /// A project pays only when it has at least this many tasks, all done.
  static const minProjectTasks = 3;

  /// Drops a plant needs to reach each phase: phase n needs
  /// `phaseGoals[n - 1]`.
  static const phaseGoals = [0, 150, 500, 1200];
  static const maxPhase = 4;
}

/// What paid a drop movement; the stored value is [name].
enum SeedlyDropSource { task, project, watering }

/// Drops moved by ticking or unticking one task.
class SeedlyDropsChange {
  const SeedlyDropsChange({
    this.task = 0,
    this.project = 0,
    this.capped = false,
  });

  /// What ticking ([done]) or unticking a task moves, given what was already
  /// paid. The task pays [SeedlyDrops.perTask] once, unless today's cap is
  /// reached; its project pays [SeedlyDrops.perProject] once, when the tick
  /// leaves at least [SeedlyDrops.minProjectTasks] tasks all done. Unticking
  /// takes the task's drops back but never the project's. firestore.rules
  /// checks the same, except the cap.
  factory SeedlyDropsChange.ofTaskToggle({
    required bool done,
    required bool taskPaid,
    required int tasksPaidToday,
    required bool projectPaid,
    required int projectTasks,
    required int projectDoneAfter,
  }) {
    if (!done) {
      return SeedlyDropsChange(task: taskPaid ? -SeedlyDrops.perTask : 0);
    }
    final capped =
        !taskPaid && tasksPaidToday >= SeedlyDrops.maxRewardedTasksPerDay;
    final finishes =
        projectTasks >= SeedlyDrops.minProjectTasks &&
        projectDoneAfter == projectTasks;
    return SeedlyDropsChange(
      task: taskPaid || capped ? 0 : SeedlyDrops.perTask,
      project: finishes && !projectPaid ? SeedlyDrops.perProject : 0,
      capped: capped,
    );
  }

  static const none = SeedlyDropsChange();

  /// Paid for the task itself; negative when unticking takes them back.
  final int task;

  /// Paid for finishing the task's project.
  final int project;

  /// The tick paid nothing for the task because today's cap was reached.
  final bool capped;

  int get total => task + project;

  @override
  bool operator ==(Object other) =>
      other is SeedlyDropsChange &&
      other.task == task &&
      other.project == project &&
      other.capped == capped;

  @override
  int get hashCode => Object.hash(task, project, capped);

  @override
  String toString() =>
      'SeedlyDropsChange(task: $task, project: $project, capped: $capped)';
}

/// A task just ticked or unticked: the [drops] it moved, known as soon as the
/// write is in this device's local view, and [saved], which completes once
/// the server accepts it. If the server refuses, [saved] throws the
/// repository's exception and the local view undoes the write.
class SeedlyTaskToggle {
  const SeedlyTaskToggle(this.drops, this.saved);

  /// Nothing moved and nothing is left to save.
  SeedlyTaskToggle.unchanged()
    : drops = SeedlyDropsChange.none,
      saved = Future<void>.value();

  final SeedlyDropsChange drops;
  final Future<void> saved;
}

/// The plant's phase and every drop collected, spent or not: growing is
/// manual and costs nothing.
class SeedlyPlantState {
  const SeedlyPlantState({required this.phase, required this.totalDrops});

  final int phase;
  final int totalDrops;

  /// Drops the next phase needs, or null at the last phase.
  int? get nextGoal =>
      phase < SeedlyDrops.maxPhase ? SeedlyDrops.phaseGoals[phase] : null;

  bool get canGrow => nextGoal != null && totalDrops >= nextGoal!;

  @override
  bool operator ==(Object other) =>
      other is SeedlyPlantState &&
      other.phase == phase &&
      other.totalDrops == totalDrops;

  @override
  int get hashCode => Object.hash(phase, totalDrops);

  @override
  String toString() => 'SeedlyPlantState(phase: $phase, drops: $totalDrops)';
}
