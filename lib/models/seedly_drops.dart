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
