import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';

import '../modals/seedly_add_modal.dart';
import '../models/seedly_errors.dart';
import '../models/seedly_project.dart';
import '../models/seedly_drops.dart';
import '../repositories/seedly_auth_repository.dart';
import '../repositories/seedly_drops_repository.dart';
import '../repositories/seedly_project_repository.dart';
import '../repositories/seedly_user_repository.dart';
import '../services/seedly_image_picker.dart';
import '../services/seedly_notification_service.dart';
import '../services/seedly_task_reminder_coordinator.dart';
import '../theme/seedly_theme.dart';
import '../utils/seedly_dates.dart';
import '../widgets/seedly_alert.dart';
import '../widgets/seedly_checkbox.dart';
import '../widgets/seedly_menu.dart';
import '../widgets/seedly_plant.dart';
import 'seedly_create_project_view.dart';
import 'seedly_login_screen.dart';
import 'seedly_profile_view.dart';

/// Signed-in shell: the bottom menu switches the active tab. Inicio combines
/// the task feed with the reusable plant widget; the add button's project
/// forms open over the current tab, menu included.
class SeedlyHomeScreen extends StatefulWidget {
  const SeedlyHomeScreen({
    super.key,
    required this.auth,
    required this.projects,
    required this.users,
    this.imagePicker,
    this.notifications,
    this.drops,
    this.onNotificationTaskTap,
  });

  final SeedlyAuthRepository auth;
  final SeedlyProjectRepository projects;
  final SeedlyUserRepository users;

  /// Replaced in tests so they never open the system gallery.
  final SeedlyImagePicker? imagePicker;

  /// Shared native notification service; omitted in isolated widget tests.
  final SeedlyNotificationService? notifications;

  /// Persona 4's plant state; omitted by isolated screens that only need UI.
  final SeedlyDropsRepository? drops;

  /// Hook for Persona 1's future task editor when a reminder is tapped.
  final void Function(String taskId)? onNotificationTaskTap;

  @override
  State<SeedlyHomeScreen> createState() => _SeedlyHomeScreenState();
}

class _SeedlyHomeScreenState extends State<SeedlyHomeScreen> {
  late final SeedlyImagePicker _picker =
      widget.imagePicker ?? GallerySeedlyImagePicker();
  var _active = SeedlyMenuTab.inicio;
  bool _signingOut = false;

  /// The project form being filled in, if any.
  SeedlyProjectKind? _creating;

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await widget.auth.signOut();
      await widget.notifications?.cancelAllTaskReminders();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => SeedlyLoginScreen(
            auth: widget.auth,
            projects: widget.projects,
            users: widget.users,
            notifications: widget.notifications,
          ),
        ),
        (_) => false,
      );
    } on SeedlyAuthException catch (error) {
      if (!mounted) return;
      showSeedlyAlert(
        context,
        style: SeedlyAlertStyle.danger,
        title: 'No se pudo cerrar sesión',
        message: error.message,
      );
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  Future<void> _add() async {
    final option = await showSeedlyAddModal(context);
    if (option == null || !mounted) return;
    switch (option) {
      case SeedlyAddOption.fullProject:
        setState(() => _creating = SeedlyProjectKind.full);
      case SeedlyAddOption.expressProject:
        setState(() => _creating = SeedlyProjectKind.express);
      case SeedlyAddOption.task:
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('${option.title} aún no disponible')),
          );
    }
  }

  void _closeForm() {
    hideSeedlyAlert();
    setState(() => _creating = null);
  }

  void _created(NewSeedlyProject project, SeedlyProjectSave save) {
    setState(() => _creating = null);
    showSeedlyAlert(
      context,
      style: SeedlyAlertStyle.success,
      title: 'Proyecto creado',
      message: switch (save) {
        SeedlyProjectSave.saved =>
          '«${project.name}» ya está en tus proyectos.',
        SeedlyProjectSave.pendingSync =>
          '«${project.name}» se guardará cuando vuelva la conexión.',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final creating = _creating;
    // An open form handles the system back button itself, closing before
    // the app does.
    return Scaffold(
      backgroundColor: SeedlyPalette.neutral[100],
      body: creating != null
          ? SeedlyCreateProjectView(
              // A new key per variant opened from the modal starts a fresh
              // form.
              key: ValueKey(creating),
              projects: widget.projects,
              imagePicker: _picker,
              initialKind: creating,
              onClose: _closeForm,
              onCreated: _created,
              onReminderSelected: widget.notifications == null
                  ? null
                  : _requestReminderPermission,
            )
          : _active == SeedlyMenuTab.perfil
          ? SeedlyProfileView(
              profile: widget.auth.currentUser,
              auth: widget.auth,
              users: widget.users,
              picker: _picker,
              onSignOut: _signOut,
            )
          : _active == SeedlyMenuTab.inicio
          ? _InicioView(
              projects: widget.projects,
              drops: widget.drops,
              notifications: widget.notifications,
              onNotificationTaskTap: widget.onNotificationTaskTap,
            )
          : null,
      bottomNavigationBar: SeedlyMenu(
        active: _active,
        onSelected: (tab) {
          if (_creating != null) _closeForm();
          setState(() => _active = tab);
        },
        onAdd: _add,
      ),
    );
  }

  Future<bool> _requestReminderPermission() async {
    final permission = await widget.notifications!.requestReminderPermission();
    return permission == SeedlyNotificationPermission.granted;
  }
}

/// Figma "Inicio", for now only the plant, where Figma puts it: below the
/// header's 56px and the 24px gap, 14px into the "Planta" frame. The header
/// and the rest of the screen come later.
class _InicioView extends StatefulWidget {
  const _InicioView({
    required this.projects,
    this.drops,
    this.notifications,
    this.onNotificationTaskTap,
  });

  final SeedlyProjectRepository projects;
  final SeedlyDropsRepository? drops;
  final SeedlyNotificationService? notifications;
  final void Function(String taskId)? onNotificationTaskTap;

  @override
  State<_InicioView> createState() => _InicioViewState();
}

class _InicioViewState extends State<_InicioView> {
  late final _today = SeedlyDates.day(DateTime.now());
  late final _todayTasks = widget.projects.watchTasksOn(_today);
  late final _futureTasks = widget.projects.watchTasksFrom(_today);
  late final Stream<SeedlyPlantState>? _plantState = widget.drops
      ?.watchPlantState();
  SeedlyTaskReminderCoordinator? _coordinator;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeNotifications());
  }

  Future<void> _initializeNotifications() async {
    final notifications = widget.notifications;
    if (notifications == null) return;
    await notifications.initialize(onTaskReminderTap: _onTaskReminderTap);
    if (!mounted) return;
    final coordinator = SeedlyTaskReminderCoordinator(
      tasks: _futureTasks,
      notifications: notifications,
    );
    _coordinator = coordinator;
    await coordinator.start();
  }

  void _onTaskReminderTap(String taskId) {
    if (mounted) widget.onNotificationTaskTap?.call(taskId);
  }

  @override
  void dispose() {
    final coordinator = _coordinator;
    if (coordinator != null) unawaited(coordinator.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = SeedlyMetrics.spacing;
    // Figma's 48px top padding stands in for the status bar, as in Mi perfil.
    final top = math.max(
      spacing['xl']!,
      48 - MediaQuery.paddingOf(context).top,
    );
    final plant = _plantState == null
        ? _homeContent(
            context,
            top,
            spacing,
            const SeedlyPlantState(phase: 1, totalDrops: 0),
          )
        : StreamBuilder<SeedlyPlantState>(
            stream: _plantState,
            builder: (context, snapshot) => _homeContent(
              context,
              top,
              spacing,
              snapshot.data ?? const SeedlyPlantState(phase: 1, totalDrops: 0),
            ),
          );
    return plant;
  }

  Widget _homeContent(
    BuildContext context,
    double top,
    Map<String, double> spacing,
    SeedlyPlantState plant,
  ) => SafeArea(
    bottom: false,
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        top + 56 + spacing['xl']! + 14,
        24,
        spacing['xl']!,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: SizedBox(
              height: 303,
              child: SeedlyPlant(phase: plant.phase),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Gotas: ${plant.totalDrops}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),
          Text(
            'Tareas de hoy',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<SeedlyTask>>(
            stream: _todayTasks,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text('No se pudieron cargar tus tareas.');
              }
              if (!snapshot.hasData) {
                return const Text('Cargando tareas…');
              }
              final tasks = snapshot.data!
                  .where(
                    (task) =>
                        task.dueDate != null &&
                        SeedlyDates.sameDay(task.dueDate!, _today),
                  )
                  .toList();
              if (tasks.isEmpty) {
                return const Text('No tienes tareas para hoy.');
              }
              return Column(
                spacing: 8,
                children: [
                  for (final task in tasks)
                    SeedlyCheckboxCard(
                      label: task.title,
                      value: task.done,
                      onChanged: null,
                      time: task.dueMinutes == null
                          ? null
                          : SeedlyDates.time(task.dueMinutes!),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}
