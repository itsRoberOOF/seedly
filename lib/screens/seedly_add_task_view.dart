import 'package:flutter/material.dart';

import '../modals/seedly_project_modal.dart';
import '../models/seedly_errors.dart';
import '../models/seedly_project.dart';
import '../repositories/seedly_project_repository.dart';
import '../widgets/seedly_alert.dart';
import 'seedly_create_task_view.dart';

/// Figma "Crear - Tarea" opened from the add menu: a task for a project that
/// already exists, which is picked in "Modal proyectos". Shown inside the
/// home so the menu stays visible.
class SeedlyAddTaskView extends StatefulWidget {
  const SeedlyAddTaskView({
    super.key,
    required this.projects,
    required this.onClose,
    required this.onCreated,
    this.today,
    this.onReminderSelected,
  });

  final SeedlyProjectRepository projects;
  final VoidCallback onClose;

  /// Called with the project and the task once it is saved.
  final void Function(SeedlyProject project, NewSeedlyTask task) onCreated;

  /// Defaults to the current day; tests pin it.
  final DateTime? today;

  /// Passed to the task form when notifications are available.
  final Future<bool> Function()? onReminderSelected;

  @override
  State<SeedlyAddTaskView> createState() => _SeedlyAddTaskViewState();
}

class _SeedlyAddTaskViewState extends State<SeedlyAddTaskView> {
  SeedlyProject? _project;
  bool _busy = false;

  Future<void> _pickProject() async {
    hideSeedlyAlert();
    // Its own query: the modal may be opened more than once.
    final chosen = await showSeedlyProjectModal(
      context,
      projects: widget.projects.watchProjects(),
      selected: _project,
      today: widget.today,
    );
    if (chosen != null && mounted) setState(() => _project = chosen);
  }

  Future<void> _save(NewSeedlyTask task) async {
    final project = _project;
    if (project == null || _busy) return;
    _busy = true;
    try {
      await widget.projects.addTask(project.id, task);
      if (mounted) widget.onCreated(project, task);
    } on SeedlyProjectException catch (error) {
      if (!mounted) return;
      showSeedlyAlert(
        context,
        style: SeedlyAlertStyle.danger,
        title: 'No se pudo crear la tarea',
        message: error.message,
      );
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = _project;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onClose();
      },
      child: SeedlyCreateTaskView(
        projectName: project?.name ?? '',
        projectIcon: (project?.icon ?? SeedlyProjectIcon.planta).asset,
        projectPhoto: project?.photo,
        today: widget.today,
        onClose: widget.onClose,
        onSave: _save,
        onReminderSelected: widget.onReminderSelected,
        onPickProject: _pickProject,
      ),
    );
  }
}
