import '../../../core/time/argentina_time.dart';
import '../../../core/time/calendar_day.dart';
import '../../../core/time/calendar_month.dart';
import '../../../features/matches/domain/entities/kickoff.dart';
import '../../../features/matches/domain/entities/match.dart';
import '../../../features/matches/domain/entities/match_status.dart';

/// Textos de partidos para la UI (español rioplatense, hora argentina).
abstract final class MatchLabels {
  static const _weekdays = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  static const _months = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  /// Iniciales de los días, de lunes a domingo (encabezado del calendario).
  static const weekdayInitials = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  static const unconfirmedTime = 'Horario por confirmar';
  static const unconfirmedDate = 'Fecha por confirmar';

  /// «Sábado 11/10/2026», o «Fecha por confirmar».
  static String day(CalendarDay? day) => day == null
      ? unconfirmedDate
      : '${_weekdays[day.weekday - 1]} ${ArgentinaTime.formatDay(day)}';

  /// «Octubre 2026».
  static String month(CalendarMonth month) =>
      '${_months[month.month - 1]} ${month.year}';

  /// «17:45» si el horario es confiable; si no, «Horario por confirmar».
  static String kickoffTime(Kickoff kickoff) {
    final utc = kickoff.confirmedUtc;
    return utc == null ? unconfirmedTime : ArgentinaTime.formatTime(utc);
  }

  /// Estado visible, o `null` si no hace falta mostrarlo (programado).
  static String? status(MatchStatus status, {bool overdue = false}) =>
      switch (status.kind) {
        MatchStatusKind.scheduled => overdue ? 'Resultado pendiente' : null,
        MatchStatusKind.live => 'En juego',
        MatchStatusKind.halfTime => 'Entretiempo',
        MatchStatusKind.finished => switch (status.decidedBy) {
          MatchDecision.regular => 'Final',
          MatchDecision.extraTime => 'Final (alargue)',
          MatchDecision.penalties => 'Final (penales)',
        },
        MatchStatusKind.postponed => 'Postergado',
        MatchStatusKind.cancelled => 'Cancelado',
        MatchStatusKind.abandoned => 'Suspendido',
        MatchStatusKind.suspended => 'Interrumpido',
        MatchStatusKind.unknown => status.raw ?? 'Estado desconocido',
      };

  /// Descripción para lectores de pantalla.
  static String semantics(Match m, {bool overdue = false}) {
    final score = m.score;
    final result = score != null && (m.status.isFinished || m.status.isInPlay)
        ? '${m.home.name} ${score.home}, ${m.away.name} ${score.away}'
        : '${m.home.name} contra ${m.away.name}';
    final when = m.status.isScheduled
        ? '${day(m.kickoff.argentinaDay)}, ${kickoffTime(m.kickoff)}'
        : null;
    return [result, ?status(m.status, overdue: overdue), ?when].join('. ');
  }
}
