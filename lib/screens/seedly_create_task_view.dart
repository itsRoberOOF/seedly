import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../modals/seedly_date_modal.dart';
import '../modals/seedly_time_modal.dart';
import '../models/seedly_project.dart';
import '../theme/seedly_theme.dart';
import '../utils/seedly_dates.dart';
import '../widgets/seedly_alert.dart';
import '../widgets/seedly_button.dart';
import '../widgets/seedly_header.dart';
import '../widgets/seedly_input_button.dart';
import '../widgets/seedly_input_tags.dart';

/// Figma "Crear- Tarea" in its Contraída and Extendida variants, for a task
/// of the project being created. The project is fixed: it hasn't been saved
/// yet. Editing an [initial] task keeps its done state.
class SeedlyCreateTaskView extends StatefulWidget {
  const SeedlyCreateTaskView({
    super.key,
    required this.projectName,
    required this.projectIcon,
    required this.onClose,
    required this.onSave,
    this.projectPhoto,
    this.initial,
    this.today,
    this.onReminderSelected,
    this.onPickProject,
  });

  /// The project the task belongs to. Empty only when [onPickProject] is
  /// set and none has been chosen yet.
  final String projectName;
  final String projectIcon;
  final Uint8List? projectPhoto;
  final NewSeedlyTask? initial;
  final VoidCallback onClose;
  final ValueChanged<NewSeedlyTask> onSave;

  /// Requests native notification permission after a reminder is selected.
  /// The task remains selected when permission is denied.
  final Future<bool> Function()? onReminderSelected;

  /// Defaults to the current day; tests pin it.
  final DateTime? today;

  /// Turns "Proyecto *" into a choice: tapping it asks the caller to pick a
  /// project, and saving without one is refused. Without it the project is
  /// fixed, as for the tasks of a project being created or edited.
  final VoidCallback? onPickProject;

  @override
  State<SeedlyCreateTaskView> createState() => _SeedlyCreateTaskViewState();
}

class _SeedlyCreateTaskViewState extends State<SeedlyCreateTaskView> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.initial?.title);
  late DateTime? _dueDate = widget.initial?.dueDate;
  late int? _dueMinutes = widget.initial?.dueMinutes;
  late int? _reminder = widget.initial?.reminderMinutes;

  /// Figma's Extendida variant, opened straight away when editing a task
  /// that already uses its options.
  late bool _expanded = _dueMinutes != null;
  var _autovalidate = AutovalidateMode.disabled;

  /// A save was refused for lack of a project; shows the red border until
  /// one is chosen.
  bool _projectMissing = false;

  bool get _needsProject =>
      widget.onPickProject != null && widget.projectName.trim().isEmpty;

  @override
  void didUpdateWidget(SeedlyCreateTaskView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_needsProject) _projectMissing = false;
  }

  DateTime get _today => SeedlyDates.day(widget.today ?? DateTime.now());

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  static String? _titleError(String? value) =>
      (value?.trim().isEmpty ?? true) ? 'Escribe la tarea' : null;

  void _setDueDate(DateTime? day) => setState(() {
    _dueDate = day;
    // Without a day, a time or a reminder means nothing.
    if (day == null) _dueMinutes = _reminder = null;
  });

  Future<void> _pickDate() async {
    final day = await showSeedlyDateModal(
      context,
      initial: _dueDate,
      today: _today,
    );
    if (day != null && mounted) _setDueDate(day);
  }

  Future<void> _pickTime() async {
    final minutes = await showSeedlyTimeModal(context, initial: _dueMinutes);
    if (minutes != null && mounted) setState(() => _dueMinutes = minutes);
  }

  Future<void> _selectReminder(int minutes) async {
    final removing = _reminder == minutes;
    setState(() => _reminder = removing ? null : minutes);
    if (removing || widget.onReminderSelected == null) return;
    final granted = await widget.onReminderSelected!();
    if (!mounted || granted) return;
    showSeedlyAlert(
      context,
      style: SeedlyAlertStyle.warning,
      title: 'Notificaciones desactivadas',
      message:
          'La tarea se guardará, pero no recibirá el recordatorio hasta '
          'permitir las notificaciones.',
    );
  }

  void _save() {
    final titleOk = _formKey.currentState!.validate();
    if (!titleOk || _needsProject) {
      setState(() {
        _autovalidate = AutovalidateMode.onUserInteraction;
        _projectMissing = _needsProject;
      });
      showSeedlyAlert(
        context,
        style: SeedlyAlertStyle.danger,
        title: 'Campos incompletos',
        message: [
          if (!titleOk) _titleError(_title.text)!,
          if (_needsProject) 'Elige un proyecto',
        ].join('\n'),
      );
      return;
    }
    hideSeedlyAlert();
    widget.onSave(
      NewSeedlyTask(
        _title.text.trim(),
        done: widget.initial?.done ?? false,
        dueDate: _dueDate,
        dueMinutes: _dueMinutes,
        reminderMinutes: _reminder,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SeedlyHeader(
              title: editing ? 'Editar tarea' : 'Nueva tarea',
              onBack: widget.onClose,
            ),
            const SizedBox(height: 40),
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
                      _titleField(editing),
                      _projectField(),
                      SeedlyInputTags(
                        label: 'Entrega',
                        placeholder: '¿Cuándo quieres terminar?',
                        value: _dueDate == null
                            ? null
                            : SeedlyDates.short(_dueDate!),
                        icon: 'assets/images/icon_calendar.svg',
                        onTap: _pickDate,
                        tags: [
                          for (final (label, day) in SeedlyDates.quickDates(
                            _today,
                          ))
                            SeedlyInputTag(
                              label: label,
                              selected:
                                  _dueDate != null &&
                                  SeedlyDates.sameDay(day, _dueDate!),
                              // Tapping the chosen day again clears it.
                              onTap: () => _setDueDate(
                                _dueDate != null &&
                                        SeedlyDates.sameDay(day, _dueDate!)
                                    ? null
                                    : day,
                              ),
                            ),
                        ],
                      ),
                      if (_expanded) ..._extendedFields(),
                      SeedlyButton(
                        label: _expanded
                            ? 'Mostrar menos opciones'
                            : 'Mostrar más opciones',
                        variant: SeedlyButtonVariant.text,
                        size: SeedlyButtonSize.small,
                        foreground: SeedlyPalette.neutral[600],
                        trailing: Transform.flip(
                          flipY: _expanded,
                          child: SvgPicture.asset(
                            'assets/images/icon_nav_down.svg',
                            width: 20,
                            height: 20,
                          ),
                        ),
                        onPressed: () => setState(() => _expanded = !_expanded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SeedlyButton(
              label: editing ? 'Guardar cambios' : 'Crear tarea',
              expand: true,
              leading: SvgPicture.asset(
                editing
                    ? 'assets/images/icon_save.svg'
                    : 'assets/images/icon_plus.svg',
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  /// Figma's big "Escribe tu tarea..." title, typed in place.
  Widget _titleField(bool editing) {
    const style = TextStyle(
      fontSize: 28,
      height: 34 / 28,
      fontWeight: FontWeight.w600,
    );
    return TextFormField(
      controller: _title,
      validator: _titleError,
      autofocus: !editing,
      maxLength: 200,
      maxLines: null,
      buildCounter: (
        _, {
        required currentLength,
        required isFocused,
        maxLength,
      }) => null,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.done,
      errorBuilder: (context, message) => const SizedBox.shrink(),
      style: style.copyWith(color: SeedlyPalette.neutral[850]),
      decoration: InputDecoration(
        hintText: 'Escribe tu tarea...',
        hintStyle: style.copyWith(color: SeedlyPalette.neutral[600]),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
        // The theme's input box (fill and borders) doesn't apply here.
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        // Borderless like Figma; a red line marks it when empty on save.
        errorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: SeedlyPalette.danger[600]!),
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: SeedlyPalette.danger[600]!, width: 1.5),
        ),
      ),
    );
  }

  /// "Proyecto *": the project being created, which can't be changed here.
  Widget _projectField() {
    final radius = BorderRadius.circular(SeedlyMetrics.radii['lg']!);
    final name = widget.projectName.trim();
    final pick = widget.onPickProject;
    final empty = name.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Text(
          'Proyecto *',
          style: TextStyle(
            fontSize: 16,
            height: 24 / 16,
            fontWeight: FontWeight.w500,
            color: SeedlyPalette.neutral[850],
          ),
        ),
        Semantics(
          button: pick != null,
          label: pick != null && empty
              ? 'Elegir proyecto'
              : 'Proyecto: ${empty ? 'sin nombre' : name}',
          excludeSemantics: true,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: SeedlyPalette.neutral[50],
              borderRadius: radius,
              border: Border.all(
                color: _projectMissing
                    ? SeedlyPalette.danger[600]!
                    : SeedlyPalette.border,
              ),
              boxShadow: SeedlyShadows.card,
            ),
            child: Material(
              type: MaterialType.transparency,
              borderRadius: radius,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: pick,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    spacing: 12,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: SeedlyPalette.primary[50],
                          shape: BoxShape.circle,
                        ),
                        child: widget.projectPhoto != null
                            ? Image.memory(
                                widget.projectPhoto!,
                                fit: BoxFit.cover,
                                width: 48,
                                height: 48,
                              )
                            : SvgPicture.asset(
                                widget.projectIcon,
                                width: 24,
                                height: 24,
                                colorFilter: ColorFilter.mode(
                                  SeedlyPalette.primary[600]!,
                                  BlendMode.srcIn,
                                ),
                              ),
                      ),
                      Expanded(
                        child: Text(
                          empty
                              ? (pick != null
                                    ? 'Elige un proyecto'
                                    : 'Proyecto sin nombre')
                              : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            height: 24 / 16,
                            color: empty
                                ? SeedlyPalette.neutral[600]
                                : SeedlyPalette.neutral[850],
                          ),
                        ),
                      ),
                      if (pick != null)
                        SvgPicture.asset(
                          'assets/images/icon_nav_down.svg',
                          width: 24,
                          height: 24,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _extendedFields() => [
    SeedlyInputButton(
      label: 'Hora límite',
      placeholder: _dueDate == null
          ? 'Elige primero la entrega'
          : '¿A qué hora?',
      value: _dueMinutes == null ? null : SeedlyDates.time(_dueMinutes!),
      icon: 'assets/images/icon_clock_large.svg',
      enabled: _dueDate != null,
      onTap: _pickTime,
    ),
    SeedlyInputTags(
      label: 'Recordatorio',
      placeholder: _dueMinutes == null
          ? 'Elige primero la hora'
          : 'Añadir recordatorio',
      value: _reminder == null ? null : SeedlyDates.reminder(_reminder!),
      icon: 'assets/images/icon_bell.svg',
      enabled: _dueMinutes != null,
      tags: [
        for (final minutes in seedlyReminderOptions)
          SeedlyInputTag(
            label: SeedlyDates.reminder(minutes),
            selected: _reminder == minutes,
            onTap: () => _selectReminder(minutes),
          ),
      ],
    ),
  ];
}
