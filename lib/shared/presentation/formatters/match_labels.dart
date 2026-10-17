import '../../../core/time/argentina_time.dart';
import '../../../core/time/calendar_day.dart';
import '../../../core/time/calendar_month.dart';
import '../../../features/matches/domain/entities/kickoff.dart';
import '../../../features/matches/domain/entities/knockout_tie.dart';
import '../../../features/matches/domain/entities/match.dart';
import '../../../features/matches/domain/entities/match_status.dart';
import '../../../features/matches/domain/entities/score.dart';
import '../../../features/matches/domain/services/tie_outcome.dart';

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

  /// «4-3» de la tanda de penales, si la API la informa.
  static String? penalties(Match m) {
    final p = m.penalties;
    return p == null ? null : '${p.home}-${p.away}';
  }

  /// «Avanza River Plate», con la tanda si se definió por penales.
  static String advances(TieOutcome outcome, Match m) {
    final shootout = penalties(m);
    return outcome.source == TieOutcomeSource.penalties && shootout != null
        ? 'Avanza ${outcome.winner.name} ($shootout en penales)'
        : 'Avanza ${outcome.winner.name}';
  }

  /// «Ida» o «Vuelta» de la pierna [index] (desde 0) de una serie.
  static String leg(int index) => index == 0 ? 'Ida' : 'Vuelta';

  /// Quién avanzó en [tie]: en un partido único, como [advances]; en una
  /// serie, con el global o la tanda contados desde el ganador («Avanza
  /// Palmeiras (4-3 en penales)»).
  static String tieAdvances(TieOutcome outcome, KnockoutTie tie) {
    if (!tie.isSeries) return advances(outcome, tie.decisive);
    final winner = outcome.winner;
    String fromWinner(Score s) => winner.id == tie.first.id
        ? '${s.home}-${s.away}'
        : '${s.away}-${s.home}';
    final detail = switch (outcome.source) {
      TieOutcomeSource.aggregate => switch (tie.aggregate) {
        final s? => 'global ${fromWinner(s)}',
        null => null,
      },
      TieOutcomeSource.penalties => switch (tie.penalties) {
        final s? => '${fromWinner(s)} en penales',
        null => 'por penales',
      },
      TieOutcomeSource.laterMatch => 'juega la ronda siguiente',
      TieOutcomeSource.score => null,
    };
    return detail == null
        ? 'Avanza ${winner.name}'
        : 'Avanza ${winner.name} ($detail)';
  }

  /// «Global River Plate 3-1 Boca Juniors» («Global parcial» si falta
  /// jugar); `null` si ninguna pierna empezó.
  static String? aggregate(KnockoutTie tie) {
    final s = tie.partialAggregate;
    if (s == null) return null;
    final label = tie.isComplete ? 'Global' : 'Global parcial';
    return '$label ${tie.first.name} ${s.home}-${s.away} ${tie.second.name}';
  }

  /// Descripción para lectores de pantalla.
  static String semantics(Match m, {bool overdue = false}) {
    final score = m.score;
    final result = score != null && (m.status.isFinished || m.status.isInPlay)
        ? '${m.home.name} ${score.home}, ${m.away.name} ${score.away}'
        : '${m.home.name} contra ${m.away.name}';
    final shootout = m.penalties;
    final penaltiesText = shootout == null || !m.status.isFinished
        ? null
        : 'Penales: ${m.home.name} ${shootout.home}, '
              '${m.away.name} ${shootout.away}';
    final when = m.status.isScheduled
        ? '${day(m.kickoff.argentinaDay)}, ${kickoffTime(m.kickoff)}'
        : null;
    return [
      result,
      ?status(m.status, overdue: overdue),
      ?penaltiesText,
      ?when,
    ].join('. ');
  }
}
