import 'package:equatable/equatable.dart';

import '../../../../core/time/calendar_day.dart';

enum KickoffCertainty {
  /// Hora confiable: se muestra.
  confirmed,

  /// Hay una hora pero sin evidencia suficiente (p. ej. `00:00` UTC sin
  /// corroborar): se muestra «Horario por confirmar».
  tentative,

  /// No hay hora: «Horario por confirmar» (o «Fecha por confirmar»).
  unknown,
}

/// De dónde sale la certeza del horario (para depurar y para el detalle).
enum KickoffEvidence {
  timestamp,
  dateAndTime,
  midnightCorroborated,
  midnightUncorroborated,
  dateOnly,
  none,
}

/// Inicio de un partido según la regla conservadora D5 (`KickoffResolver`).
final class Kickoff extends Equatable {
  const Kickoff({
    required this.utc,
    required this.argentinaDay,
    required this.certainty,
    required this.evidence,
  });

  const Kickoff.unknown()
    : utc = null,
      argentinaDay = null,
      certainty = KickoffCertainty.unknown,
      evidence = KickoffEvidence.none;

  /// Instante informado por la API (UTC). En `tentative` existe pero no se
  /// muestra; en `unknown` es `null`.
  final DateTime? utc;

  /// Día del partido en Argentina, o `null` si tampoco hay fecha.
  final CalendarDay? argentinaDay;

  final KickoffCertainty certainty;
  final KickoffEvidence evidence;

  bool get isConfirmed => certainty == KickoffCertainty.confirmed;

  /// Instante que se puede mostrar o usar para ordenar por hora.
  DateTime? get confirmedUtc => isConfirmed ? utc : null;

  @override
  List<Object?> get props => [utc, argentinaDay, certainty, evidence];
}
