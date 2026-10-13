import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Icons a project can show in its avatar; the stored value is [name].
enum SeedlyProjectIcon {
  planta('Planta', 'assets/images/project_planta.svg'),
  trabajo('Trabajo', 'assets/images/project_trabajo.svg'),
  estudio('Estudio', 'assets/images/project_estudio.svg'),
  tech('Tech', 'assets/images/project_tech.svg'),
  personal('Personal', 'assets/images/project_personal.svg'),
  ideas('Ideas', 'assets/images/project_ideas.svg'),
  objetivo('Objetivo', 'assets/images/project_objetivo.svg'),
  plan('Plan', 'assets/images/project_plan.svg'),
  reporte('Reporte', 'assets/images/project_reporte.svg'),
  hogar('Hogar', 'assets/images/project_hogar.svg'),
  amor('Amor', 'assets/images/project_amor.svg'),
  // More Iconoir icons beyond Figma's ten.
  lectura('Lectura', 'assets/images/project_lectura.svg'),
  escuela('Escuela', 'assets/images/project_escuela.svg'),
  mente('Mente', 'assets/images/project_mente.svg'),
  diseno('Diseño', 'assets/images/project_diseno.svg'),
  arte('Arte', 'assets/images/project_arte.svg'),
  codigo('Código', 'assets/images/project_codigo.svg'),
  fotos('Fotos', 'assets/images/project_fotos.svg'),
  musica('Música', 'assets/images/project_musica.svg'),
  juegos('Juegos', 'assets/images/project_juegos.svg'),
  series('Series', 'assets/images/project_series.svg'),
  audio('Audio', 'assets/images/project_audio.svg'),
  gym('Gym', 'assets/images/project_gym.svg'),
  correr('Correr', 'assets/images/project_correr.svg'),
  yoga('Yoga', 'assets/images/project_yoga.svg'),
  bici('Bici', 'assets/images/project_bici.svg'),
  futbol('Fútbol', 'assets/images/project_futbol.svg'),
  viaje('Viaje', 'assets/images/project_viaje.svg'),
  ruta('Ruta', 'assets/images/project_ruta.svg'),
  mundo('Mundo', 'assets/images/project_mundo.svg'),
  auto('Auto', 'assets/images/project_auto.svg'),
  compras('Compras', 'assets/images/project_compras.svg'),
  dinero('Dinero', 'assets/images/project_dinero.svg'),
  ahorro('Ahorro', 'assets/images/project_ahorro.svg'),
  regalo('Regalo', 'assets/images/project_regalo.svg'),
  comida('Comida', 'assets/images/project_comida.svg'),
  cafe('Café', 'assets/images/project_cafe.svg'),
  flor('Flor', 'assets/images/project_flor.svg'),
  arbol('Árbol', 'assets/images/project_arbol.svg'),
  agua('Agua', 'assets/images/project_agua.svg'),
  sol('Sol', 'assets/images/project_sol.svg'),
  mar('Mar', 'assets/images/project_mar.svg'),
  nube('Nube', 'assets/images/project_nube.svg'),
  favorito('Favorito', 'assets/images/project_favorito.svg'),
  meta('Meta', 'assets/images/project_meta.svg'),
  logro('Logro', 'assets/images/project_logro.svg'),
  startup('Startup', 'assets/images/project_startup.svg'),
  ciencia('Ciencia', 'assets/images/project_ciencia.svg'),
  lab('Lab', 'assets/images/project_lab.svg'),
  mate('Mate', 'assets/images/project_mate.svg'),
  idiomas('Idiomas', 'assets/images/project_idiomas.svg'),
  charla('Charla', 'assets/images/project_charla.svg'),
  correo('Correo', 'assets/images/project_correo.svg'),
  llamada('Llamada', 'assets/images/project_llamada.svg'),
  arreglos('Arreglos', 'assets/images/project_arreglos.svg'),
  retos('Retos', 'assets/images/project_retos.svg'),
  lider('Líder', 'assets/images/project_lider.svg'),
  racha('Racha', 'assets/images/project_racha.svg');

  const SeedlyProjectIcon(this.label, this.asset);

  final String label;
  final String asset;

  /// The categories offered in "Modal imagen"; [planta] is only the default.
  static List<SeedlyProjectIcon> get choices =>
      values.where((icon) => icon != planta).toList();
}

/// Figma's two "Crear Proyecto" variants.
enum SeedlyProjectKind { express, full }

/// The "Recordatorio" chips of "Nueva tarea", in minutes before the deadline.
const seedlyReminderOptions = [10, 30, 60];

/// A task typed in the create-project form; it can be created already done.
/// A [dueMinutes] time needs a [dueDate], and a reminder needs that time.
class NewSeedlyTask {
  const NewSeedlyTask(
    this.title, {
    this.done = false,
    this.dueDate,
    this.dueMinutes,
    this.reminderMinutes,
  }) : assert(dueMinutes == null || dueDate != null),
       assert(reminderMinutes == null || dueMinutes != null);

  final String title;
  final bool done;

  /// "Entrega": the day it's due.
  final DateTime? dueDate;

  /// "Hora límite", in minutes after midnight.
  final int? dueMinutes;

  /// "Recordatorio", one of [seedlyReminderOptions].
  final int? reminderMinutes;

  @override
  bool operator ==(Object other) =>
      other is NewSeedlyTask &&
      other.title == title &&
      other.done == done &&
      other.dueDate == dueDate &&
      other.dueMinutes == dueMinutes &&
      other.reminderMinutes == reminderMinutes;

  @override
  int get hashCode =>
      Object.hash(title, done, dueDate, dueMinutes, reminderMinutes);

  @override
  String toString() =>
      'NewSeedlyTask($title, done: $done, due: $dueDate $dueMinutes, '
      'reminder: $reminderMinutes)';
}

/// What the create-project form submits.
class NewSeedlyProject {
  NewSeedlyProject({
    required this.name,
    required this.kind,
    this.description,
    this.icon = SeedlyProjectIcon.planta,
    this.photo,
    this.startDate,
    this.endDate,
    this.tasks = const [],
  }) : assert(
         startDate == null || endDate == null || !endDate.isBefore(startDate),
         'A project cannot end before it starts',
       );

  final String name;
  final SeedlyProjectKind kind;
  final String? description;
  final SeedlyProjectIcon icon;

  /// A small JPEG from the gallery shown instead of [icon], which stays as
  /// the fallback.
  final Uint8List? photo;
  final DateTime? startDate;
  final DateTime? endDate;

  /// In display order.
  final List<NewSeedlyTask> tasks;
}

/// Whether the server confirmed the project or it is waiting to sync.
enum SeedlyProjectSave { saved, pendingSync }

class SeedlyProjectsException implements Exception {
  const SeedlyProjectsException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Project storage used by the screens, so tests can swap Firestore out.
abstract interface class SeedlyProjects {
  /// Throws [SeedlyProjectsException] with a message ready to show.
  Future<SeedlyProjectSave> create(NewSeedlyProject project);
}

/// Stores projects in the root `projects` collection and their tasks in the
/// root `tasks` collection, so tasks from every project can be queried
/// together (today's tasks, the calendar). Both carry `ownerId`, which every
/// query must filter on; tasks also carry `projectId`. A project and its
/// tasks are written together in one batch.
class FirebaseSeedlyProjects implements SeedlyProjects {
  FirebaseSeedlyProjects({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// How long to wait for the server before trusting the offline queue.
  static const _serverWait = Duration(seconds: 8);

  @override
  Future<SeedlyProjectSave> create(NewSeedlyProject project) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const SeedlyProjectsException(
        'Tu sesión expiró. Vuelve a iniciar sesión.',
      );
    }
    final projectRef = _firestore.collection('projects').doc();
    final batch = _firestore.batch()
      ..set(projectRef, {
        'ownerId': uid,
        'name': project.name,
        'description': project.description,
        'icon': project.icon.name,
        // Avatar-sized, so it fits in the document; Storage needs Blaze.
        'photo': project.photo == null ? null : Blob(project.photo!),
        'kind': project.kind.name,
        'startDate': _timestamp(project.startDate),
        'endDate': _timestamp(project.endDate),
        // Progress for the project list without reading every task; kept
        // in step whenever tasks are written.
        'taskCount': project.tasks.length,
        'doneCount': project.tasks.where((task) => task.done).length,
        'createdAt': FieldValue.serverTimestamp(),
      });
    for (final (order, task) in project.tasks.indexed) {
      batch.set(_firestore.collection('tasks').doc(), {
        'ownerId': uid,
        'projectId': projectRef.id,
        'title': task.title,
        'done': task.done,
        'order': order,
        'dueDate': _timestamp(task.dueDate),
        'dueMinutes': task.dueMinutes,
        'reminderMinutes': task.reminderMinutes,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    // Offline, the batch is already in the local cache and syncs later, but
    // commit() only completes once the server answers.
    try {
      await batch.commit().timeout(_serverWait);
      return SeedlyProjectSave.saved;
    } on TimeoutException {
      return SeedlyProjectSave.pendingSync;
    } on FirebaseException {
      throw const SeedlyProjectsException(
        'No se pudo guardar el proyecto. Inténtalo de nuevo.',
      );
    }
  }

  static Timestamp? _timestamp(DateTime? date) =>
      date == null ? null : Timestamp.fromDate(date);
}
