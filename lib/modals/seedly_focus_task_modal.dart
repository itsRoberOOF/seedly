import 'package:flutter/material.dart';

import '../models/seedly_project.dart';
import '../repositories/seedly_project_repository.dart';
import '../theme/seedly_theme.dart';
import '../utils/seedly_dates.dart';
import '../widgets/seedly_info_card.dart';
import '../widgets/seedly_modal.dart';

/// Lo que se eligió en "Elegir tarea": una tarea, o null para "Sesión
/// libre".
typedef SeedlyFocusChoice = ({SeedlyTask? task});

/// "Elegir tarea" de Riego: "Sesión libre" y las tareas pendientes de hoy,
/// cada una con el ícono de su proyecto como en Inicio. Completa con la
/// elección, o null si se cierra sin elegir.
Future<SeedlyFocusChoice?> showSeedlyFocusTaskModal(
  BuildContext context, {
  required SeedlyProjectRepository projects,
  String? selectedTaskId,
}) {
  return showSeedlyModal<SeedlyFocusChoice>(
    context,
    builder: (context) =>
        _FocusTaskModal(projects: projects, selectedTaskId: selectedTaskId),
  );
}

class _FocusTaskModal extends StatefulWidget {
  const _FocusTaskModal({required this.projects, this.selectedTaskId});

  final SeedlyProjectRepository projects;
  final String? selectedTaskId;

  @override
  State<_FocusTaskModal> createState() => _FocusTaskModalState();
}

class _FocusTaskModalState extends State<_FocusTaskModal> {
  late final _today = SeedlyDates.day(DateTime.now());
  late final _tasks = widget.projects.watchTasksOn(_today);
  late final _projects = widget.projects.watchProjects();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        Text(
          'Elegir tarea',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            height: 28 / 18,
            fontWeight: FontWeight.w600,
            color: SeedlyPalette.neutral[850],
          ),
        ),
        SeedlyInfoCard(
          icon: 'assets/images/icon_question.svg',
          title: 'Sesión libre',
          helper: 'Sin una tarea definida',
          superior: widget.selectedTaskId == null ? 'Elegida' : null,
          onTap: () => Navigator.of(context).pop((task: null)),
        ),
        StreamBuilder<List<SeedlyProject>>(
          stream: _projects,
          builder: (context, projects) => StreamBuilder<List<SeedlyTask>>(
            stream: _tasks,
            builder: (context, snapshot) =>
                _taskList(snapshot, projects.data ?? const []),
          ),
        ),
      ],
    );
  }

  Widget _taskList(
    AsyncSnapshot<List<SeedlyTask>> snapshot,
    List<SeedlyProject> projects,
  ) {
    if (snapshot.hasError) {
      return _note('No se pudieron cargar tus tareas.');
    }
    final tasks = snapshot.data?.where((task) => !task.done).toList();
    if (tasks == null) return _note('Cargando tareas…');
    if (tasks.isEmpty) return _note('No tienes tareas pendientes para hoy.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        for (final task in tasks)
          SeedlyInfoCard(
            icon: _iconOf(task, projects),
            title: task.title,
            superior: task.id == widget.selectedTaskId ? 'Elegida' : null,
            helper: task.dueMinutes == null
                ? null
                : 'Hoy • ${SeedlyDates.time(task.dueMinutes!)}',
            onTap: () => Navigator.of(context).pop((task: task)),
          ),
      ],
    );
  }

  Widget _note(String text) => Text(
    text,
    textAlign: TextAlign.center,
    style: TextStyle(
      fontSize: 14,
      height: 20 / 14,
      color: SeedlyPalette.neutral[600],
    ),
  );

  /// Una tarea lleva el ícono de su proyecto, como en Inicio.
  static String _iconOf(SeedlyTask task, List<SeedlyProject> projects) {
    for (final project in projects) {
      if (project.id == task.projectId) return project.icon.asset;
    }
    return SeedlyProjectIcon.planta.asset;
  }
}
