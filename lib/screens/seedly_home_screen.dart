import 'package:flutter/material.dart';

import '../modals/seedly_add_modal.dart';
import '../services/seedly_auth.dart';
import '../theme/seedly_theme.dart';
import '../widgets/seedly_alert.dart';
import '../widgets/seedly_button.dart';
import '../widgets/seedly_menu.dart';
import 'seedly_login_screen.dart';

/// Signed-in shell: the bottom menu switches the active tab. Every tab is
/// still an empty page except Mi perfil, which only offers signing out.
class SeedlyHomeScreen extends StatefulWidget {
  const SeedlyHomeScreen({super.key, required this.auth});

  final SeedlyAuth auth;

  @override
  State<SeedlyHomeScreen> createState() => _SeedlyHomeScreenState();
}

class _SeedlyHomeScreenState extends State<SeedlyHomeScreen> {
  var _active = SeedlyMenuTab.inicio;
  bool _signingOut = false;

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
    // None of the creation flows exist yet.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('${option.title} aún no disponible')),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SeedlyPalette.neutral[100],
      body: _active == SeedlyMenuTab.perfil
          ? Center(
              child: SeedlyButton(label: 'Cerrar sesión', onPressed: _signOut),
            )
          : null,
      bottomNavigationBar: SeedlyMenu(
        active: _active,
        onSelected: (tab) => setState(() => _active = tab),
        onAdd: _add,
      ),
    );
  }
}
