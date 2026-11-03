import 'dart:typed_data';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../modals/seedly_date_modal.dart';
import '../modals/seedly_icon_modal.dart';
import '../models/seedly_errors.dart';
import '../models/seedly_project.dart';
import '../repositories/seedly_project_repository.dart';
import '../services/seedly_image_picker.dart';
import '../theme/seedly_theme.dart';
import '../utils/seedly_dates.dart';
import '../widgets/seedly_alert.dart';
import '../widgets/seedly_avatar.dart';
import '../widgets/seedly_button.dart';
import '../widgets/seedly_checkbox.dart';
import '../widgets/seedly_header.dart';
import '../widgets/seedly_input.dart';
import '../widgets/seedly_input_button.dart';

/// Figma "Editar - Proyecto": the create form's own fields (avatar, name,
/// description and dates) filled in with the saved project, its tasks with
/// "Añadir tarea", and the trash can that deletes the project. Its kind
/// stays as it was.
class SeedlyEditProjectView extends StatefulWidget {
  const SeedlyEditProjectView({
    super.key,
    required this.project,
    required this.projects,
    required this.onClose,
    required this.onSaved,
    required this.onDelete,
    required this.onAddTask,
    required this.onEditTask,
    required this.onDeleteTask,
    required this.onToggleTask,
    this.imagePicker,
    this.today,
  });

  final SeedlyProject project;
  final SeedlyProjectRepository projects;
  final VoidCallback onClose;

  /// Called once the changes are saved.
  final VoidCallback onSaved;

  /// The trash can: the caller asks for confirmation and deletes.
  final VoidCallback onDelete;
  final VoidCallback onAddTask;
  final void Function(SeedlyTask task) onEditTask;
  final void Function(SeedlyTask task) onDeleteTask;
  final void Function(SeedlyTask task, bool done) onToggleTask;

  /// Defaults to the device gallery; tests pass a fake.
  final SeedlyImagePicker? imagePicker;

  /// Defaults to the current day; tests pin it.
  final DateTime? today;

  @override
  State<SeedlyEditProjectView> createState() => _SeedlyEditProjectViewState();
}

class _SeedlyEditProjectViewState extends State<SeedlyEditProjectView> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.project.name);
  late final _description = TextEditingController(
    text: widget.project.description,
  );
  late var _icon = widget.project.icon;
  late Uint8List? _photo = widget.project.photo;
  late DateTime? _start = widget.project.startDate;
  late DateTime? _end = widget.project.endDate;
  late final SeedlyImagePicker _picker =
      widget.imagePicker ?? GallerySeedlyImagePicker();
  var _autovalidate = AutovalidateMode.disabled;
  bool _busy = false;

  /// Its own subscription to the tasks: a stream handed over by the detail
  /// would give nothing to a second listener until the next change.
  late final Stream<List<SeedlyTask>> _tasks = widget.projects.watchTasks(
    widget.project.id,
  );

  bool get _datesInverted =>
      _start != null && _end != null && _end!.isBefore(_start!);

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  static String? _nameError(String? value) =>
      (value?.trim().isEmpty ?? true) ? 'Ingresa el nombre del proyecto' : null;

  Future<void> _pickAvatar() async {
    final choice = await showSeedlyIconModal(
      context,
      picker: _picker,
      selected: _photo == null ? _icon : null,
    );
    if (choice == null || !mounted) return;
    setState(() {
      switch (choice) {
        case SeedlyIconChoice(:final icon):
          _icon = icon;
          _photo = null;
        case SeedlyPhotoChoice(:final photo):
          _photo = photo;
      }
    });
  }

  Future<void> _pickStart() async {
    final day = await showSeedlyDateModal(
      context,
      initial: _start,
      today: widget.today,
    );
    if (day == null || !mounted) return;
    setState(() {
      _start = day;
      if (_end != null && _end!.isBefore(day)) _end = null;
    });
  }

  Future<void> _pickEnd() async {
    final day = await showSeedlyDateModal(
      context,
      initial: _end,
      firstDate: _start,
      today: widget.today,
    );
    if (day != null && mounted) setState(() => _end = day);
  }

  Future<void> _submit() async {
    if (_busy) return;
    final valid = _formKey.currentState!.validate();
    if (!valid || _datesInverted) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      showSeedlyAlert(
        context,
        style: SeedlyAlertStyle.danger,
        title: 'Campos incompletos',
        message: [
          _nameError(_name.text),
          if (_datesInverted) 'La fecha de fin no puede ser antes del inicio',
        ].nonNulls.join('\n'),
      );
      return;
    }
    final description = _description.text.trim();
    hideSeedlyAlert();
    setState(() => _busy = true);
    try {
      await widget.projects.updateProject(
        widget.project.id,
        SeedlyProjectChanges(
          name: _name.text.trim(),
          description: description.isEmpty ? null : description,
          icon: _icon,
          photo: _photo,
          startDate: _start,
          endDate: _end,
        ),
      );
      if (mounted) widget.onSaved();
    } on SeedlyProjectException catch (error) {
      if (!mounted) return;
      showSeedlyAlert(
        context,
        style: SeedlyAlertStyle.danger,
        title: 'No se pudo guardar el proyecto',
        message: error.message,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// "Tareas" with "Añadir tarea" and the task cards; Figma shows them as
  /// the detail does, each with its three-dot menu.
  Widget _tasksSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 12,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Tareas',
            style: TextStyle(
              fontSize: 16,
              height: 24 / 16,
              fontWeight: FontWeight.w500,
              color: SeedlyPalette.neutral[850],
            ),
          ),
          SeedlyButton(
            label: 'Añadir tarea',
            variant: SeedlyButtonVariant.text,
            size: SeedlyButtonSize.small,
            leading: SvgPicture.asset(
              'assets/images/icon_plus.svg',
              width: 16,
              height: 16,
              colorFilter: ColorFilter.mode(
                SeedlyPalette.primary[500]!,
                BlendMode.srcIn,
              ),
            ),
            onPressed: widget.onAddTask,
          ),
        ],
      ),
      StreamBuilder<List<SeedlyTask>>(
        stream: _tasks,
        builder: (context, snapshot) {
          final tasks = snapshot.data;
          if (tasks == null || tasks.isEmpty) {
            return Text(
              tasks == null
                  ? 'Cargando tareas…'
                  : 'Este proyecto aún no tiene tareas.',
            );
          }
          return Column(
            spacing: 16,
            children: [
              for (final task in tasks)
                SeedlyCheckboxCard(
                  key: ValueKey(task.id),
                  label: task.title,
                  value: task.done,
                  onChanged: (done) => widget.onToggleTask(task, done),
                  time: task.dueMinutes == null
                      ? null
                      : SeedlyDates.time(task.dueMinutes!),
                  actions: [
                    SeedlyCardAction('Editar', () => widget.onEditTask(task)),
                    SeedlyCardAction(
                      'Eliminar',
                      () => widget.onDeleteTask(task),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    // Figma's 48px top padding stands in for the status bar, as in Inicio.
    final top = math.max(24.0, 48 - MediaQuery.paddingOf(context).top);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onClose();
      },
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(32, top, 32, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SeedlyHeader(
                title: 'Editar proyecto',
                onBack: widget.onClose,
                action: SeedlyHeaderAction(
                  asset: 'assets/images/icon_trash.svg',
                  tooltip: 'Eliminar proyecto',
                  color: SeedlyPalette.neutral[850],
                  onPressed: widget.onDelete,
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: _autovalidate,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 24,
                      children: [
                        Center(
                          child: SeedlyAvatar(
                            icon: _icon.asset,
                            photo: _photo,
                            onEdit: _pickAvatar,
                          ),
                        ),
                        SeedlyInput(
                          label: 'Nombre del proyecto *',
                          hint: 'Ej. Rediseño de la app',
                          controller: _name,
                          validator: _nameError,
                          maxLength: 80,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.next,
                        ),
                        SeedlyInput(
                          label: 'Descripción',
                          hint: 'Añade algunos detalles sobre tu proyecto',
                          controller: _description,
                          minLines: 3,
                          maxLines: 5,
                          maxLength: 500,
                          textCapitalization: TextCapitalization.sentences,
                          keyboardType: TextInputType.multiline,
                        ),
                        Row(
                          spacing: 16,
                          children: [
                            Expanded(
                              child: SeedlyInputButton(
                                helper: 'INICIO',
                                placeholder: 'Añadir fecha',
                                value: _start == null
                                    ? null
                                    : SeedlyDates.short(_start!),
                                onTap: _pickStart,
                              ),
                            ),
                            Expanded(
                              child: SeedlyInputButton(
                                helper: 'FIN',
                                placeholder: 'Añadir fecha',
                                value: _end == null
                                    ? null
                                    : SeedlyDates.short(_end!),
                                error: _datesInverted,
                                onTap: _pickEnd,
                              ),
                            ),
                          ],
                        ),
                        _tasksSection(),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SeedlyButton(
                label: _busy ? 'Guardando…' : 'Guardar cambios',
                expand: true,
                leading: SvgPicture.asset(
                  'assets/images/icon_save.svg',
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
                onPressed: _busy ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
