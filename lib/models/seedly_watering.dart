import 'seedly_drops.dart';

/// Los números de una sesión de riego. Las gotas que paga viven en
/// [SeedlyDrops].
abstract final class SeedlyWatering {
  /// Las opciones de duración de Figma, en minutos.
  static const presets = [10, 15, 25, 30, 40];
  static const defaultMinutes = 25;
  static const minMinutes = 1;

  /// Una sesión paga como máximo estos minutos, así que nunca dura más.
  static const maxMinutes = SeedlyDrops.maxWateringMinutes;
}

/// Una sesión de riego en curso: una cuenta regresiva de [minutes] que se
/// puede pausar.
///
/// El tiempo sale del reloj del teléfono, así que la cuenta sigue aunque la
/// app esté en segundo plano o cerrada; acá nada hace tic. firestore.rules
/// solo paga los minutos que pasaron de verdad desde que el servidor sella el
/// inicio, y [startedAt] se toma después de ese sello, así que los minutos
/// contados acá nunca superan a los del servidor.
class SeedlyWateringSession {
  const SeedlyWateringSession({
    required this.id,
    required this.ownerId,
    required this.minutes,
    required this.startedAt,
    this.pausedFor = Duration.zero,
    this.pausedAt,
    this.focusTaskId,
    this.focusTitle,
  });

  /// El id del documento de `sessions`; también nombra las gotas que paga.
  final String id;
  final String ownerId;

  /// Lo que dura la cuenta regresiva.
  final int minutes;

  /// Cuándo empezó a contar este teléfono.
  final DateTime startedAt;

  /// Tiempo en pausa antes de [pausedAt].
  final Duration pausedFor;

  /// Presente mientras está en pausa.
  final DateTime? pausedAt;

  /// La tarea elegida en "Enfoque de hoy", o null para "Sesión libre".
  final String? focusTaskId;
  final String? focusTitle;

  bool get isPaused => pausedAt != null;

  Duration get length => Duration(minutes: minutes);

  /// Tiempo regado a [now], sin contar las pausas; nunca más que [length].
  Duration wateredAt(DateTime now) {
    final watered = (pausedAt ?? now).difference(startedAt) - pausedFor;
    if (watered.isNegative) return Duration.zero;
    return watered > length ? length : watered;
  }

  Duration remainingAt(DateTime now) => length - wateredAt(now);

  /// De 0 a 1.
  double progressAt(DateTime now) =>
      wateredAt(now).inMilliseconds / length.inMilliseconds;

  bool isDoneAt(DateTime now) => wateredAt(now) >= length;

  /// Minutos completos regados a [now]: lo que paga la sesión.
  int paidMinutesAt(DateTime now) => wateredAt(now).inMinutes;

  /// Cuándo la cuenta llega a cero, o null en pausa.
  DateTime? get endsAt => isPaused ? null : startedAt.add(pausedFor + length);

  /// Detiene la cuenta en [now]; si ya estaba en pausa, queda igual.
  SeedlyWateringSession pause(DateTime now) =>
      isPaused ? this : _copy(pausedFor: pausedFor, pausedAt: now);

  /// Retoma la cuenta desde donde se pausó.
  SeedlyWateringSession resume(DateTime now) {
    final pausedAt = this.pausedAt;
    if (pausedAt == null) return this;
    final paused = now.difference(pausedAt);
    return _copy(
      // Si atrasaron el reloj durante la pausa, no se suma tiempo.
      pausedFor: pausedFor + (paused.isNegative ? Duration.zero : paused),
      pausedAt: null,
    );
  }

  SeedlyWateringSession _copy({
    required Duration pausedFor,
    required DateTime? pausedAt,
  }) => SeedlyWateringSession(
    id: id,
    ownerId: ownerId,
    minutes: minutes,
    startedAt: startedAt,
    pausedFor: pausedFor,
    pausedAt: pausedAt,
    focusTaskId: focusTaskId,
    focusTitle: focusTitle,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'ownerId': ownerId,
    'minutes': minutes,
    'startedAt': startedAt.millisecondsSinceEpoch,
    'pausedForMs': pausedFor.inMilliseconds,
    'pausedAt': pausedAt?.millisecondsSinceEpoch,
    'focusTaskId': focusTaskId,
    'focusTitle': focusTitle,
  };

  /// Lanza [FormatException] si [json] no es una sesión guardada.
  factory SeedlyWateringSession.fromJson(Map<String, Object?> json) {
    try {
      final pausedAt = json['pausedAt'] as int?;
      return SeedlyWateringSession(
        id: json['id']! as String,
        ownerId: json['ownerId']! as String,
        minutes: json['minutes']! as int,
        startedAt: DateTime.fromMillisecondsSinceEpoch(
          json['startedAt']! as int,
        ),
        pausedFor: Duration(milliseconds: json['pausedForMs']! as int),
        pausedAt: pausedAt == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(pausedAt),
        focusTaskId: json['focusTaskId'] as String?,
        focusTitle: json['focusTitle'] as String?,
      );
    } on TypeError {
      throw const FormatException('No es una sesión de riego guardada');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is SeedlyWateringSession &&
      other.id == id &&
      other.ownerId == ownerId &&
      other.minutes == minutes &&
      other.startedAt == startedAt &&
      other.pausedFor == pausedFor &&
      other.pausedAt == pausedAt &&
      other.focusTaskId == focusTaskId &&
      other.focusTitle == focusTitle;

  @override
  int get hashCode => Object.hash(
    id,
    ownerId,
    minutes,
    startedAt,
    pausedFor,
    pausedAt,
    focusTaskId,
    focusTitle,
  );

  @override
  String toString() =>
      'SeedlyWateringSession($id, $minutes min, '
      '${isPaused ? 'paused' : 'running'})';
}
