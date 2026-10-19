import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../modals/seedly_date_modal.dart';
import '../modals/seedly_icon_modal.dart';
import '../models/seedly_errors.dart';
import '../models/seedly_project.dart';
import '../services/seedly_image_picker.dart';
import 'seedly_create_task_view.dart';
import '../services/seedly_projects.dart';
import '../theme/seedly_theme.dart';
import '../utils/seedly_dates.dart';
import '../widgets/seedly_alert.dart';
import '../widgets/seedly_avatar.dart';
import '../widgets/seedly_button.dart';
import '../widgets/seedly_checkbox.dart';
import '../widgets/seedly_header.dart';
import '../widgets/seedly_input.dart';
import '../widgets/seedly_input_button.dart';
import '../widgets/seedly_segmented_control.dart';
import '../widgets/seedly_task_field.dart';

/// Figma "Crear Proyecto" in its Express and Completo variants. Both share
/// one form: Express only shows its essentials, so switching keeps
/// everything typed. Shown inside the home so the menu stays visible.
class SeedlyCreateProjectView extends StatefulWidget {
  const SeedlyCreateProjectView({
    super.key,
    required this.projects,
    required this.onClose,
    required this.onCreated,
    this.initialKind = SeedlyProjectKind.full,
    this.today,
    this.imagePicker,
  });

  final SeedlyProjects projects;

  /// Defaults to the device gallery; tests pass a fake.
  final SeedlyImagePicker? imagePicker;
  final VoidCallback onClose;

  /// Called with the saved project once [SeedlyProjects.create] succeeds.
  final void Function(NewSeedlyProject project, SeedlyProjectSave save)
  onCreated;
  final SeedlyProjectKind initialKind;

  /// Defaults to the current day; tests pin it.
  final DateTime? today;

  @override
  State<SeedlyCreateProjectView> createState() =>
      _SeedlyCreateProjectViewState();
}

class _SeedlyCreateProjectViewState extends State<SeedlyCreateProjectView> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();

  /// Both variants share this list; Express needs at least one task and
  /// starts with an empty row to type it in.
  late final _tasks = [
    if (widget.initialKind == SeedlyProjectKind.express) _TaskDraft(),
  ];
  late var _kind = widget.initialKind;

  /// "Nueva tarea" open over the form, for a new task or the one at
  /// [_TaskEditor.index].
  _TaskEditor? _editor;
  var _icon = SeedlyProjectIcon.planta;

  /// A gallery photo shown over [_icon]; picking an icon clears it.
  Uint8List? _photo;
  late final SeedlyImagePicker _picker =
      widget.imagePicker ?? GallerySeedlyImagePicker();
  DateTime? _start;
  DateTime? _end;
  var _autovalidate = AutovalidateMode.disabled;
  bool _busy = false;

  bool get _full => _kind == SeedlyProjectKind.full;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    for (final task in _tasks) {
      task.text.dispose();
    }
    super.dispose();
  }

  static String? _nameError(String? value) =>
      (value?.trim().isEmpty ?? true) ? 'Ingresa el nombre del proyecto' : null;

  bool get _hasTask => _tasks.any((task) => task.text.text.trim().isNotEmpty);

  /// Express needs a task; the message and red border go on the first row.
  String? _missingTaskError([String? _]) =>
      !_full && !_hasTask ? 'Añade al menos una tarea' : null;

  bool get _datesInverted =>
      _full && _start != null && _end != null && _end!.isBefore(_start!);

  Future<void> _pickAvatar() async {
    final choice = await showSeedlyIconModal(
      context,
      picker: _picker,
      // No icon is highlighted while a photo is showing.
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
      // A start after the end makes that end meaningless.
      if (_end != null && _end!.isBefore(day)) _end = null;
    });
  }

  Future<void> _pickEnd() async {
    final day = await showSeedlyDateModal(
      context,
      initial: _end,
      firstDate: _full ? _start : null,
      today: widget.today,
    );
    if (day != null && mounted) setState(() => _end = day);
  }

  void _addTask() => setState(() => _tasks.add(_TaskDraft()));

  void _removeTask(int index) =>
      setState(() => _tasks.removeAt(index).text.dispose());

  /// Completo lists tasks as cards, so empty Express rows are dropped;
  /// Express types tasks in rows, so it always has at least one.
  void _setKind(SeedlyProjectKind kind) => setState(() {
    _kind = kind;
    if (_full) {
      for (final task in _tasks.where((task) => task.isEmpty).toList()) {
        _tasks.remove(task);
        task.text.dispose();
      }
    } else if (_tasks.isEmpty) {
      _tasks.add(_TaskDraft());
    }
  });

  void _openTaskEditor([int? index]) {
    hideSeedlyAlert();
    setState(() => _editor = _TaskEditor(index));
  }

  void _closeTaskEditor() => setState(() => _editor = null);

  void _saveTask(NewSeedlyTask task) => setState(() {
    final index = _editor?.index;
    if (index == null) {
      _tasks.add(_TaskDraft.from(task));
    } else {
      _tasks[index].update(task);
    }
    _editor = null;
  });

  Future<void> _submit() async {
    if (_busy) return;
    final errors = [
      _nameError(_name.text),
      _missingTaskError(),
      if (_datesInverted) 'La fecha de fin no puede ser antes del inicio',
    ].nonNulls.toList();
    // validate() turns the invalid fields' borders red; the messages are
    // gathered into one alert, as in the login.
    final valid = _formKey.currentState!.validate();
    if (!valid || errors.isNotEmpty) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      showSeedlyAlert(
        context,
        style: SeedlyAlertStyle.danger,
        title: 'Campos incompletos',
        message: errors.join('\n'),
      );
      return;
    }
    // Only what the current variant shows is saved.
    final description = _description.text.trim();
    final project = NewSeedlyProject(
      name: _name.text.trim(),
      kind: _kind,
      icon: _icon,
      photo: _photo,
      description: _full && description.isNotEmpty ? description : null,
      startDate: _full ? _start : null,
      endDate: _end,
      tasks: [
        for (final task in _tasks)
          if (!task.isEmpty) task.toTask(),
      ],
    );
    hideSeedlyAlert();
    setState(() => _busy = true);
    try {
      final save = await widget.projects.create(project);
      if (mounted) widget.onCreated(project, save);
    } on SeedlyProjectException catch (error) {
      if (!mounted) return;
      showSeedlyAlert(
        context,
        style: SeedlyAlertStyle.danger,
        title: 'No se pudo crear el proyecto',
        message: error.message,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editor = _editor;
    // The system back button closes "Nueva tarea" first, then this form.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_editor != null) {
          _closeTaskEditor();
        } else {
          widget.onClose();
        }
      },
      child: editor == null
          ? _projectForm(context)
          : SeedlyCreateTaskView(
              // A fresh form each time it opens.
              key: ObjectKey(editor),
              projectName: _name.text,
              projectIcon: _icon.asset,
              projectPhoto: _photo,
              initial: editor.index == null
                  ? null
                  : _tasks[editor.index!].toTask(),
              today: widget.today,
              onClose: _closeTaskEditor,
              onSave: _saveTask,
            ),
    );
  }

  Widget _projectForm(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SeedlyHeader(title: 'Nuevo proyecto', onBack: widget.onClose),
            const SizedBox(height: 32),
            SeedlySegmentedControl<SeedlyProjectKind>(
              options: const [
                (SeedlyProjectKind.express, 'Express'),
                (SeedlyProjectKind.full, 'Completo'),
              ],
              selected: _kind,
              onChanged: _setKind,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                // Room for the cards' shadows at the scroll edges.
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
                      if (_full)
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
                      if (_full) _dateRange() else _dueDate(),
                      _taskList(),
                      SeedlyButton(
                        label: _full
                            ? 'Mostrar menos opciones'
                            : 'Mostrar más opciones',
                        variant: SeedlyButtonVariant.text,
                        size: SeedlyButtonSize.small,
                        foreground: SeedlyPalette.neutral[600],
                        trailing: Transform.flip(
                          flipY: _full,
                          child: SvgPicture.asset(
                            'assets/images/icon_nav_down.svg',
                            width: 20,
                            height: 20,
                          ),
                        ),
                        onPressed: () => _setKind(
                          _full
                              ? SeedlyProjectKind.express
                              : SeedlyProjectKind.full,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SeedlyButton(
              label: _busy ? 'Creando proyecto…' : 'Crear proyecto',
              expand: true,
              leading: SvgPicture.asset(
                'assets/images/icon_plus.svg',
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
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w500,
      color: SeedlyPalette.neutral[850],
    ),
  );

  Widget _dateRange() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 8,
    children: [
      _sectionLabel('Fechas'),
      Row(
        spacing: 16,
        children: [
          Expanded(
            child: SeedlyInputButton(
              helper: 'INICIO',
              placeholder: 'Añadir fecha',
              value: _start == null ? null : SeedlyDates.short(_start!),
              onTap: _pickStart,
            ),
          ),
          Expanded(
            child: SeedlyInputButton(
              helper: 'FIN',
              placeholder: 'Añadir fecha',
              value: _end == null ? null : SeedlyDates.short(_end!),
              error: _datesInverted,
              onTap: _pickEnd,
            ),
          ),
        ],
      ),
    ],
  );

  Widget _dueDate() => SeedlyInputButton(
    label: 'Fecha',
    placeholder: '¿Cuándo quieres terminar?',
    value: _end == null ? null : SeedlyDates.short(_end!),
    onTap: _pickEnd,
  );

  Widget _taskList() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 8,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _sectionLabel(_full ? 'Tareas' : 'Tareas *'),
          SeedlyButton(
            label: 'Añadir tarea',
            variant: SeedlyButtonVariant.text,
            size: SeedlyButtonSize.small,
            leading: SvgPicture.asset(
              'assets/images/icon_plus.svg',
              width: 20,
              height: 20,
            ),
            // Completo creates each task in "Nueva tarea"; Express adds a row.
            onPressed: _full ? _openTaskEditor : _addTask,
          ),
        ],
      ),
      if (!_full)
        for (var index = 0; index < _tasks.length; index++) _taskField(index)
      else if (_tasks.isEmpty)
        _EmptyTaskCard(onTap: _openTaskEditor)
      else
        for (var index = 0; index < _tasks.length; index++) _taskCard(index),
    ],
  );

  Widget _taskCard(int index) {
    final task = _tasks[index];
    return SeedlyCheckboxCard(
      key: ObjectKey(task),
      label: task.text.text.trim(),
      value: task.done,
      time: task.when,
      onChanged: (done) => setState(() => task.done = done),
      actions: [
        SeedlyCardAction('Editar', () => _openTaskEditor(index)),
        SeedlyCardAction('Quitar', () => _removeTask(index)),
      ],
    );
  }

  Widget _taskField(int index) {
    final task = _tasks[index];
    return SeedlyTaskField(
      // Keys follow the draft so removing a row keeps the others' text,
      // state and focus in place.
      key: ObjectKey(task),
      controller: task.text,
      done: task.done,
      onDoneChanged: (done) => setState(() => task.done = done),
      validator: index == 0 ? _missingTaskError : null,
      autofocus: index > 0 && index == _tasks.length - 1,
      onRemove: _tasks.length > 1 ? () => _removeTask(index) : null,
    );
  }
}

/// Which task "Nueva tarea" is open for; a fresh object per opening.
class _TaskEditor {
  _TaskEditor(this.index);

  /// Null for a new task.
  final int? index;
}

/// A task in the form: its title (typed in place in Express), whether it's
/// done, and the details set in "Nueva tarea".
class _TaskDraft {
  _TaskDraft();

  _TaskDraft.from(NewSeedlyTask task) {
    update(task);
  }

  final text = TextEditingController();
  bool done = false;
  DateTime? dueDate;
  int? dueMinutes;
  int? reminderMinutes;

  bool get isEmpty => text.text.trim().isEmpty;

  /// "13 oct 2026 · 9:00 AM", for the task's card.
  String? get when => dueDate == null
      ? null
      : [
          SeedlyDates.short(dueDate!),
          if (dueMinutes != null) SeedlyDates.time(dueMinutes!),
        ].join(' · ');

  void update(NewSeedlyTask task) {
    text.text = task.title;
    done = task.done;
    dueDate = task.dueDate;
    dueMinutes = task.dueMinutes;
    reminderMinutes = task.reminderMinutes;
  }

  NewSeedlyTask toTask() => NewSeedlyTask(
    text.text.trim(),
    done: done,
    dueDate: dueDate,
    dueMinutes: dueMinutes,
    reminderMinutes: reminderMinutes,
  );
}

/// Figma's placeholder task card in Completo: opens "Nueva tarea".
class _EmptyTaskCard extends StatelessWidget {
  const _EmptyTaskCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(SeedlyMetrics.radii['sm']!);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: SeedlyShadows.card,
      ),
      child: Material(
        color: SeedlyPalette.neutral[50],
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: SeedlyPalette.border),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              spacing: 12,
              children: [
                const SeedlyCheckboxBox(value: false, placeholder: true),
                Text(
                  '¿Cuál es la tarea?',
                  style: TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    color: SeedlyPalette.neutral[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
