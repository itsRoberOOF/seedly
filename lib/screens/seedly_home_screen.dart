import 'dart:async';

import 'package:flutter/material.dart';

import '../modals/seedly_add_modal.dart';
import '../models/seedly_errors.dart';
import '../models/seedly_project.dart';
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
import '../widgets/seedly_busy_overlay.dart';
import '../widgets/seedly_menu.dart';
import 'seedly_create_project_view.dart';
import 'seedly_inicio_view.dart';
import 'seedly_login_screen.dart';
import 'seedly_profile_view.dart';

/// Signed-in shell: the bottom menu switches the active tab. Inicio combines
/// the greeting, plant and task feed; the add button's project
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

  /// Hook for Persona 1's future task editor when a reminder or a task card
  /// is tapped.
  final void Function(String taskId)? onNotificationTaskTap;

  @override
  State<SeedlyHomeScreen> createState() => _SeedlyHomeScreenState();
}

class _SeedlyHomeScreenState extends State<SeedlyHomeScreen> {
  late final SeedlyImagePicker _picker =
      widget.imagePicker ?? GallerySeedlyImagePicker();
  var _active = SeedlyMenuTab.inicio;
  bool _signingOut = false;

  /// Mi perfil has started leaving: saving what was typed, then signing out.
  bool _profileLeaving = false;
  late final _today = SeedlyDates.day(DateTime.now());
  late final _futureTasks = widget.projects.watchTasksFrom(_today);
  SeedlyTaskReminderCoordinator? _coordinator;

  /// The project form being filled in, if any.
  SeedlyProjectKind? _creating;

  @override
  void initState() {
    super.initState();
    unawaited(_startReminderCoordinator());
  }

  Future<void> _startReminderCoordinator() async {
    final notifications = widget.notifications;
    if (notifications == null || _signingOut || _coordinator != null) return;
    await notifications.initialize(onTaskReminderTap: _onNotificationTaskTap);
    if (!mounted || _signingOut || _coordinator != null) return;
    final coordinator = SeedlyTaskReminderCoordinator(
      tasks: _futureTasks,
      notifications: notifications,
    );
    _coordinator = coordinator;
    await coordinator.start();
  }

  Future<void> _stopReminderCoordinator() async {
    final coordinator = _coordinator;
    _coordinator = null;
    await coordinator?.dispose();
  }

  void _onNotificationTaskTap(String taskId) {
    if (mounted) widget.onNotificationTaskTap?.call(taskId);
  }

  @override
  void dispose() {
    unawaited(_stopReminderCoordinator());
    super.dispose();
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    // Mark the coordinator disposed before leaving the signed-in shell. Its
    // subscription cancellation can finish asynchronously, but it cannot
    // reconcile another snapshot after this point.
    unawaited(_stopReminderCoordinator());
    var signedOut = false;
    try {
      await widget.auth.signOut();
      signedOut = true;
      try {
        await widget.notifications?.cancelAllTaskReminders();
      } on Object {
        // Authentication has already succeeded; notification cleanup must not
        // strand the signed-out user on the Home screen.
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => SeedlyLoginScreen(
            auth: widget.auth,
            projects: widget.projects,
            users: widget.users,
            drops: widget.drops,
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
      if (mounted) {
        setState(() => _signingOut = false);
        if (!signedOut) unawaited(_startReminderCoordinator());
      }
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
    final leaving = _signingOut || _profileLeaving;
    // An open form handles the system back button itself, closing before
    // the app does. While leaving, nothing may be touched: not the screen,
    // not the menu, not back.
    return PopScope(
      canPop: !leaving,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _scaffold(creating),
          if (leaving) const SeedlyBusyOverlay(label: 'Cerrando sesión…'),
        ],
      ),
    );
  }

  Widget _scaffold(SeedlyProjectKind? creating) {
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
              onLeavingChanged: (leaving) {
                if (mounted) setState(() => _profileLeaving = leaving);
              },
            )
          : _active == SeedlyMenuTab.inicio
          ? SeedlyInicioView(
              projects: widget.projects,
              profile: widget.auth.currentUser,
              drops: widget.drops,
              onTaskTap: widget.onNotificationTaskTap,
              onWater: () => setState(() => _active = SeedlyMenuTab.riego),
              onSeeProjects: () =>
                  setState(() => _active = SeedlyMenuTab.proyectos),
              onAdd: _add,
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
