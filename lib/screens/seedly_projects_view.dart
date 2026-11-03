import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/seedly_errors.dart';
import '../models/seedly_project.dart';
import '../repositories/seedly_drops_repository.dart';
import '../repositories/seedly_project_repository.dart';
import '../services/seedly_image_picker.dart';
import '../services/seedly_task_completion.dart';
import '../theme/seedly_theme.dart';
import '../utils/seedly_dates.dart';
import '../widgets/seedly_alert.dart';
import '../widgets/seedly_drops_feedback.dart';
import '../widgets/seedly_button.dart';
import '../widgets/seedly_deadline_tag.dart';
import '../widgets/seedly_search_bar.dart';
import '../widgets/seedly_segmented_control.dart';
import 'seedly_project_detail_view.dart';

/// Figma "Proyectos": the catalog of the user's projects with its
/// Activos / Completados tabs, a search bar and expandable project cards,
/// and the detail of the one opened from it. Firestore keeps a local copy,
/// so offline the list shows what was last seen.
class SeedlyProjectsView extends StatefulWidget {
  const SeedlyProjectsView({
    super.key,
    required this.projects,
    this.drops,
    this.imagePicker,
    this.today,
    this.onReminderSelected,
    this.initialProjectId,
  });

  /// Opens this project's detail straight away, such as from a task in
  /// Inicio.
  final String? initialProjectId;

  final SeedlyProjectRepository projects;
  final SeedlyDropsRepository? drops;
  final SeedlyImagePicker? imagePicker;

  /// Defaults to the current day; tests pin it.
  final DateTime? today;
  final Future<bool> Function()? onReminderSelected;

  @override
  State<SeedlyProjectsView> createState() => _SeedlyProjectsViewState();
}

enum _Tab { active, completed }

class _SeedlyProjectsViewState extends State<SeedlyProjectsView> {
  late var _stream = widget.projects.watchProjects();
  late final _completion = SeedlyTaskCompletion(
    projects: widget.projects,
    drops: widget.drops,
  );
  var _tab = _Tab.active;
  var _query = '';
  final _expanded = <String>{};

  /// The project whose detail is open, if any.
  late String? _openId = widget.initialProjectId;

  void _retry() => setState(() => _stream = widget.projects.watchProjects());

  Future<void> _toggleTask(SeedlyTask task, bool done) {
    return completeSeedlyTask(
      context,
      _completion,
      task,
      done: done,
      onError: (error) => showSeedlyAlert(
        context,
        style: SeedlyAlertStyle.danger,
        title: 'No se pudo actualizar la tarea',
        message: error is SeedlyProjectException
            ? error.message
            : 'Inténtalo de nuevo en un momento.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final openId = _openId;
    if (openId != null) {
      return SeedlyProjectDetailView(
        key: ValueKey(openId),
        projectId: openId,
        projects: widget.projects,
        drops: widget.drops,
        imagePicker: widget.imagePicker,
        today: widget.today,
        onReminderSelected: widget.onReminderSelected,
        onClose: () => setState(() => _openId = null),
      );
    }
    // Figma's 48px top padding stands in for the status bar, as in Inicio.
    final top = math.max(24.0, 48 - MediaQuery.paddingOf(context).top);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(32, top, 32, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            Text(
              'Proyectos',
              style: TextStyle(
                fontSize: 32,
                height: 38 / 32,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: SeedlyPalette.neutral[850],
              ),
            ),
            SeedlySegmentedControl<_Tab>(
              options: const [
                (_Tab.active, 'Activos'),
                (_Tab.completed, 'Completados'),
              ],
              selected: _tab,
              onChanged: (tab) => setState(() => _tab = tab),
            ),
            SeedlySearchBar(
              hint: 'Buscar proyectos...',
              onChanged: (query) => setState(() => _query = query.trim()),
            ),
            Expanded(
              child: StreamBuilder<List<SeedlyProject>>(
                stream: _stream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _status(
                      'No se pudieron cargar tus proyectos. '
                      'Revisa tu conexión.',
                      retry: true,
                    );
                  }
                  final all = snapshot.data;
                  if (all == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (all.isEmpty) {
                    return _status(
                      'Aún no tienes proyectos. Crea el primero con el botón +.'
                      ' Si estás sin conexión, aparecerán cuando vuelva.',
                    );
                  }
                  final query = _query.toLowerCase();
                  final shown = [
                    for (final project in all)
                      if (project.isComplete == (_tab == _Tab.completed) &&
                          project.name.toLowerCase().contains(query))
                        project,
                  ];
                  if (shown.isEmpty) {
                    return _status(
                      query.isNotEmpty
                          ? 'No hay proyectos que coincidan con «$_query».'
                          : _tab == _Tab.active
                          ? 'No tienes proyectos activos.'
                          : 'Aún no completas ningún proyecto.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: shown.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 24),
                    itemBuilder: (context, index) {
                      final project = shown[index];
                      return _ProjectCard(
                        key: ValueKey(project.id),
                        project: project,
                        today: SeedlyDates.day(widget.today ?? DateTime.now()),
                        projects: widget.projects,
                        expanded: _expanded.contains(project.id),
                        onToggle: () => setState(() {
                          if (!_expanded.remove(project.id)) {
                            _expanded.add(project.id);
                          }
                        }),
                        onOpen: () => setState(() => _openId = project.id),
                        onToggleTask: _toggleTask,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _status(String text, {bool retry = false}) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        Text(text, textAlign: TextAlign.center),
        if (retry)
          SeedlyButton(
            label: 'Reintentar',
            variant: SeedlyButtonVariant.outline,
            size: SeedlyButtonSize.small,
            onPressed: _retry,
          ),
      ],
    ),
  );
}

/// Figma "Card-projects - App": collapsed it shows the project's name and
/// counts; expanded, its delivery tag, progress bar, first pending tasks and
/// "Ver proyecto".
class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    super.key,
    required this.project,
    required this.today,
    required this.projects,
    required this.expanded,
    required this.onToggle,
    required this.onOpen,
    required this.onToggleTask,
  });

  final SeedlyProject project;
  final DateTime today;
  final SeedlyProjectRepository projects;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onOpen;
  final void Function(SeedlyTask task, bool done) onToggleTask;

  @override
  Widget build(BuildContext context) {
    final percent = (project.progress * 100).round();
    final deadline = seedlyDeadlineLabel(project, today);
    final gray12 = TextStyle(
      fontSize: 12,
      height: 16 / 12,
      color: SeedlyPalette.neutral[600],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SeedlyPalette.neutral[50],
        borderRadius: BorderRadius.circular(SeedlyMetrics.radii['lg']!),
        border: Border.all(color: SeedlyPalette.border),
        boxShadow: SeedlyShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            InkWell(
              onTap: onToggle,
              child: Row(
                spacing: 12,
                children: [
                  _Tile(project: project),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (expanded && deadline != null)
                          SeedlyDeadlineTag(deadline),
                        Text(
                          project.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            height: 28 / 18,
                            fontWeight: FontWeight.w600,
                            color: SeedlyPalette.neutral[850],
                          ),
                        ),
                        if (!expanded)
                          Text(
                            '${project.taskCount} '
                            '${project.taskCount == 1 ? 'tarea' : 'tareas'}'
                            ' • $percent% completado',
                            style: gray12.copyWith(
                              fontSize: 10,
                              height: 14 / 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: expanded ? 'Contraer proyecto' : 'Expandir proyecto',
                    child: SvgPicture.asset(
                      expanded
                          ? 'assets/images/icon_nav_up.svg'
                          : 'assets/images/icon_nav_down.svg',
                      width: 24,
                      height: 24,
                    ),
                  ),
                ],
              ),
            ),
            if (expanded) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 6,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${project.taskCount} '
                        '${project.taskCount == 1 ? 'tarea' : 'tareas'}',
                        style: gray12,
                      ),
                      Text('$percent% completado', style: gray12),
                    ],
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 8,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(color: SeedlyPalette.primary[150]!),
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: project.progress,
                            child: ColoredBox(
                              color: SeedlyPalette.primary[500]!,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              _PendingTasks(
                tasks: projects.watchTasks(project.id),
                onToggleTask: onToggleTask,
              ),
              SeedlyButton(
                label: 'Ver proyecto',
                variant: SeedlyButtonVariant.outline,
                size: SeedlyButtonSize.medium,
                expand: true,
                trailing: SvgPicture.asset(
                  'assets/images/icon_docs.svg',
                  width: 24,
                  height: 24,
                ),
                onPressed: onOpen,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The first three pending tasks of an expanded card, as plain checkbox
/// rows (Figma's "Checkboxes" frame).
class _PendingTasks extends StatefulWidget {
  const _PendingTasks({required this.tasks, required this.onToggleTask});

  final Stream<List<SeedlyTask>> tasks;
  final void Function(SeedlyTask task, bool done) onToggleTask;

  @override
  State<_PendingTasks> createState() => _PendingTasksState();
}

class _PendingTasksState extends State<_PendingTasks> {
  // Subscribed once per expansion; the card rebuilds around it.
  late final Stream<List<SeedlyTask>> _tasks = widget.tasks;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SeedlyTask>>(
      stream: _tasks,
      builder: (context, snapshot) {
        final pending = [
          for (final task in snapshot.data ?? const <SeedlyTask>[])
            if (!task.done) task,
        ].take(3).toList();
        if (pending.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            spacing: 12,
            children: [
              for (final task in pending)
                InkWell(
                  onTap: () => widget.onToggleTask(task, true),
                  child: Row(
                    spacing: 12,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: SeedlyPalette.primary[500]!,
                            width: 1.5,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              style: TextStyle(
                                fontSize: 14,
                                height: 20 / 14,
                                color: SeedlyPalette.neutral[850],
                              ),
                            ),
                            if (task.dueMinutes != null)
                              Row(
                                spacing: 2,
                                children: [
                                  SvgPicture.asset(
                                    'assets/images/icon_clock.svg',
                                    width: 12,
                                    height: 12,
                                  ),
                                  Text(
                                    SeedlyDates.time(task.dueMinutes!),
                                    style: TextStyle(
                                      fontSize: 10,
                                      height: 14 / 10,
                                      color: SeedlyPalette.neutral[600],
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The project's 48px tile: its photo, or its icon on grey.
class _Tile extends StatelessWidget {
  const _Tile({required this.project});

  final SeedlyProject project;

  @override
  Widget build(BuildContext context) {
    final photo = project.photo;
    return ClipRRect(
      borderRadius: BorderRadius.circular(SeedlyMetrics.radii['md']!),
      child: ColoredBox(
        color: SeedlyPalette.neutral[200]!,
        child: SizedBox(
          width: 48,
          height: 48,
          child: photo != null
              ? Image.memory(photo, fit: BoxFit.cover)
              : Center(
                  child: SvgPicture.asset(
                    project.icon.asset,
                    width: 24,
                    height: 24,
                  ),
                ),
        ),
      ),
    );
  }
}
