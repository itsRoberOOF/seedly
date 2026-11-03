import 'dart:typed_data';

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

/// A task read from Firestore. Firebase-specific timestamp conversion happens
/// in the data layer, so screens and services only work with Dart values.
class SeedlyTask {
  const SeedlyTask({
    required this.id,
    required this.projectId,
    required this.title,
    required this.done,
    required this.order,
    this.dueDate,
    this.dueMinutes,
    this.reminderMinutes,
  });

  final String id;
  final String projectId;
  final String title;
  final bool done;
  final int order;
  final DateTime? dueDate;
  final int? dueMinutes;
  final int? reminderMinutes;

  @override
  bool operator ==(Object other) =>
      other is SeedlyTask &&
      other.id == id &&
      other.projectId == projectId &&
      other.title == title &&
      other.done == done &&
      other.order == order &&
      other.dueDate == dueDate &&
      other.dueMinutes == dueMinutes &&
      other.reminderMinutes == reminderMinutes;

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    title,
    done,
    order,
    dueDate,
    dueMinutes,
    reminderMinutes,
  );

  @override
  String toString() =>
      'SeedlyTask($id, $title, done: $done, due: $dueDate $dueMinutes, '
      'reminder: $reminderMinutes)';
}

/// A project read from Firestore, with the progress counters that keep the
/// project list from reading every task.
class SeedlyProject {
  const SeedlyProject({
    required this.id,
    required this.name,
    required this.kind,
    required this.icon,
    required this.taskCount,
    required this.doneCount,
    this.description,
    this.photo,
    this.startDate,
    this.endDate,
  });

  final String id;
  final String name;
  final SeedlyProjectKind kind;
  final SeedlyProjectIcon icon;
  final String? description;

  /// A small JPEG shown instead of [icon], when the project has one.
  final Uint8List? photo;
  final DateTime? startDate;
  final DateTime? endDate;
  final int taskCount;
  final int doneCount;

  /// Tasks still to do.
  int get remaining => taskCount - doneCount;

  /// Every task done; a project with no tasks is not complete.
  bool get isComplete => taskCount > 0 && doneCount >= taskCount;

  /// How far along, from 0 to 1.
  double get progress => taskCount == 0 ? 0 : doneCount / taskCount;

  @override
  bool operator ==(Object other) =>
      other is SeedlyProject &&
      other.id == id &&
      other.name == name &&
      other.kind == kind &&
      other.icon == icon &&
      other.description == description &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.taskCount == taskCount &&
      other.doneCount == doneCount;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    kind,
    icon,
    description,
    startDate,
    endDate,
    taskCount,
    doneCount,
  );

  @override
  String toString() => 'SeedlyProject($id, $name, $doneCount/$taskCount done)';
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

/// What the edit-project form submits; the kind and the tasks stay as they
/// are. Every field is written, so pass the current value for what didn't
/// change.
class SeedlyProjectChanges {
  SeedlyProjectChanges({
    required this.name,
    this.description,
    this.icon = SeedlyProjectIcon.planta,
    this.photo,
    this.startDate,
    this.endDate,
  }) : assert(
         startDate == null || endDate == null || !endDate.isBefore(startDate),
         'A project cannot end before it starts',
       );

  final String name;
  final String? description;
  final SeedlyProjectIcon icon;
  final Uint8List? photo;
  final DateTime? startDate;
  final DateTime? endDate;
}
