import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/seedly_drops.dart';
import '../models/seedly_project.dart';
import '../models/seedly_user_profile.dart';
import '../repositories/seedly_drops_repository.dart';
import '../repositories/seedly_project_repository.dart';
import '../theme/seedly_theme.dart';
import '../utils/seedly_dates.dart';
import '../utils/seedly_validators.dart';
import '../widgets/seedly_button.dart';
import '../widgets/seedly_empty_card.dart';
import '../widgets/seedly_home_header.dart';
import '../widgets/seedly_info_card.dart';
import '../widgets/seedly_plant_blob.dart';

/// Figma "Inicio": the greeting and drops, the plant, today's focus and the
/// watering shortcut, then the tasks to attend and the projects in progress.
class SeedlyInicioView extends StatefulWidget {
  const SeedlyInicioView({
    super.key,
    required this.projects,
    this.profile,
    this.drops,
    this.onTaskTap,
    this.onProjectTap,
    this.onWater,
    this.onSeeProjects,
    this.onAdd,
  });

  final SeedlyProjectRepository projects;
  final SeedlyUserProfile? profile;

  /// Persona 4's plant state; without it the plant shows its first phase.
  final SeedlyDropsRepository? drops;

  /// Opens a task: Persona 1's editor, once it exists. Cards are not
  /// tappable without it.
  final void Function(String taskId)? onTaskTap;

  /// Opens a project's detail from its card.
  final void Function(String projectId)? onProjectTap;

  /// "Regar por 25 minutos": takes the person to Riego.
  final VoidCallback? onWater;

  /// "Ir a proyectos".
  final VoidCallback? onSeeProjects;

  /// Opens the add menu, from the empty tasks card.
  final VoidCallback? onAdd;

  /// Minutes of the watering session the shortcut offers, as in Figma.
  static const wateringMinutes = 25;

  /// How much smaller than Figma's 300×331 the plant is drawn, so the first
  /// project fits above the menu on a phone.
  static const plantScale = 0.85;

  /// Tasks and projects the lists stop at.
  static const _maxTasks = 10;
  static const _maxProjects = 4;

  @override
  State<SeedlyInicioView> createState() => _SeedlyInicioViewState();
}

class _SeedlyInicioViewState extends State<SeedlyInicioView> {
  static const _noPlant = SeedlyPlantState(phase: 1, totalDrops: 0);

  late final _today = SeedlyDates.day(DateTime.now());
  late final _todayTasks = widget.projects.watchTasksOn(_today);
  late final _upcomingTasks = widget.projects.watchTasksFrom(_today);
  late final _projects = widget.projects.watchProjects();
  late final Stream<SeedlyPlantState>? _plantState = widget.drops
      ?.watchPlantState();

  /// "Rober" out of "Rober Morán".
  String? get _firstName {
    final name = widget.profile?.displayName?.trim() ?? '';
    return name.isEmpty ? null : name.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    final spacing = SeedlyMetrics.spacing;
    // Figma's 48px top padding stands in for the status bar, as in Mi perfil.
    final top = math.max(
      spacing['xl']!,
      48 - MediaQuery.paddingOf(context).top,
    );
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(top: top, bottom: spacing['xl']!),
        child: StreamBuilder<List<SeedlyProject>>(
          stream: _projects,
          builder: (context, projects) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _padded(_top(projects.data ?? const [])),
              const SizedBox(height: 16),
              _padded(_title(context, 'Tareas por atender')),
              const SizedBox(height: 16),
              _upcoming(projects.data ?? const []),
              const SizedBox(height: 16),
              _padded(_projectsSection(context, projects)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _padded(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: child,
  );

  Widget _title(BuildContext context, String text) => Semantics(
    header: true,
    child: Text(text, style: Theme.of(context).textTheme.headlineSmall),
  );

  /// Figma's "Superior" frame, 24px between each of its parts. The focus
  /// card brings its own gap, so without it there is no double one.
  Widget _top(List<SeedlyProject> projects) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _withPlant(
          (plant) => Column(
            spacing: 24,
            children: [
              SeedlyHomeHeader(
                name: _firstName,
                initials: seedlyInitials(
                  widget.profile?.displayName,
                  widget.profile?.email,
                ),
                photo: widget.profile?.photo,
                drops: plant.totalDrops,
              ),
              SeedlyPlantBlob(
                phase: plant.phase,
                scale: SeedlyInicioView.plantScale,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        StreamBuilder<List<SeedlyTask>>(
          stream: _todayTasks,
          builder: (context, snapshot) {
            final today = snapshot.data;
            // Loading or failed: no card, rather than a wrong one.
            if (today == null) return const SizedBox.shrink();
            final focus = today.where((task) => !task.done).firstOrNull;
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: focus != null
                  ? SeedlyInfoCard(
                      icon: _iconOf(focus, projects),
                      superior: 'Enfoque de hoy',
                      title: focus.title,
                      showArrow: true,
                      onTap: _taskTap(focus),
                    )
                  // Nothing today and everything done today read differently.
                  : SeedlyEmptyCard(
                      superior: 'Enfoque de hoy',
                      title: today.isEmpty
                          ? '¿Qué toca hoy?'
                          : '¡Hoy quedó al día!',
                      done: today.isNotEmpty,
                      onTap: widget.onAdd,
                    ),
            );
          },
        ),
        SeedlyButton(
          label: 'Regar por ${SeedlyInicioView.wateringMinutes} minutos',
          expand: true,
          leading: SvgPicture.asset(
            'assets/images/icon_raindrop.svg',
            width: 24,
            height: 24,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
          onPressed: widget.onWater,
        ),
      ],
    );
  }

  Widget _withPlant(Widget Function(SeedlyPlantState plant) builder) {
    final stream = _plantState;
    if (stream == null) return builder(_noPlant);
    return StreamBuilder<SeedlyPlantState>(
      stream: stream,
      builder: (context, snapshot) => builder(snapshot.data ?? _noPlant),
    );
  }

  /// Figma's horizontal scroll of 260px cards.
  Widget _upcoming(List<SeedlyProject> projects) {
    return StreamBuilder<List<SeedlyTask>>(
      stream: _upcomingTasks,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _padded(const Text('No se pudieron cargar tus tareas.'));
        }
        if (!snapshot.hasData) return _padded(const Text('Cargando tareas…'));
        final all = snapshot.data!;
        final tasks = all
            .where((task) => !task.done)
            .take(SeedlyInicioView._maxTasks)
            .toList();
        if (tasks.isEmpty) {
          // Nothing scheduled and everything done read differently.
          return _padded(
            all.isEmpty
                ? SeedlyEmptyCard(
                    title: 'Sin pendientes',
                    helper: '¿Tienes algo en mente? Crea una tarea',
                    onTap: widget.onAdd,
                  )
                : SeedlyEmptyCard(
                    title: '¡Todo al día!',
                    helper: 'Buen trabajo, ¿algo más en mente?',
                    done: true,
                    onTap: widget.onAdd,
                  ),
          );
        }
        return SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            clipBehavior: Clip.none,
            itemCount: tasks.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final task = tasks[index];
              return SizedBox(
                width: 260,
                child: SeedlyInfoCard(
                  icon: _iconOf(task, projects),
                  title: task.title,
                  helper: task.dueDate == null
                      ? null
                      : SeedlyDates.due(task.dueDate!, task.dueMinutes, _today),
                  onTap: _taskTap(task),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _projectsSection(
    BuildContext context,
    AsyncSnapshot<List<SeedlyProject>> snapshot,
  ) {
    final Widget list;
    if (snapshot.hasError) {
      list = const Text('No se pudieron cargar tus proyectos.');
    } else if (!snapshot.hasData) {
      list = const Text('Cargando proyectos…');
    } else {
      final all = snapshot.data!;
      final active = all
          .where((project) => !project.isComplete)
          .take(SeedlyInicioView._maxProjects)
          .toList();
      list = active.isEmpty
          // No projects yet and every project finished read differently.
          ? (all.isEmpty
                ? SeedlyEmptyCard(
                    title: 'Sin proyectos',
                    helper: 'Crea tu primer proyecto',
                    onTap: widget.onAdd,
                  )
                : SeedlyEmptyCard(
                    title: '¡Proyectos al día!',
                    helper: 'Buen trabajo, ¿empezamos otro?',
                    done: true,
                    onTap: widget.onAdd,
                  ))
          : Column(
              spacing: 16,
              children: [
                for (final project in active)
                  SeedlyInfoCard(
                    icon: project.icon.asset,
                    title: project.name,
                    helper: _remaining(project),
                    progress: project.progress,
                    onTap: widget.onProjectTap == null
                        ? null
                        : () => widget.onProjectTap!(project.id),
                  ),
              ],
            );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        _title(context, 'Proyectos'),
        list,
        Align(
          alignment: Alignment.centerRight,
          child: SeedlyButton(
            label: 'Ir a proyectos',
            variant: SeedlyButtonVariant.text,
            size: SeedlyButtonSize.large,
            trailing: SvgPicture.asset(
              'assets/images/card_arrow_right.svg',
              width: 24,
              height: 24,
            ),
            onPressed: widget.onSeeProjects,
          ),
        ),
      ],
    );
  }

  VoidCallback? _taskTap(SeedlyTask task) {
    final onTaskTap = widget.onTaskTap;
    return onTaskTap == null ? null : () => onTaskTap(task.id);
  }

  /// A task wears its project's icon.
  String _iconOf(SeedlyTask task, List<SeedlyProject> projects) {
    for (final project in projects) {
      if (project.id == task.projectId) return project.icon.asset;
    }
    return SeedlyProjectIcon.planta.asset;
  }

  static String _remaining(SeedlyProject project) =>
      switch (project.remaining) {
        _ when project.taskCount == 0 => 'Sin tareas',
        1 => '1 tarea restante',
        final count => '$count tareas restantes',
      };
}
