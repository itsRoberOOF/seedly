import 'package:flutter/material.dart';

import '../models/seedly_drops.dart';
import '../models/seedly_errors.dart';
import '../models/seedly_project.dart';
import '../repositories/seedly_auth_repository.dart';
import '../repositories/seedly_drops_repository.dart';
import '../repositories/seedly_project_repository.dart';

/// Debug-only panel to try the drops system before its real screens exist,
/// and to fill Inicio with sample projects and tasks.
/// main.dart opens it instead of the app with --dart-define=DROPS_PANEL=true.
class SeedlyDropsDebugView extends StatefulWidget {
  const SeedlyDropsDebugView({
    super.key,
    required this.auth,
    required this.drops,
    required this.projects,
    required this.app,
  });

  final SeedlyAuthRepository auth;
  final SeedlyDropsRepository drops;
  final SeedlyProjectRepository projects;

  /// The real app, opened on top to create projects and tasks to pay.
  final Widget app;

  /// Two projects with tasks due today, some already done, so Inicio has a
  /// focus task, cards to scroll and rings at different points: 25% and 67%.
  static List<NewSeedlyProject> sampleProjects(DateTime today) {
    final day = DateTime(today.year, today.month, today.day);
    NewSeedlyTask task(String title, int hour, {bool done = false}) =>
        NewSeedlyTask(title, done: done, dueDate: day, dueMinutes: hour * 60);
    return [
      NewSeedlyProject(
        name: 'Prueba UI/UX',
        kind: SeedlyProjectKind.full,
        icon: SeedlyProjectIcon.tech,
        tasks: [
          task('Preparar pitch', 8, done: true),
          task('Hacer sistema de diseño', 9),
          task('Avanzar Framer', 11),
          task('Diseño de frontend', 15),
        ],
      ),
      NewSeedlyProject(
        name: 'Prueba Arquitectura',
        kind: SeedlyProjectKind.full,
        icon: SeedlyProjectIcon.plan,
        tasks: [
          task('Revisar planos', 10, done: true),
          task('Medir el terreno', 12, done: true),
          task('Entregar maqueta', 18),
        ],
      ),
    ];
  }

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
    } on SeedlyProjectException catch (error) {
      result = error.message;
    }
    if (mounted) setState(() => _result = '$label: $result');
  }

  Future<String> _createSamples() async {
    final samples = SeedlyDropsDebugView.sampleProjects(DateTime.now());
    for (final project in samples) {
      await widget.projects.create(project);
    }
    return '${samples.length} proyectos con tareas de hoy';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panel de gotas (debug)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Above the buttons, so the outcome shows without scrolling. It is
          // always there, empty at first, so the plant's stream keeps its
          // place in the list instead of being listened to again.
          Text(_result),
          const SizedBox(height: 16),
          if (widget.auth.isSignedIn) ..._panel() else ..._signIn(),
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
    const Divider(height: 32),
    OutlinedButton(
      onPressed: () => _run('Crear proyectos de prueba', _createSamples),
      child: const Text('Crear proyectos de prueba (tareas de hoy)'),
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
