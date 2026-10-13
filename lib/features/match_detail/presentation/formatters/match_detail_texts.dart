import '../../../../core/calendar/calendar_event.dart';
import '../../../../core/time/argentina_time.dart';
import '../../../../shared/presentation/formatters/match_labels.dart';
import '../../../competitions/domain/entities/phase.dart';
import '../../../matches/domain/entities/kickoff.dart';
import '../../domain/entities/match_detail.dart';

/// Textos de un partido para compartir y para el calendario, con las reglas
/// de horario de la app: hora de Argentina y «Horario por confirmar» si la
/// hora no es confiable (D5).
abstract final class MatchDetailTexts {
  /// Duración que se reserva en el calendario (90 min, entretiempo y
  /// adicionales).
  static const calendarDuration = Duration(hours: 2);

  static const source = 'Horarios de Argentina · Datos de TheSportsDB';

  /// «Clausura · Fecha 12», «Cuartos de final», «Ronda 16 · sin fase».
  static String? phaseAndStage(MatchDetail detail) {
    final phase = detail.phase;
    final stage = detail.stageLabel;
    if (phase == null || stage == null) return stage;
    if (!phase.isDetermined) return '$stage · ${PhaseKey.undetermined.label}';
    return phase.phase == PhaseKey.unica || phase.phase == PhaseKey.regular
        ? stage
        : '${phase.phase.label} · $stage';
  }

  /// «Primera División · Clausura · Fecha 12».
  static String competitionLine(MatchDetail detail) =>
      [detail.competitionName, ?phaseAndStage(detail)].join(' · ');

  /// «Boca Juniors vs. River Plate».
  static String title(MatchDetail detail) =>
      '${detail.match.home.name} vs. ${detail.match.away.name}';

  /// Texto para compartir. [fetchedAt]: de cuándo son los datos (se informa
  /// en los partidos en juego).
  static String share(
    MatchDetail detail, {
    required DateTime now,
    required DateTime fetchedAt,
  }) {
    final m = detail.match;
    final score = m.score;
    final overdue = m.isResultOverdue(now);
    final status = MatchLabels.status(m.status, overdue: overdue);
    final day = m.kickoff.argentinaDay;

    final teams = score != null && (m.status.isFinished || m.status.isInPlay)
        ? '${m.home.name} ${score.home} – ${score.away} ${m.away.name}'
        : title(detail);
    final when = m.status.isInPlay
        ? '$status · actualizado a las ${ArgentinaTime.formatTime(fetchedAt)}'
        : [
            ?status,
            MatchLabels.day(day),
            if (!m.status.isFinished && !overdue && day != null)
              MatchLabels.kickoffTime(m.kickoff),
          ].join(' · ');

    return [teams, competitionLine(detail), when, ?m.venue, source].join('\n');
  }

  /// Evento para el calendario, o `null` si el partido no se puede agendar:
  /// ya empezó, terminó, no está programado o no tiene fecha. Con la hora
  /// confirmada dura [calendarDuration]; si no, es de día completo.
  static CalendarEvent? calendarEvent(MatchDetail detail, DateTime now) {
    final m = detail.match;
    final day = m.kickoff.argentinaDay;
    if (!m.status.isScheduled || day == null) return null;
    if (day.isBefore(ArgentinaTime.dayOf(now))) return null;
    final start = m.kickoff.confirmedUtc;
    if (start != null && !start.isAfter(now)) return null;

    final timeNote = switch (m.kickoff.certainty) {
      KickoffCertainty.confirmed => null,
      KickoffCertainty.tentative =>
        '${MatchLabels.unconfirmedTime}: TheSportsDB informa 00:00 UTC '
            '(21:00 en Argentina), sin confirmar.',
      KickoffCertainty.unknown => '${MatchLabels.unconfirmedTime}.',
    };
    return CalendarEvent(
      uid: 'partido-${m.id}@futbol-argentino',
      title: title(detail),
      time: start == null
          ? AllDayEvent(day)
          : TimedEvent(startUtc: start, endUtc: start.add(calendarDuration)),
      description: [
        competitionLine(detail),
        ?timeNote,
        'Datos de TheSportsDB.',
      ].join('\n'),
      location: m.venue,
    );
  }

  /// Nombre del `.ics` que se descarga en Web.
  static String calendarFileName(MatchDetail detail) =>
      'partido-${detail.match.id}.ics';
}
