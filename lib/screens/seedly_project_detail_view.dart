import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../modals/seedly_delete_modal.dart';
import '../modals/seedly_project_modal.dart';
import '../models/seedly_errors.dart';
import '../models/seedly_project.dart';
import '../repositories/seedly_drops_repository.dart';
import '../repositories/seedly_project_repository.dart';
import '../services/seedly_image_picker.dart';
import '../services/seedly_task_completion.dart';
import '../theme/seedly_theme.dart';
import '../utils/seedly_dates.dart';
import '../widgets/seedly_alert.dart';
import '../widgets/seedly_button.dart';
import '../widgets/seedly_checkbox.dart';
import '../widgets/seedly_header.dart';
import '../widgets/seedly_segmented_control.dart';
import 'seedly_create_task_view.dart';
import 'seedly_edit_project_view.dart';

/// Figma "Detalle - Proyecto": the project's card with its progress, the
/// task list with its filter (tick, edit, delete) and "Añadir tarea". The
/// pencil opens "Editar - Proyecto". Shown inside the home so the menu
/// stays visible.
class SeedlyProjectDetailView extends StatefulWidget {
  const SeedlyProjectDetailView({
    super.key,
    required this.projectId,
    required this.projects,
    required this.onClose,
    this.drops,
    this.imagePicker,
    this.today,
    this.onReminderSelected,
  });

  final String projectId;
  final SeedlyProjectRepository projects;

  /// Pays and takes back drops as tasks are ticked; omitted in tests that
  /// don't care.
  final SeedlyDropsRepository? drops;
  final SeedlyImagePicker? imagePicker;

  /// Back to the catalog, also when the project turns out to be gone.
  final VoidCallback onClose;

  /// Defaults to the current day; tests pin it.
  final DateTime? today;

  /// Passed to the task form when notifications are available.
  final Future<bool> Function()? onReminderSelected;

  @override
  State<SeedlyProjectDetailView> createState() =>
      _SeedlyProjectDetailViewState();
}

/// What is open over the detail.
sealed class _Editing {
  const _Editing();
}

class _EditingProject extends _Editing {
  const _EditingProject();
}

/// The task form, for a new task ([task] null) or an existing one.
class _EditingTask extends _Editing {
  const _EditingTask(this.task);

  final SeedlyTask? task;
}

/// The "Todas / Pendientes / Completadas" filter.
enum _Filter { all, pending, done }

class _SeedlyProjectDetailViewState extends State<SeedlyProjectDetailView> {
  late final Stream<SeedlyProject?> _project = widget.projects.watchProject(
    widget.projectId,
  );
  late final Stream<List<SeedlyTask>> _tasks = widget.projects.watchTasks(
    widget.projectId,
  );
  late final _completion = SeedlyTaskCompletion(
    projects: widget.projects,
    drops: widget.drops,
  );
  _Editing? _editing;

  /// While editing a task, the project to move it to, or null to keep it in
  /// its own. Picked through "Proyecto", as when creating a task from scratch.
  SeedlyProject? _taskTargetProject;
  var _filter = _Filter.all;

  void _fail(String title, Object error) {
    if (!mounted) return;
    showSeedlyAlert(
      context,
      style: SeedlyAlertStyle.danger,
      title: title,
      message: error is SeedlyProjectException
          ? error.message
          : 'Inténtalo de nuevo en un momento.',
    );
  }

  Future<void> _toggle(SeedlyTask task, bool done) async {
    try {
      final earned = await _completion.setDone(task, done);
      if (!mounted) return;
      if (seedlyDropsEarnedToast(earned) case final toast?) {
        showSeedlyAlert(
          context,
          style: SeedlyAlertStyle.success,
          title: toast.title,
          message: toast.message,
        );
      }
    } on SeedlyProjectException catch (error) {
      _fail('No se pudo actualizar la tarea', error);
    }
  }

  Future<void> _deleteTask(SeedlyTask task) async {
    final confirmed = await showSeedlyDeleteModal(
      context,
      title: 'Eliminar tarea',
      message:
          '¿Estás seguro de eliminar esta tarea? Es una acción permanente y '
          'no podrá recuperarse después.',
    );
    if (!confirmed) return;
    try {
      await _completion.delete(task);
    } on SeedlyProjectException catch (error) {
      _fail('No se pudo eliminar la tarea', error);
    }
  }

  Future<void> _deleteProject(SeedlyProject project) async {
    final confirmed = await showSeedlyDeleteModal(
      context,
      title: 'Eliminar proyecto',
      message:
          '¿Estás seguro de eliminar este proyecto? Es una acción permanente '
          'y todas sus tareas e información se perderán.',
    );
    if (!confirmed) return;
    try {
      await widget.projects.deleteProject(project.id);
      // The project stream then emits null, which closes this view.
    } on SeedlyProjectException catch (error) {
      _fail('No se pudo eliminar el proyecto', error);
    }
  }

  Future<void> _saveTask(SeedlyProject project, NewSeedlyTask task) async {
    final editing = _editing;
    final existing = editing is _EditingTask ? editing.task : null;
    final target = _taskTargetProject;
    try {
      if (existing == null) {
        await widget.projects.addTask(project.id, task);
      } else if (target != null && target.id != existing.projectId) {
        await _completion.move(existing, target.id, task);
      } else {
        await widget.projects.updateTask(existing.id, task);
      }
      if (mounted) {
        setState(() {
          _editing = _afterTask;
          _taskTargetProject = null;
        });
      }
    } on SeedlyProjectException catch (error) {
      _fail('No se pudo guardar la tarea', error);
    }
  }

  /// Opens "Modal proyectos" to move the task being edited; [base] is the
  /// project it currently sits in. Choosing [base] again means "don't move".
  Future<void> _pickTaskProject(SeedlyProject base) async {
    hideSeedlyAlert();
    final chosen = await showSeedlyProjectModal(
      context,
      projects: widget.projects.watchProjects(),
      selected: _taskTargetProject ?? base,
      today: widget.today,
    );
    if (chosen != null && mounted) {
      setState(() => _taskTargetProject = chosen.id == base.id ? null : chosen);
    }
  }

  /// Where a task form returns to: the project form when it was opened from
  /// there, otherwise the detail.
  _Editing? _afterTask;

  void _openTask(SeedlyTask? task, {required _Editing? from}) {
    hideSeedlyAlert();
    setState(() {
      _afterTask = from;
      _editing = _EditingTask(task);
      _taskTargetProject = null;
    });
  }

  void _openProjectForm() {
    hideSeedlyAlert();
    setState(() => _editing = const _EditingProject());
  }

  /// Back one step: from a task form to where it was opened, from the
  /// project form to the detail.
  void _back() {
    hideSeedlyAlert();
    setState(() {
      if (_editing is _EditingTask) {
        _editing = _afterTask;
        _afterTask = null;
        _taskTargetProject = null;
      } else {
        _editing = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SeedlyProject?>(
      stream: _project,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _message('No se pudo cargar el proyecto. Revisa tu conexión.');
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _message('Cargando proyecto…');
        }
        final project = snapshot.data;
        if (project == null) {
          // Deleted here or elsewhere: nothing left to show.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onClose();
          });
          return const SizedBox.shrink();
        }
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (_editing != null) {
              _back();
            } else {
              widget.onClose();
            }
          },
          child: switch (_editing) {
            _EditingProject() => SeedlyEditProjectView(
              project: project,
              projects: widget.projects,
              imagePicker: widget.imagePicker,
              today: widget.today,
              onClose: _back,
              onSaved: () => setState(() => _editing = null),
              onDelete: () => _deleteProject(project),
              onAddTask: () => _openTask(null, from: const _EditingProject()),
              onEditTask: (task) =>
                  _openTask(task, from: const _EditingProject()),
              onDeleteTask: _deleteTask,
              onToggleTask: _toggle,
            ),
            final _EditingTask editing => () {
              // While editing, "Proyecto" can move the task; show the chosen
              // destination. A new task stays in this project.
              final shown = _taskTargetProject ?? project;
              return SeedlyCreateTaskView(
                key: ObjectKey(editing),
                projectName: shown.name,
                projectIcon: shown.icon.asset,
                projectPhoto: shown.photo,
                initial: editing.task == null
                    ? null
                    : NewSeedlyTask(
                        editing.task!.title,
                        done: editing.task!.done,
                        dueDate: editing.task!.dueDate,
                        dueMinutes: editing.task!.dueMinutes,
                        reminderMinutes: editing.task!.reminderMinutes,
                      ),
                today: widget.today,
                onClose: _back,
                onSave: (task) => _saveTask(project, task),
                onReminderSelected: widget.onReminderSelected,
                // Only an existing task can be moved; a new one belongs here.
                onPickProject: editing.task == null
                    ? null
                    : () => _pickTaskProject(project),
              );
            }(),
            null => _detail(context, project),
          },
        );
      },
    );
  }

  Widget _message(String text) => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SeedlyHeader(title: 'Proyecto', onBack: widget.onClose),
          const SizedBox(height: 40),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    ),
  );

  Widget _detail(BuildContext context, SeedlyProject project) {
    // Figma's 48px top padding stands in for the status bar, as in Inicio.
    final top = math.max(24.0, 48 - MediaQuery.paddingOf(context).top);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(32, top, 32, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SeedlyHeader(
              title: 'Proyecto',
              onBack: widget.onClose,
              action: SeedlyHeaderAction(
                asset: 'assets/images/icon_header_edit.svg',
                tooltip: 'Editar proyecto',
                onPressed: _openProjectForm,
              ),
            ),
            const SizedBox(height: 24),
            _ProjectCard(project: project),
            const SizedBox(height: 24),
            Expanded(child: _tasksSection()),
          ],
        ),
      ),
    );
  }

  Widget _tasksSection() => StreamBuilder<List<SeedlyTask>>(
    stream: _tasks,
    builder: (context, snapshot) {
      final tasks = snapshot.data;
      final remaining = tasks?.where((task) => !task.done).length;
      final shown = tasks == null
          ? const <SeedlyTask>[]
          : switch (_filter) {
              _Filter.all => tasks,
              _Filter.pending => [
                for (final task in tasks)
                  if (!task.done) task,
              ],
              _Filter.done => [
                for (final task in tasks)
                  if (task.done) task,
              ],
            };
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tareas',
                style: TextStyle(
                  fontSize: 18,
                  height: 28 / 18,
                  fontWeight: FontWeight.w600,
                  color: SeedlyPalette.neutral[850],
                ),
              ),
              if (remaining != null)
                Text(
                  remaining == 1 ? '1 restante' : '$remaining restantes',
                  style: TextStyle(
                    fontSize: 12,
                    height: 16 / 12,
                    fontWeight: FontWeight.w600,
                    color: SeedlyPalette.primary[500],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SeedlySegmentedControl<_Filter>(
            dense: true,
            options: const [
              (_Filter.all, 'Todas'),
              (_Filter.pending, 'Pendientes'),
              (_Filter.done, 'Completadas'),
            ],
            selected: _filter,
            onChanged: (filter) => setState(() => _filter = filter),
          ),
          const SizedBox(height: 20),
          Expanded(child: _list(snapshot, shown)),
          const SizedBox(height: 20),
          SeedlyButton(
            label: 'Añadir tarea',
            variant: SeedlyButtonVariant.outline,
            expand: true,
            leading: SvgPicture.asset(
              'assets/images/icon_plus.svg',
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(
                SeedlyPalette.primary[500]!,
                BlendMode.srcIn,
              ),
            ),
            onPressed: () => _openTask(null, from: null),
          ),
        ],
      );
    },
  );

  Widget _list(
    AsyncSnapshot<List<SeedlyTask>> snapshot,
    List<SeedlyTask> shown,
  ) {
    if (snapshot.hasError) {
      return const Center(child: Text('No se pudieron cargar las tareas.'));
    }
    if (snapshot.data == null) {
      return const Center(child: Text('Cargando tareas…'));
    }
    if (shown.isEmpty) {
      return Center(
        child: Text(
          snapshot.data!.isEmpty
              ? 'Este proyecto aún no tiene tareas.'
              : switch (_filter) {
                  _Filter.pending => 'No tienes tareas pendientes.',
                  _Filter.done => 'Aún no completas ninguna tarea.',
                  _Filter.all => '',
                },
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.separated(
      // Room for the cards' shadows at the scroll edges.
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: shown.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final task = shown[index];
        return SeedlyCheckboxCard(
          key: ValueKey(task.id),
          label: task.title,
          value: task.done,
          onChanged: (done) => _toggle(task, done),
          time: task.dueMinutes == null
              ? null
              : SeedlyDates.time(task.dueMinutes!),
          actions: [
            SeedlyCardAction('Editar', () => _openTask(task, from: null)),
            SeedlyCardAction('Eliminar', () => _deleteTask(task)),
          ],
        );
      },
    );
  }
}

/// Figma "Card-projectDetails": the project's icon, status, name and
/// description, its progress bar and its dates.
class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});

  final SeedlyProject project;

  @override
  Widget build(BuildContext context) {
    final percent = (project.progress * 100).round();
    final start = project.startDate;
    final end = project.endDate;
    final datesStyle = TextStyle(
      fontSize: 10,
      height: 14 / 10,
      fontWeight: FontWeight.w500,
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
          spacing: 20,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                _IconTile(project: project),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: SeedlyPalette.primary[50],
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: Text(
                            project.isComplete ? 'Completado' : 'Activo',
                            style: TextStyle(
                              fontSize: 10,
                              height: 14 / 10,
                              fontWeight: FontWeight.w600,
                              color: SeedlyPalette.neutral[850],
                            ),
                          ),
                        ),
                      ),
                      Text(
                        project.name,
                        style: TextStyle(
                          fontSize: 18,
                          height: 28 / 18,
                          fontWeight: FontWeight.w600,
                          color: SeedlyPalette.neutral[850],
                        ),
                      ),
                      if (project.description != null)
                        Text(
                          project.description!,
                          style: TextStyle(
                            fontSize: 12,
                            height: 16 / 12,
                            fontWeight: FontWeight.w500,
                            color: SeedlyPalette.neutral[600],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progreso',
                      style: TextStyle(
                        fontSize: 12,
                        height: 16 / 12,
                        fontWeight: FontWeight.w500,
                        color: SeedlyPalette.neutral[850],
                      ),
                    ),
                    Text(
                      '$percent%',
                      style: TextStyle(
                        fontSize: 12,
                        height: 16 / 12,
                        fontWeight: FontWeight.w600,
                        color: SeedlyPalette.primary[500],
                      ),
                    ),
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
                          child: ColoredBox(color: SeedlyPalette.primary[500]!),
                        ),
                      ],
                    ),
                  ),
                ),
                if (start != null || end != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        start == null
                            ? ''
                            : 'INICIO: ${SeedlyDates.dayMonth(start).toUpperCase()}',
                        style: datesStyle,
                      ),
                      Text(
                        end == null
                            ? ''
                            : 'FIN: ${SeedlyDates.dayMonth(end).toUpperCase()}',
                        style: datesStyle,
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The project's 48px tile: its photo, or its icon on grey.
class _IconTile extends StatelessWidget {
  const _IconTile({required this.project});

  final SeedlyProject project;

  @override
  Widget build(BuildContext context) {
    final photo = project.photo;
    return Semantics(
      label: 'Imagen del proyecto',
      child: ClipRRect(
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
      ),
    );
  }
}
