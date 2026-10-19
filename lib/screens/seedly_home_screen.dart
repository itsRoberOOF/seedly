import 'package:flutter/material.dart';

import '../data/firebase/firestore_seedly_project_repository.dart';
import '../modals/seedly_add_modal.dart';
import '../models/seedly_errors.dart';
import '../models/seedly_project.dart';
import '../repositories/seedly_auth_repository.dart';
import '../repositories/seedly_project_repository.dart';
import '../theme/seedly_theme.dart';
import '../widgets/seedly_alert.dart';
import '../widgets/seedly_button.dart';
import '../widgets/seedly_menu.dart';
import 'seedly_create_project_view.dart';
import 'seedly_login_screen.dart';

/// Signed-in shell: the bottom menu switches the active tab. Every tab is
/// still an empty page except Mi perfil, which only offers signing out. The
/// add button's project forms open over the current tab, menu included.
class SeedlyHomeScreen extends StatefulWidget {
  const SeedlyHomeScreen({super.key, required this.auth, this.projects});

  final SeedlyAuthRepository auth;

  /// Defaults to Firestore; tests pass a fake.
  final SeedlyProjectRepository? projects;

  @override
  State<SeedlyHomeScreen> createState() => _SeedlyHomeScreenState();
}

class _SeedlyHomeScreenState extends State<SeedlyHomeScreen> {
  var _active = SeedlyMenuTab.inicio;
  bool _signingOut = false;

  /// The project form being filled in, if any.
  SeedlyProjectKind? _creating;

  late final SeedlyProjectRepository _projects =
      widget.projects ?? FirestoreSeedlyProjectRepository(auth: widget.auth);

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await widget.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => SeedlyLoginScreen(auth: widget.auth),
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
              projects: _projects,
              initialKind: creating,
              onClose: _closeForm,
              onCreated: _created,
            )
          : _active == SeedlyMenuTab.perfil
          ? Center(
              child: SeedlyButton(label: 'Cerrar sesión', onPressed: _signOut),
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
}
