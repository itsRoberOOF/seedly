import 'package:flutter/material.dart';

import '../models/seedly_drops.dart';
import '../models/seedly_errors.dart';
import '../repositories/seedly_auth_repository.dart';
import '../repositories/seedly_drops_repository.dart';

/// Debug-only panel to try the drops system before its real screens exist.
/// main.dart opens it instead of the app with --dart-define=DROPS_PANEL=true.
class SeedlyDropsDebugView extends StatefulWidget {
  const SeedlyDropsDebugView({
    super.key,
    required this.auth,
    required this.drops,
    required this.app,
  });

  final SeedlyAuthRepository auth;
  final SeedlyDropsRepository drops;

  /// The real app, opened on top to create projects and tasks to pay.
  final Widget app;

  @override
  State<SeedlyDropsDebugView> createState() => _SeedlyDropsDebugViewState();
}

class _SeedlyDropsDebugViewState extends State<SeedlyDropsDebugView> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _id = TextEditingController();
  final _minutes = TextEditingController(text: '1');

  /// Created once, after signing in, so rebuilds don't resubscribe.
  late final _plant = widget.drops.watchPlantState();

  String? _sessionId;
  String _result = '';

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _id.dispose();
    _minutes.dispose();
    super.dispose();
  }

  /// Runs [action] and shows what it returned, or why it failed.
  Future<void> _run(String label, Future<Object?> Function() action) async {
    String result;
    try {
      result = '${await action() ?? 'listo'}';
    } on SeedlyDropsException catch (error) {
      result = error.message;
    } on SeedlyAuthException catch (error) {
      result = error.message;
    }
    if (mounted) setState(() => _result = '$label: $result');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panel de gotas (debug)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.auth.isSignedIn) ..._panel() else ..._signIn(),
          const SizedBox(height: 16),
          Text(_result),
        ],
      ),
    );
  }

  List<Widget> _signIn() => [
    TextField(
      controller: _email,
      decoration: const InputDecoration(labelText: 'Correo'),
    ),
    TextField(
      controller: _password,
      obscureText: true,
      decoration: const InputDecoration(labelText: 'Contraseña'),
    ),
    const SizedBox(height: 16),
    FilledButton(
      onPressed: () => _run(
        'Iniciar sesión',
        () => widget.auth.signInWithEmail(
          email: _email.text.trim(),
          password: _password.text,
        ),
      ),
      child: const Text('Iniciar sesión'),
    ),
  ];

  List<Widget> _panel() => [
    StreamBuilder<SeedlyPlantState>(
      stream: _plant,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Text('Error: ${snapshot.error}');
        final plant = snapshot.data;
        if (plant == null) return const Text('Cargando…');
        return Text(
          'Fase ${plant.phase} · ${plant.totalDrops} gotas · '
          'meta ${plant.nextGoal ?? '—'}',
        );
      },
    ),
    const SizedBox(height: 16),
    TextField(
      key: const Key('drops-id'),
      controller: _id,
      decoration: const InputDecoration(labelText: 'Id de tarea o proyecto'),
    ),
    Wrap(
      spacing: 8,
      children: [
        OutlinedButton(
          onPressed: () => _run(
            'Pagar tarea',
            () => widget.drops.addTaskDrops(_id.text.trim()),
          ),
          child: const Text('Pagar tarea'),
        ),
        OutlinedButton(
          onPressed: () => _run(
            'Quitar tarea',
            () => widget.drops.removeTaskDrops(_id.text.trim()),
          ),
          child: const Text('Quitar tarea'),
        ),
        OutlinedButton(
          onPressed: () => _run(
            'Pagar proyecto',
            () => widget.drops.addProjectDrops(_id.text.trim()),
          ),
          child: const Text('Pagar proyecto'),
        ),
      ],
    ),
    const Divider(height: 32),
    OutlinedButton(
      onPressed: () => _run('Iniciar riego', () async {
        final id = await widget.drops.startWateringSession();
        setState(() => _sessionId = id);
        return id;
      }),
      child: const Text('Iniciar riego'),
    ),
    Text('Sesión: ${_sessionId ?? '—'}'),
    TextField(
      controller: _minutes,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(labelText: 'Minutos'),
    ),
    OutlinedButton(
      onPressed: _sessionId == null
          ? null
          : () => _run(
              'Pagar riego',
              () => widget.drops.payWateringSession(
                _sessionId!,
                int.tryParse(_minutes.text) ?? 0,
              ),
            ),
      child: const Text('Pagar riego'),
    ),
    const Divider(height: 32),
    FilledButton(
      onPressed: () => _run('Crecer', widget.drops.growPlant),
      child: const Text('Crecer'),
    ),
    const SizedBox(height: 8),
    TextButton(
      onPressed: () =>
          Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => widget.app)),
      child: const Text('Ir a la app (F5 vuelve aquí)'),
    ),
  ];
}
